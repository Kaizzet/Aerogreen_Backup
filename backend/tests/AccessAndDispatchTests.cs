using IOTAgriBackend.Models;
using IOTAgriBackend.Services;
using Xunit;

namespace IOTAgriBackend.Tests;

public class AccessAndDispatchTests
{
    [Fact]
    public void Production_owner_filter_rejects_other_users_and_devices()
    {
        var id = Guid.NewGuid();
        var predicate = DeviceAccess.OwnedDevice(id, "owner").Compile();
        Assert.True(predicate(new Device { Id = id, OwnerId = "owner" }));
        Assert.False(predicate(new Device { Id = id, OwnerId = "other" }));
        Assert.False(predicate(new Device { Id = Guid.NewGuid(), OwnerId = "owner" }));
        Assert.False(predicate(new Device { Id = id, OwnerId = null }));
    }

    private sealed class Clock : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => new(2030, 1, 1, 0, 0, 0, TimeSpan.Zero);
    }

    [Theory]
    [InlineData(false)] [InlineData(true)]
    public async Task Failed_or_cancelled_publish_remains_retryable_then_success_marks_occurrence(bool cancelled)
    {
        var occurrence = new PumpScheduleOccurrence { CommandId = Guid.Parse("11111111-1111-4111-8111-111111111111"), Schedule = new PumpSchedule(), OccurrenceUtc = DateTime.UnixEpoch };
        var command = new PumpCommand { Id = occurrence.CommandId };
        var calls = new List<Guid>();
        Task Failed(PumpCommand item, CancellationToken token)
        {
            calls.Add(item.Id);
            return Task.FromException(cancelled ? new OperationCanceledException() : new TimeoutException());
        }
        if (cancelled)
            await Assert.ThrowsAsync<OperationCanceledException>(() => PumpDispatchAttempt.PublishAsync(occurrence, command, Failed, new Clock(), default));
        else
            await Assert.ThrowsAsync<TimeoutException>(() => PumpDispatchAttempt.PublishAsync(occurrence, command, Failed, new Clock(), default));
        Assert.Null(occurrence.DispatchedAt);
        Assert.Null(occurrence.Schedule.LastDispatchedOccurrenceUtc);
        await PumpDispatchAttempt.PublishAsync(occurrence, command, (item, _) => { calls.Add(item.Id); return Task.CompletedTask; }, new Clock(), default);
        Assert.Equal([command.Id, command.Id], calls);
        Assert.Equal(new Clock().GetUtcNow().UtcDateTime, occurrence.DispatchedAt);
        Assert.Equal(occurrence.OccurrenceUtc, occurrence.Schedule.LastDispatchedOccurrenceUtc);
    }
}
