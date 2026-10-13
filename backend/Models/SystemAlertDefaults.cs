namespace IOTAgriBackend.Models;

public class SystemAlertDefaults
{
    public const double DefaultHighTemperatureC = 35;
    public const double DefaultLowWaterLevelPercent = 20;

    public int Id { get; set; } = 1;
    public double HighTemperatureC { get; set; } = DefaultHighTemperatureC;
    public double LowWaterLevelPercent { get; set; } = DefaultLowWaterLevelPercent;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
