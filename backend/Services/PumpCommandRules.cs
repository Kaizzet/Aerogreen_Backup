using IOTAgriBackend.Dtos.Pumps;
using IOTAgriBackend.Models;

namespace IOTAgriBackend.Services;

public static class PumpCommandRules
{
    public static bool Matches(PumpCommand command, Guid deviceId, PumpCommandRequest request) =>
        command.DeviceId == deviceId && command.IsOn == request.IsOn && command.DurationSeconds == request.DurationSeconds;

    public static void ApplyStatus(PumpCommand command, PumpStatusMessage status, DateTime now)
    {
        command.Status = status.WasSuccessful ? PumpCommandStatus.Acknowledged : PumpCommandStatus.Failed;
        command.AcknowledgedAt = now;
        command.AcknowledgedIsOn = status.IsOn;
        command.FailureReason = status.WasSuccessful ? null : status.NormalizedReason ?? "DEVICE_REJECTED";
    }
}
