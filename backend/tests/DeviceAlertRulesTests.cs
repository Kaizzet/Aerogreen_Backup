using IOTAgriBackend.Models;
using IOTAgriBackend.Services;
using Xunit;

namespace IOTAgriBackend.Tests;

public class DeviceAlertRulesTests
{
    [Theory]
    [InlineData(35, 35, true)]
    [InlineData(34.9, 35, false)]
    public void Temperature_alert_triggers_at_or_above_threshold(double temperature, double threshold, bool expected)
    {
        var actual = DeviceAlertRules.IsUnsafe(
            DeviceAlertType.HighTemperature,
            temperature,
            null,
            threshold,
            null);

        Assert.Equal(expected, actual);
    }

    [Theory]
    [InlineData(20, 20, true)]
    [InlineData(20.1, 20, false)]
    public void Low_water_alert_triggers_at_or_below_threshold(double waterLevel, double threshold, bool expected)
    {
        var actual = DeviceAlertRules.IsUnsafe(
            DeviceAlertType.LowWaterLevel,
            null,
            waterLevel,
            null,
            threshold);

        Assert.Equal(expected, actual);
    }

    [Fact]
    public void Missing_measurement_or_threshold_does_not_resolve_or_trigger_an_alert()
    {
        Assert.Null(DeviceAlertRules.IsUnsafe(
            DeviceAlertType.HighTemperature,
            null,
            null,
            35,
            null));
        Assert.Null(DeviceAlertRules.IsUnsafe(
            DeviceAlertType.LowWaterLevel,
            null,
            10,
            null,
            null));
    }

    [Fact]
    public void Device_thresholds_override_global_defaults_independently()
    {
        var thresholds = DeviceAlertRules.EffectiveThresholds(42, null, 35, 20);

        Assert.Equal(42, thresholds.HighTemperatureC);
        Assert.Equal(20, thresholds.LowWaterLevelPercent);
    }
}
