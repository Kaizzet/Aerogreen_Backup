using IOTAgriBackend.Models;

namespace IOTAgriBackend.Services;

public static class PumpDispatchAttempt
{
    // Persistence/uniqueness remain the responsibility of the dispatcher store.
    public static async Task PublishAsync(PumpScheduleOccurrence occurrence, PumpCommand command,
        Func<PumpCommand, CancellationToken, Task> publish, TimeProvider clock, CancellationToken cancellationToken)
    {
        await publish(command, cancellationToken);
        occurrence.DispatchedAt = clock.GetUtcNow().UtcDateTime;
        occurrence.Schedule!.LastDispatchedOccurrenceUtc = occurrence.OccurrenceUtc;
    }
}
