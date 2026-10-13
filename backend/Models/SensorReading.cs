namespace IOTAgriBackend.Models;

public class SensorReading
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid DeviceId { get; set; }
    public Device? Device { get; set; }

    public double? Temperature { get; set; }
    public double? SolutionTemperature { get; set; }
    public double? Humidity { get; set; }
    public double? Ph { get; set; }
    public double? Tds { get; set; }
    public double? WaterLevel { get; set; }
    public double? Lux { get; set; }

    public DateTime RecordedAt { get; set; } = DateTime.UtcNow;
}
