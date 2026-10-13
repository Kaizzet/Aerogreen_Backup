using IOTAgriBackend.Dtos.Pumps;
using Xunit;

namespace IOTAgriBackend.Tests;

public class PumpCommandRulesTests
{
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Empty_device_rejection_reason_is_normalized_to_null(string? reason)
    {
        Assert.Null(new PumpStatusMessage(null, false, false, reason).NormalizedReason);
    }

    [Fact]
    public void Device_reason_is_trimmed_and_truncated_at_512_characters()
    {
        var reason = new string('a', 513);
        var status = new PumpStatusMessage(null, false, false, " " + reason + " ");
        Assert.Equal(new string('a', 512), status.NormalizedReason);
        Assert.False(status.WasSuccessful);
    }

    [Fact]
    public void Legacy_acknowledgment_is_successful_and_explicit_false_is_failure()
    {
        Assert.True(new PumpStatusMessage(null, true).WasSuccessful);
        Assert.False(new PumpStatusMessage(null, false, false).WasSuccessful);
    }
}
