namespace IOTAgriBackend.Dtos.Dashboard;

public record AggregatedReadingBucket(
    DateTime BucketStart,
    double? AvgTemperature,
    double? MinTemperature,
    double? MaxTemperature,
    double? AvgSolutionTemperature,
    double? MinSolutionTemperature,
    double? MaxSolutionTemperature,
    double? AvgHumidity,
    double? MinHumidity,
    double? MaxHumidity,
    double? AvgPh,
    double? MinPh,
    double? MaxPh,
    double? AvgTds,
    double? MinTds,
    double? MaxTds,
    double? AvgWaterLevel,
    double? MinWaterLevel,
    double? MaxWaterLevel,
    double? AvgLux,
    double? MinLux,
    double? MaxLux,
    int SampleCount
);
