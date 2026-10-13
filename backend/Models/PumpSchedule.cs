namespace IOTAgriBackend.Models;

public class PumpSchedule
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid DeviceId { get; set; }
    public Device? Device { get; set; }
    public bool IsEnabled { get; set; } = true;
    public int WeekdayMask { get; set; }
    public TimeOnly StartTime { get; set; }
    public TimeOnly? EndTime { get; set; }
    public int? IntervalMinutes { get; set; }
    public int DurationSeconds { get; set; }
    public string TimeZone { get; set; } = string.Empty;
    public DateTime? LastDispatchedOccurrenceUtc { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public ICollection<PumpScheduleOccurrence> Occurrences { get; set; } = new List<PumpScheduleOccurrence>();
}
