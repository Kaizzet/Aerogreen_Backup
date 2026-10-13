using System.Text.Json;
using IOTAgriBackend.Dtos.Sensors;
using Xunit;

namespace IOTAgriBackend.Tests;

public class SensorReadingContractTests
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    [Fact]
    public void Esp32_payload_maps_all_aerogreen_sensor_values()
    {
        const string payload =
            """
            {
              "temperature": 29.1,
              "solutionTemperature": 26.7,
              "humidity": 73.2,
              "tds": 520,
              "waterLevel": 71.3
            }
            """;

        var reading = JsonSerializer.Deserialize<SensorReadingRequest>(payload, JsonOptions);

        Assert.NotNull(reading);
        Assert.Equal(29.1, reading.Temperature);
        Assert.Equal(26.7, reading.SolutionTemperature);
        Assert.Equal(73.2, reading.Humidity);
        Assert.Equal(520, reading.Tds);
        Assert.Equal(71.3, reading.WaterLevel);
    }
}
