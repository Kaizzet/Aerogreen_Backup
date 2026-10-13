using System.Text.Json;
using IOTAgriBackend.Models;
using IOTAgriBackend.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using MQTTnet;
using MQTTnet.Protocol;
using Xunit;

namespace IOTAgriBackend.Tests;

public class MqttPublisherTests
{
    private static MqttIngestionService Service(Mock<IMqttClient> client) => new(
        Mock.Of<IServiceScopeFactory>(), new ConfigurationBuilder().Build(),
        NullLogger<MqttIngestionService>.Instance, client.Object);

    [Fact]
    public async Task Disconnected_publisher_does_not_attempt_delivery()
    {
        var client = new Mock<IMqttClient>(MockBehavior.Strict);
        client.SetupGet(c => c.IsConnected).Returns(false);
        await Assert.ThrowsAsync<InvalidOperationException>(() => Service(client).PublishPumpCommandAsync("fixture-device", new(), default));
        client.VerifyGet(c => c.IsConnected, Times.Once);
        client.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task Publishes_qos_one_contract_and_preserves_command_id_on_retry()
    {
        var client = new Mock<IMqttClient>();
        client.SetupGet(c => c.IsConnected).Returns(true);
        var messages = new List<MqttApplicationMessage>();
        client.Setup(c => c.PublishAsync(It.IsAny<MqttApplicationMessage>(), It.IsAny<CancellationToken>()))
            .Callback<MqttApplicationMessage, CancellationToken>((message, _) => messages.Add(message))
            .ReturnsAsync(new MqttClientPublishResult(1, MqttClientPublishReasonCode.Success, null, []));
        var service = Service(client);
        var command = new PumpCommand { IsOn = true, DurationSeconds = 60 };
        await service.PublishPumpCommandAsync("fixture-device", command, default);
        await service.PublishPumpCommandAsync("fixture-device", command, default);
        Assert.Equal(2, messages.Count);
        Assert.All(messages, message =>
        {
            Assert.Equal("devices/fixture-device/commands/pump", message.Topic);
            Assert.Equal(MqttQualityOfServiceLevel.AtLeastOnce, message.QualityOfServiceLevel);
            using var payload = JsonDocument.Parse(message.Payload);
            Assert.Equal(command.Id, payload.RootElement.GetProperty("commandId").GetGuid());
            Assert.True(payload.RootElement.GetProperty("isOn").GetBoolean());
            Assert.Equal(60, payload.RootElement.GetProperty("durationSeconds").GetInt32());
        });
    }

    [Fact]
    public async Task Broker_failure_and_cancellation_reach_the_caller()
    {
        var client = new Mock<IMqttClient>();
        client.SetupGet(c => c.IsConnected).Returns(true);
        client.Setup(c => c.PublishAsync(It.IsAny<MqttApplicationMessage>(), It.IsAny<CancellationToken>())).ThrowsAsync(new TimeoutException());
        await Assert.ThrowsAsync<TimeoutException>(() => Service(client).PublishPumpCommandAsync("fixture-device", new(), default));
        client.Setup(c => c.PublishAsync(It.IsAny<MqttApplicationMessage>(), It.IsAny<CancellationToken>())).ThrowsAsync(new OperationCanceledException());
        await Assert.ThrowsAsync<OperationCanceledException>(() => Service(client).PublishPumpCommandAsync("fixture-device", new(), default));
    }
}
