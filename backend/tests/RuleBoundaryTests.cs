using IOTAgriBackend.Dtos.Alerts;
using IOTAgriBackend.Dtos.Pumps;
using IOTAgriBackend.Models;
using IOTAgriBackend.Services;
using Xunit;

namespace IOTAgriBackend.Tests;

public class RuleBoundaryTests
{
    [Theory]
    [InlineData(-1, false)] [InlineData(0, false)] [InlineData(1, true)]
    [InlineData(600, true)] [InlineData(601, false)]
    public void Pump_duration_and_empty_id_boundaries(int duration, bool valid)
    {
        Assert.Equal(valid, new PumpCommandRequest(Guid.NewGuid(), true, duration).IsValid(600));
        Assert.False(new PumpCommandRequest(Guid.Empty, true, duration).IsValid(600));
    }

    [Theory]
    [InlineData(0, true)] [InlineData(100, true)] [InlineData(-1, false)] [InlineData(101, false)]
    [InlineData(double.NaN, false)] [InlineData(double.PositiveInfinity, false)]
    public void Alert_water_threshold_boundaries(double water, bool valid) =>
        Assert.Equal(valid, new DeviceAlertSettingsRequest(null, water).IsValid);

    [Theory]
    [InlineData(0, 1, false)] [InlineData(1, 0, false)] [InlineData(1, 100, true)] [InlineData(1, 101, false)]
    public void Alert_pagination_boundaries(int page, int size, bool valid) =>
        Assert.Equal(valid, new DeviceAlertHistoryQuery(Page: page, PageSize: size).HasValidPagination);

    [Fact]
    public void Profile_maximum_length_is_accepted_and_trimmed()
    {
        var name = new string('a', ProfileRules.MaximumFullNameLength);
        Assert.Null(ProfileRules.Validate(" " + name + " ", " 12345678 ", out var normalized, out var phone));
        Assert.Equal(name, normalized);
        Assert.Equal("12345678", phone);
    }

    [Fact]
    public void Provisioning_alphabet_length_hash_and_case_are_real()
    {
        var code = ProvisioningCode.Create();
        Assert.Equal(12, code.Length);
        Assert.All(code, c => Assert.Contains(c, "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"));
        Assert.Equal(32, Convert.FromBase64String(ProvisioningCode.Hash(code)).Length);
        Assert.False(ProvisioningCode.Matches("abcd", ProvisioningCode.Hash("ABCD")));
    }

    [Theory]
    [InlineData("open", "closed", false)] [InlineData("closed", "in_progress", false)]
    [InlineData("open", "open", false)] [InlineData("closed", "open", true)]
    public void Ticket_transitions_enforce_production_state_machine(string current, string next, bool valid) =>
        Assert.Equal(valid, SupportTicketRules.IsValidTransition(current, next));

    [Fact]
    public void Administrator_can_unlock_last_admin_but_not_lock_or_change_self()
    {
        Assert.Null(AdminRoleRules.ValidateLock("actor", "target", false, true, 1));
        Assert.NotNull(AdminRoleRules.ValidateLock("actor", "target", true, true, 1));
        Assert.NotNull(AdminRoleRules.Validate("actor", "actor", "Admin", true, 2));
        Assert.Null(AdminRoleRules.Validate("actor", "target", "Admin", false, 1));
    }

    [Fact]
    public void Schedule_window_validation_and_disabled_due_occurrences()
    {
        var start = new TimeOnly(6, 0);
        Assert.NotNull(PumpScheduleRules.Validate(true, 128, start, 30, "Asia/Bangkok", 600));
        Assert.NotNull(PumpScheduleRules.Validate(true, 1, start, 30, "Asia/Bangkok", 600, start, 5));
        Assert.NotNull(PumpScheduleRules.Validate(true, 1, start, 60, "Asia/Bangkok", 600, new TimeOnly(7, 0), 1));
        Assert.NotNull(PumpScheduleRules.Validate(true, 1, start, 30, "Asia/Bangkok", 600, new TimeOnly(7, 0)));
        Assert.Null(PumpScheduleRules.Validate(true, 1, start, 59, "Asia/Bangkok", 600, new TimeOnly(7, 0), 1));
        var schedule = new PumpSchedule { IsEnabled = false, TimeZone = "Asia/Bangkok", WeekdayMask = 127, StartTime = start };
        Assert.Empty(PumpScheduleRules.GetDueOccurrencesUtc(schedule, new DateTime(2030, 1, 1, 0, 0, 0, DateTimeKind.Utc), TimeSpan.FromSeconds(90)));
        schedule.IsEnabled = true;
        Assert.Empty(PumpScheduleRules.GetDueOccurrencesUtc(schedule, DateTime.UnixEpoch, TimeSpan.Zero));
    }

    [Fact]
    public void Adjacent_schedule_windows_do_not_overlap_and_self_is_ignored()
    {
        var candidate = new PumpSchedule { IsEnabled = true, WeekdayMask = 1, StartTime = new TimeOnly(6, 0), DurationSeconds = 60 };
        var next = new PumpSchedule { IsEnabled = true, WeekdayMask = 1, StartTime = new TimeOnly(6, 1), DurationSeconds = 60 };
        Assert.False(PumpScheduleRules.Overlaps(candidate, [candidate, next]));
        next.StartTime = new TimeOnly(6, 0, 59);
        Assert.True(PumpScheduleRules.Overlaps(candidate, [next]));
    }
}
