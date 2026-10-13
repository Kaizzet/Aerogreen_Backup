using IOTAgriBackend.Dtos.Pumps;
using IOTAgriBackend.Models;
using IOTAgriBackend.Services;
using Xunit;

namespace IOTAgriBackend.Tests;

public class PumpCommandRulesTests
{
    [Theory]
    [InlineData(true, 60, true)]
    [InlineData(false, 60, false)]
    [InlineData(true, 30, false)]
    public void Duplicate_command_must_match_device_and_payload(bool on, int duration, bool expected)
    {
        var device = Guid.NewGuid();
        var command = new PumpCommand { DeviceId = device, IsOn = true, DurationSeconds = 60 };
        var request = new PumpCommandRequest(command.Id, on, duration);
        Assert.Equal(expected, PumpCommandRules.Matches(command, device, request));
        Assert.False(PumpCommandRules.Matches(command, Guid.NewGuid(), request));
    }

    [Theory]
    [InlineData(true, null, null)]
    [InlineData(false, null, "DEVICE_REJECTED")]
    [InlineData(false, " LOW_WATER ", "LOW_WATER")]
    public void Acknowledgment_applies_device_result_and_can_be_repeated(bool success, string? reason, string? expected)
    {
        var command = new PumpCommand { FailureReason = "previous" };
        var status = new PumpStatusMessage(command.Id, false, success, reason);
        var now = new DateTime(2030, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        PumpCommandRules.ApplyStatus(command, status, now);
        PumpCommandRules.ApplyStatus(command, status, now);
        Assert.Equal(success ? PumpCommandStatus.Acknowledged : PumpCommandStatus.Failed, command.Status);
        Assert.Equal(now, command.AcknowledgedAt);
        Assert.False(command.AcknowledgedIsOn);
        Assert.Equal(expected, command.FailureReason);
    }
}
