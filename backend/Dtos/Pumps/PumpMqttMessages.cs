namespace IOTAgriBackend.Dtos.Pumps;

public record PumpCommandMessage(Guid CommandId, bool IsOn, int? DurationSeconds);

public record PumpStatusMessage(
    Guid? CommandId,
    bool IsOn,
    bool? Success = null,
    string? Reason = null)
{
    public bool WasSuccessful => Success ?? true;

    public string? NormalizedReason
    {
        get
        {
            if (string.IsNullOrWhiteSpace(Reason)) return null;
            var value = Reason.Trim();
            return value.Length <= 512 ? value : value[..512];
        }
    }
}
