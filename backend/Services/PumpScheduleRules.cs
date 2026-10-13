using IOTAgriBackend.Models;

namespace IOTAgriBackend.Services;

public static class PumpScheduleRules
{
    private const int AllDaysMask = 0b1111111;
    private const long TicksPerWeek = TimeSpan.TicksPerDay * 7;

    public static string? Validate(bool? isEnabled, int weekdayMask, TimeOnly? startTime, int durationSeconds, string? timeZone, int maximumDurationSeconds, TimeOnly? endTime = null, int? intervalMinutes = null)
    {
        if (isEnabled is null) return "isEnabled is required.";
        if (weekdayMask <= 0 || (weekdayMask & ~AllDaysMask) != 0) return "weekdayMask must include one or more days from Sunday (1) through Saturday (64).";
        if (startTime is null) return "startTime is required.";
        if (durationSeconds <= 0 || durationSeconds > maximumDurationSeconds) return $"durationSeconds must be between 1 and {maximumDurationSeconds}.";
        if (endTime.HasValue != intervalMinutes.HasValue) return "endTime and intervalMinutes must be provided together.";
        if (intervalMinutes is <= 0 or > 60) return "intervalMinutes must be between 1 and 60.";
        if (endTime == startTime) return "endTime must differ from startTime.";
        if (intervalMinutes is not null && durationSeconds >= intervalMinutes * 60) return "durationSeconds must be shorter than intervalMinutes.";
        if (string.IsNullOrWhiteSpace(timeZone) || !TimeZoneInfo.TryConvertIanaIdToWindowsId(timeZone, out _)) return "timeZone must be a valid IANA time zone.";
        return null;
    }

    public static bool Overlaps(PumpSchedule candidate, IEnumerable<PumpSchedule> schedules)
    {
        if (!candidate.IsEnabled) return false;

        return schedules.Where(schedule => schedule.IsEnabled && schedule.Id != candidate.Id)
            .Any(schedule => Occurrences(candidate).Any(candidateStart =>
                Occurrences(schedule).Any(existingStart => IntervalsOverlap(candidateStart, candidate.DurationSeconds, existingStart, schedule.DurationSeconds))));
    }

    private static IEnumerable<long> Occurrences(PumpSchedule schedule)
    {
        for (var day = 0; day < 7; day++)
        {
            if ((schedule.WeekdayMask & (1 << day)) != 0)
            {
                foreach (var offset in OccurrenceOffsets(schedule))
                    yield return (TimeSpan.TicksPerDay * day) + schedule.StartTime.Ticks + offset.Ticks;
            }
        }
    }

    private static bool IntervalsOverlap(long firstStart, int firstDurationSeconds, long secondStart, int secondDurationSeconds)
    {
        var firstEnd = firstStart + TimeSpan.FromSeconds(firstDurationSeconds).Ticks;
        var secondEnd = secondStart + TimeSpan.FromSeconds(secondDurationSeconds).Ticks;

        return Overlaps(firstStart, firstEnd, secondStart, secondEnd) ||
            Overlaps(firstStart, firstEnd, secondStart + TicksPerWeek, secondEnd + TicksPerWeek) ||
            Overlaps(firstStart, firstEnd, secondStart - TicksPerWeek, secondEnd - TicksPerWeek);
    }

    public static bool TryGetDueOccurrenceUtc(PumpSchedule schedule, DateTime utcNow, TimeSpan dueWindow, out DateTime occurrenceUtc)
    {
        occurrenceUtc = GetDueOccurrencesUtc(schedule, utcNow, dueWindow).LastOrDefault();
        return occurrenceUtc != default;
    }

    public static List<DateTime> GetDueOccurrencesUtc(PumpSchedule schedule, DateTime utcNow, TimeSpan dueWindow)
    {
        if (!schedule.IsEnabled || dueWindow <= TimeSpan.Zero) return [];

        TimeZoneInfo timeZone;
        try { timeZone = TimeZoneInfo.FindSystemTimeZoneById(schedule.TimeZone); }
        catch (TimeZoneNotFoundException) { return []; }
        catch (InvalidTimeZoneException) { return []; }

        var localNow = TimeZoneInfo.ConvertTimeFromUtc(utcNow, timeZone);
        var occurrences = new List<DateTime>();
        for (var dayOffset = -1; dayOffset <= 0; dayOffset++)
        {
            var date = localNow.Date.AddDays(dayOffset);
            if ((schedule.WeekdayMask & (1 << (int)date.DayOfWeek)) == 0) continue;

            foreach (var offset in OccurrenceOffsets(schedule))
            {
                var localOccurrence = DateTime.SpecifyKind(date + schedule.StartTime.ToTimeSpan(), DateTimeKind.Unspecified).Add(offset);
                if (timeZone.IsInvalidTime(localOccurrence)) continue;

                var occurrenceUtc = TimeZoneInfo.ConvertTimeToUtc(localOccurrence, timeZone);
                if (occurrenceUtc <= utcNow && utcNow - occurrenceUtc <= dueWindow)
                    occurrences.Add(occurrenceUtc);
            }
        }

        return occurrences.OrderBy(occurrence => occurrence).ToList();
    }

    private static IEnumerable<TimeSpan> OccurrenceOffsets(PumpSchedule schedule)
    {
        yield return TimeSpan.Zero;
        if (schedule.EndTime is not TimeOnly endTime || schedule.IntervalMinutes is not int intervalMinutes) yield break;

        var start = schedule.StartTime.ToTimeSpan();
        var window = endTime.ToTimeSpan() - start;
        if (window <= TimeSpan.Zero) window += TimeSpan.FromDays(1);
        for (var elapsed = TimeSpan.FromMinutes(intervalMinutes); elapsed < window; elapsed += TimeSpan.FromMinutes(intervalMinutes))
            yield return elapsed;
    }

    private static bool Overlaps(long firstStart, long firstEnd, long secondStart, long secondEnd) =>
        firstStart < secondEnd && secondStart < firstEnd;
}
