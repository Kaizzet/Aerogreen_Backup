namespace IOTAgriBackend.Dtos.Sensors;

public record SensorReadingResponse(
    Guid Id,
    double? Temperature,
    double? SolutionTemperature,
    double? Humidity,
    double? Ph,
    double? Tds,
    double? WaterLevel,
    double? Lux,
    DateTime RecordedAt
);
