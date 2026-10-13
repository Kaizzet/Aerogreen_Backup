namespace IOTAgriBackend.Dtos.Sensors;

public record SensorReadingRequest(
    double? Temperature,
    double? SolutionTemperature,
    double? Humidity,
    double? Ph,
    double? Tds,
    double? WaterLevel,
    double? Lux
);
