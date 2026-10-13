using System.Buffers;
using System.Text;
using System.Text.Json;
using IOTAgriBackend.Data;
using IOTAgriBackend.Dtos.Pumps;
using IOTAgriBackend.Dtos.Sensors;
using IOTAgriBackend.Models;
using Microsoft.EntityFrameworkCore;
using MQTTnet;
using MQTTnet.Protocol;

namespace IOTAgriBackend.Services;

// Handles MQTT readings, pump status, and outbound pump commands.
public class MqttIngestionService : BackgroundService
{
    private const string PumpStatusTopicFilter = "devices/+/pump-status";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IConfiguration _configuration;
    private readonly ILogger<MqttIngestionService> _logger;
    private readonly IMqttClient _mqttClient;

    public bool IsConnected => _mqttClient.IsConnected;

    public MqttIngestionService(
        IServiceScopeFactory scopeFactory,
        IConfiguration configuration,
        ILogger<MqttIngestionService> logger)
    {
        _scopeFactory = scopeFactory;
        _configuration = configuration;
        _logger = logger;
        _mqttClient = new MqttClientFactory().CreateMqttClient();
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var mqttSection = _configuration.GetSection("Mqtt");
        var host = mqttSection["Host"] ?? "localhost";
        var port = mqttSection.GetValue<int?>("Port") ?? 1883;
        var useTls = mqttSection.GetValue<bool>("UseTls");
        var username = mqttSection["Username"];
        var password = mqttSection["Password"];
        var clientId = mqttSection["ClientId"] ?? $"iotagribackend-{Guid.NewGuid():N}";
        var readingsTopicFilter = mqttSection["ReadingsTopicFilter"] ?? "devices/+/readings";

        var optionsBuilder = new MqttClientOptionsBuilder()
            .WithTcpServer(host, port)
            .WithClientId(clientId)
            .WithCleanSession();

        if (!string.IsNullOrEmpty(username))
        {
            optionsBuilder = optionsBuilder.WithCredentials(username, password);
        }

        if (useTls)
        {
            optionsBuilder = optionsBuilder.WithTlsOptions(o => o.UseTls());
        }

        var options = optionsBuilder.Build();

        _mqttClient.ApplicationMessageReceivedAsync += OnMessageReceivedAsync;

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (!_mqttClient.IsConnected)
                {
                    await _mqttClient.ConnectAsync(options, stoppingToken);

                    var subscribeOptions = new MqttClientFactory()
                        .CreateSubscribeOptionsBuilder()
                        .WithTopicFilter(readingsTopicFilter)
                        .WithTopicFilter(PumpStatusTopicFilter)
                        .Build();

                    await _mqttClient.SubscribeAsync(subscribeOptions, stoppingToken);
                    _logger.LogInformation("MQTT connected to {Host}:{Port} and subscribed to {ReadingsTopic} and {PumpStatusTopic}", host, port, readingsTopicFilter, PumpStatusTopicFilter);
                }
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogWarning(ex, "MQTT connection attempt failed, retrying in 5s.");
            }

            try
            {
                await MarkOfflineDevicesAsync();
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogError(ex, "Failed to update device presence.");
            }

