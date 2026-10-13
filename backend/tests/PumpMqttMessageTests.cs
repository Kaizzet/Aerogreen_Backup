using System.Text.Json;
using IOTAgriBackend.Dtos.Pumps;
using Xunit;

namespace IOTAgriBackend.Tests;

public class PumpMqttMessageTests
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    [Fact]
    public void Legacy_status_without_success_remains_acknowledged()
    {
        var status = JsonSerializer.Deserialize<PumpStatusMessage>(
            """{"commandId":"ad2ff566-68e4-4e96-a799-9bb617c0e491","isOn":true}""",
            JsonOptions);

        Assert.NotNull(status);
        Assert.True(status.WasSuccessful);
        Assert.Null(status.NormalizedReason);
    }

    [Fact]
    public void Safety_rejection_preserves_a_bounded_reason()
    {
        var status = JsonSerializer.Deserialize<PumpStatusMessage>(
            """{"commandId":"ad2ff566-68e4-4e96-a799-9bb617c0e491","isOn":false,"success":false,"reason":" LOW_WATER "}""",
            JsonOptions);

        Assert.NotNull(status);
        Assert.False(status.WasSuccessful);
        Assert.Equal("LOW_WATER", status.NormalizedReason);
    }
}
