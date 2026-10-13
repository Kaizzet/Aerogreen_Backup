using System;
using IOTAgriBackend.Models;
using IOTAgriBackend.Services;
using Xunit;

namespace IOTAgriBackend.Tests;

public class PumpScheduleRulesTests
{
    [Fact]
    public void Validates_mask_duration_and_iana_time_zone()
    {
        Assert.Null(PumpScheduleRules.Validate(true, 127, new TimeOnly(6, 0), 600, "Asia/Bangkok", 600));
        Assert.NotNull(PumpScheduleRules.Validate(null, 1, new TimeOnly(6, 0), 60, "Asia/Bangkok", 600));
        Assert.NotNull(PumpScheduleRules.Validate(true, 1, null, 60, "Asia/Bangkok", 600));
        Assert.NotNull(PumpScheduleRules.Validate(true, 0, new TimeOnly(6, 0), 600, "Asia/Bangkok", 600));
        Assert.NotNull(PumpScheduleRules.Validate(true, 1, new TimeOnly(6, 0), 601, "Asia/Bangkok", 600));
        Assert.NotNull(PumpScheduleRules.Validate(true, 1, new TimeOnly(6, 0), 60, "SE Asia Standard Time", 600));
    }

    [Fact]
    public void Detects_overlap_across_week_boundary()
    {
        var saturdayLate = new PumpSchedule
        {
            WeekdayMask = 64,
            StartTime = new TimeOnly(23, 55),
            DurationSeconds = 600,
            IsEnabled = true,
        };
        var sundayEarly = new PumpSchedule
        {
            WeekdayMask = 1,
            StartTime = new TimeOnly(0, 0),
            DurationSeconds = 600,
            IsEnabled = true,
        };

        Assert.True(PumpScheduleRules.Overlaps(saturdayLate, [sundayEarly]));
        sundayEarly.IsEnabled = false;
        Assert.False(PumpScheduleRules.Overlaps(saturdayLate, [sundayEarly]));
    }

    [Fact]
    public void Detects_overlap_for_an_overnight_interval()
    {
        var saturdayWindow = new PumpSchedule
        {
            WeekdayMask = 64,
            StartTime = new TimeOnly(23, 30),
            EndTime = new TimeOnly(1, 0),
            IntervalMinutes = 30,
            DurationSeconds = 60,
            IsEnabled = true,
        };
        var sundayMidnight = new PumpSchedule
        {
            WeekdayMask = 1,
            StartTime = new TimeOnly(0, 0),
            DurationSeconds = 60,
            IsEnabled = true,
        };

        Assert.True(PumpScheduleRules.Overlaps(saturdayWindow, [sundayMidnight]));
    }

    [Fact]
    public void Finds_only_a_current_valid_occurrence()
    {
        var bangkokSunday = new PumpSchedule
        {
            IsEnabled = true,
            WeekdayMask = 1,
            StartTime = new TimeOnly(6, 0),
            TimeZone = "Asia/Bangkok",
        };
        var dueNow = new DateTime(2026, 1, 3, 23, 0, 0, DateTimeKind.Utc);

        Assert.True(PumpScheduleRules.TryGetDueOccurrenceUtc(bangkokSunday, dueNow, TimeSpan.FromSeconds(90), out var occurrence));
        Assert.Equal(dueNow, occurrence);
        Assert.False(PumpScheduleRules.TryGetDueOccurrenceUtc(bangkokSunday, dueNow.AddMinutes(2), TimeSpan.FromSeconds(90), out _));
        bangkokSunday.IsEnabled = false;
        Assert.False(PumpScheduleRules.TryGetDueOccurrenceUtc(bangkokSunday, dueNow, TimeSpan.FromSeconds(90), out _));
    }

    [Fact]
    public void Finds_each_interval_occurrence_inside_the_configured_window()
    {
        var schedule = new PumpSchedule
        {
            IsEnabled = true,
            WeekdayMask = 1,
            StartTime = new TimeOnly(6, 0),
            EndTime = new TimeOnly(7, 0),
            IntervalMinutes = 30,
            DurationSeconds = 30,
            TimeZone = "Asia/Bangkok",
        };
        var dueNow = new DateTime(2026, 1, 3, 23, 30, 0, DateTimeKind.Utc);

        var occurrences = PumpScheduleRules.GetDueOccurrencesUtc(schedule, dueNow, TimeSpan.FromSeconds(90));

        Assert.Equal([dueNow], occurrences);
    }

    [Fact]
    public void Skips_nonexistent_dst_time_and_uses_one_fallback_occurrence()
    {
        var newYorkSunday = new PumpSchedule
        {
            IsEnabled = true,
            WeekdayMask = 1,
            StartTime = new TimeOnly(2, 30),
            TimeZone = "America/New_York",
        };
        var springForwardUtc = new DateTime(2026, 3, 8, 7, 30, 0, DateTimeKind.Utc);

        Assert.False(PumpScheduleRules.TryGetDueOccurrenceUtc(newYorkSunday, springForwardUtc, TimeSpan.FromMinutes(90), out _));

        newYorkSunday.StartTime = new TimeOnly(1, 30);
        var zone = TimeZoneInfo.FindSystemTimeZoneById(newYorkSunday.TimeZone);
        var expected = TimeZoneInfo.ConvertTimeToUtc(new DateTime(2026, 11, 1, 1, 30, 0, DateTimeKind.Unspecified), zone);

        Assert.True(PumpScheduleRules.TryGetDueOccurrenceUtc(newYorkSunday, expected, TimeSpan.FromSeconds(90), out var occurrence));
        Assert.Equal(expected, occurrence);
    }
}