            await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
        }
    }

    private async Task MarkOfflineDevicesAsync()
    {
        var now = DateTime.UtcNow;
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var onlineDevices = await db.Devices.Where(device => device.IsOnline).ToListAsync();

        foreach (var device in onlineDevices.Where(device => DevicePresence.IsOffline(device.LastSeenAt, now)))
        {
            device.IsOnline = false;
        }

        if (db.ChangeTracker.HasChanges())
        {
            await db.SaveChangesAsync();
        }
    }

    private async Task OnMessageReceivedAsync(MqttApplicationMessageReceivedEventArgs args)
    {
        try
        {
            var topic = args.ApplicationMessage.Topic;
            var segments = topic.Split('/');
            if (segments.Length != 3 || segments[0] != "devices")
            {
                return;
            }

            var deviceKey = segments[1];
            var payloadBytes = args.ApplicationMessage.Payload.ToArray();
            if (segments[2] == "readings")
            {
                await ProcessReadingAsync(deviceKey, payloadBytes);
                return;
            }

            if (segments[2] == "pump-status")
            {
                await ProcessPumpStatusAsync(deviceKey, payloadBytes, topic);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to process incoming MQTT message.");
        }
    }

    public async Task PublishPumpCommandAsync(string deviceKey, PumpCommand command, CancellationToken cancellationToken)
    {
        if (!_mqttClient.IsConnected)
        {
            throw new InvalidOperationException("MQTT client is not connected.");
        }

        var message = new MqttApplicationMessageBuilder()
            .WithTopic($"devices/{deviceKey}/commands/pump")
            .WithPayload(JsonSerializer.Serialize(new PumpCommandMessage(command.Id, command.IsOn, command.DurationSeconds), JsonOptions))
            .WithQualityOfServiceLevel(MqttQualityOfServiceLevel.AtLeastOnce)
            .Build();

        await _mqttClient.PublishAsync(message, cancellationToken);
    }

    private async Task ProcessReadingAsync(string deviceKey, byte[] payloadBytes)
    {
        var request = JsonSerializer.Deserialize<SensorReadingRequest>(Encoding.UTF8.GetString(payloadBytes), JsonOptions);
        if (request is null)
        {
            return;
        }

        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

        var device = await db.Devices.FirstOrDefaultAsync(d => d.DeviceKey == deviceKey);
        if (device is null)
        {
            _logger.LogWarning("Received MQTT reading for unknown device key.");
            return;
        }

        var reading = new SensorReading
        {
            DeviceId = device.Id,
            Temperature = request.Temperature,
            SolutionTemperature = request.SolutionTemperature,
            Humidity = request.Humidity,
            Ph = request.Ph,
            Tds = request.Tds,
            WaterLevel = request.WaterLevel,
            Lux = request.Lux,
        };

        db.SensorReadings.Add(reading);
        var defaults = await db.SystemAlertDefaults.SingleOrDefaultAsync();
        var thresholds = DeviceAlertRules.EffectiveThresholds(
            device.HighTemperatureAlertC,
            device.LowWaterLevelAlertPercent,
            defaults?.HighTemperatureC ?? SystemAlertDefaults.DefaultHighTemperatureC,
            defaults?.LowWaterLevelPercent ?? SystemAlertDefaults.DefaultLowWaterLevelPercent);
        await EvaluateAlertsAsync(db, device, reading, thresholds.HighTemperatureC, thresholds.LowWaterLevelPercent);
        device.IsOnline = true;
        device.LastSeenAt = reading.RecordedAt;
        await db.SaveChangesAsync();
    }

    private static async Task EvaluateAlertsAsync(
        ApplicationDbContext db,
        Device device,
        SensorReading reading,
        double highTemperatureC,
        double lowWaterLevelPercent)
    {
        foreach (var type in Enum.GetValues<DeviceAlertType>())
        {
            var isUnsafe = DeviceAlertRules.IsUnsafe(
                type,
                reading.Temperature,
                reading.WaterLevel,
                highTemperatureC,
                lowWaterLevelPercent);
            if (isUnsafe is null)
            {
                continue;
            }

            var activeAlert = await db.DeviceAlerts.SingleOrDefaultAsync(alert =>
                alert.DeviceId == device.Id && alert.Type == type && alert.ResolvedAt == null);

            if (isUnsafe.Value && activeAlert is null)
            {
                var (measuredValue, threshold) = type == DeviceAlertType.HighTemperature
                    ? (reading.Temperature!.Value, highTemperatureC)
                    : (reading.WaterLevel!.Value, lowWaterLevelPercent);
                db.DeviceAlerts.Add(new DeviceAlert
                {
                    DeviceId = device.Id,
                    Type = type,
                    MeasuredValue = measuredValue,
                    Threshold = threshold,
                    TriggeredAt = reading.RecordedAt,
                });
            }
            else if (!isUnsafe.Value && activeAlert is not null)
            {
                activeAlert.ResolvedAt = reading.RecordedAt;
            }
        }
    }

    private async Task ProcessPumpStatusAsync(string deviceKey, byte[] payloadBytes, string topic)
    {
        if (payloadBytes.Length > 1024)
        {
            _logger.LogWarning("Ignored oversized pump status on topic {Topic}.", topic);
            return;
        }

        var status = JsonSerializer.Deserialize<PumpStatusMessage>(Encoding.UTF8.GetString(payloadBytes), JsonOptions);
        if (status is null)
        {
            return;
        }

        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var device = await db.Devices.FirstOrDefaultAsync(d => d.DeviceKey == deviceKey);
        if (device is null)
        {
            _logger.LogWarning("Received pump status for unknown device key on topic {Topic}.", topic);
            return;
        }

        var now = DateTime.UtcNow;
        device.IsPumpOn = status.IsOn;
        device.PumpStatusUpdatedAt = now;

        if (status.CommandId is Guid commandId && commandId != Guid.Empty)
        {
            var command = await db.PumpCommands.FirstOrDefaultAsync(c => c.Id == commandId && c.DeviceId == device.Id);
            if (command is null)
            {
                _logger.LogWarning("Received pump status for unknown command {CommandId} on topic {Topic}.", commandId, topic);
            }
            else
            {
                command.Status = status.WasSuccessful
                    ? PumpCommandStatus.Acknowledged
                    : PumpCommandStatus.Failed;
                command.AcknowledgedAt = now;
                command.AcknowledgedIsOn = status.IsOn;
                command.FailureReason = status.WasSuccessful
                    ? null
                    : status.NormalizedReason ?? "DEVICE_REJECTED";
            }
        }

        await db.SaveChangesAsync();
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        if (_mqttClient.IsConnected)
        {
            await _mqttClient.DisconnectAsync(cancellationToken: cancellationToken);
        }

        await base.StopAsync(cancellationToken);
    }
}
