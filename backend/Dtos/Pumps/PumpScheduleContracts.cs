namespace IOTAgriBackend.Dtos.Pumps;

public record PumpScheduleRequest(
    bool? IsEnabled,
    int WeekdayMask,
    TimeOnly? StartTime,
    int DurationSeconds,
    string? TimeZone,
    TimeOnly? EndTime = null,
    int? IntervalMinutes = null);

public record PumpScheduleResponse(
    Guid Id,
    Guid DeviceId,
    bool IsEnabled,
    int WeekdayMask,
    TimeOnly StartTime,
    TimeOnly? EndTime,
    int? IntervalMinutes,
    int DurationSeconds,
    string TimeZone,
    DateTime? LastDispatchedOccurrenceUtc,
    DateTime CreatedAt);
