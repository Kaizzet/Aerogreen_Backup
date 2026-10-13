using IOTAgriBackend.Data;
using IOTAgriBackend.Models;
using Microsoft.EntityFrameworkCore;

namespace IOTAgriBackend.Services;

public class PumpScheduleDispatchService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IConfiguration _configuration;
    private readonly MqttIngestionService _mqtt;
    private readonly ILogger<PumpScheduleDispatchService> _logger;

    public PumpScheduleDispatchService(
        IServiceScopeFactory scopeFactory,
        IConfiguration configuration,
        MqttIngestionService mqtt,
        ILogger<PumpScheduleDispatchService> logger)
    {
        _scopeFactory = scopeFactory;
        _configuration = configuration;
        _mqtt = mqtt;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var scheduling = _configuration.GetSection("PumpScheduling");
        if (!scheduling.GetValue<bool>("Enabled"))
        {
            _logger.LogInformation("Pump schedule dispatch is disabled.");
            return;
        }

        var pollSeconds = Math.Clamp(scheduling.GetValue<int?>("PollSeconds") ?? 30, 5, 300);
        var dueWindow = TimeSpan.FromSeconds(Math.Max(scheduling.GetValue<int?>("DueWindowSeconds") ?? 90, pollSeconds));
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(pollSeconds));

        await DispatchAsync(dueWindow, stoppingToken);
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            await DispatchAsync(dueWindow, stoppingToken);
        }
    }

    private async Task DispatchAsync(TimeSpan dueWindow, CancellationToken cancellationToken)
    {
        try
        {
            var now = DateTime.UtcNow;
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var schedules = await db.PumpSchedules.AsNoTracking().Where(schedule => schedule.IsEnabled).ToListAsync(cancellationToken);
            var dueOccurrences = new List<DueOccurrence>();
            foreach (var schedule in schedules)
            {
                dueOccurrences.AddRange(PumpScheduleRules.GetDueOccurrencesUtc(schedule, now, dueWindow)
                    .Select(occurrence => new DueOccurrence(schedule.Id, occurrence)));
            }
            var pendingIds = await db.PumpScheduleOccurrences
                .Where(occurrence => occurrence.DispatchedAt == null && occurrence.Schedule!.IsEnabled)
                .OrderBy(occurrence => occurrence.OccurrenceUtc)
                .Select(occurrence => occurrence.Id)
                .Take(100)
                .ToListAsync(cancellationToken);

            foreach (var due in dueOccurrences)
            {
                await ClaimAndPublishAsync(due.ScheduleId, due.OccurrenceUtc, cancellationToken);
            }

            foreach (var occurrenceId in pendingIds)
            {
                await PublishAsync(occurrenceId, cancellationToken);
            }
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            _logger.LogError(exception, "Pump schedule dispatch cycle failed.");
        }
    }

    private async Task ClaimAndPublishAsync(Guid scheduleId, DateTime occurrenceUtc, CancellationToken cancellationToken)
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var occurrence = new PumpScheduleOccurrence
        {
            ScheduleId = scheduleId,
            OccurrenceUtc = occurrenceUtc,
            CommandId = Guid.NewGuid(),
        };
        db.PumpScheduleOccurrences.Add(occurrence);

        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (exception.InnerException is Npgsql.PostgresException { SqlState: "23505" })
        {
            return;
        }

        await PublishAsync(occurrence.Id, cancellationToken);
    }

    private async Task PublishAsync(Guid occurrenceId, CancellationToken cancellationToken)
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var occurrence = await db.PumpScheduleOccurrences
            .Include(item => item.Schedule)
            .ThenInclude(schedule => schedule!.Device)
            .FirstOrDefaultAsync(item => item.Id == occurrenceId && item.DispatchedAt == null, cancellationToken);
        if (occurrence?.Schedule?.Device is not Device device || !occurrence.Schedule.IsEnabled)
        {
            return;
        }

        var command = await db.PumpCommands.FirstOrDefaultAsync(item => item.Id == occurrence.CommandId, cancellationToken);
        if (command is null)
        {
            command = new PumpCommand
            {
                Id = occurrence.CommandId,
                DeviceId = device.Id,
                IsOn = true,
                DurationSeconds = occurrence.Schedule.DurationSeconds,
                Source = PumpCommandSource.Scheduled,
            };
            db.PumpCommands.Add(command);
            await db.SaveChangesAsync(cancellationToken);
        }

        try
        {
            await _mqtt.PublishPumpCommandAsync(device.DeviceKey, command, cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            _logger.LogWarning(exception, "Pump schedule occurrence {OccurrenceId} was not published and will retry.", occurrence.Id);
            return;
        }

        occurrence.DispatchedAt = DateTime.UtcNow;
        occurrence.Schedule.LastDispatchedOccurrenceUtc = occurrence.OccurrenceUtc;
        await db.SaveChangesAsync(cancellationToken);
    }

    private sealed record DueOccurrence(Guid ScheduleId, DateTime OccurrenceUtc);
}
