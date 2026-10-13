namespace IOTAgriBackend.Dtos.Sensors;

public record SensorMedianBucket(
    DateTime BucketStart,
    double? MedianTemperature,
    double? MedianSolutionTemperature,
    double? MedianHumidity,
    double? MedianPh,
    double? MedianTds,
    double? MedianWaterLevel,
    double? MedianLux,
    int SampleCount
);

public static class SensorMedianBuckets
{
    public static IReadOnlyList<SensorMedianBucket> Complete(
        DateTime start,
        int count,
        TimeSpan interval,
        IReadOnlyDictionary<DateTime, SensorMedianBucket> buckets)
        => Enumerable.Range(0, count)
            .Select(index =>
            {
                var bucketStart = start.AddTicks(interval.Ticks * index);
                return buckets.TryGetValue(bucketStart, out var bucket)
                    ? bucket
                    : new SensorMedianBucket(bucketStart, null, null, null, null, null, null, null, 0);
            })
            .ToList();
}
