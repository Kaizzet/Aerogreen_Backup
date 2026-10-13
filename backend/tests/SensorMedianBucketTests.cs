using System;
using System.Collections.Generic;
using IOTAgriBackend.Dtos.Sensors;
using Xunit;

namespace IOTAgriBackend.Tests;

public class SensorMedianBucketTests
{
    [Fact]
    public void Hourly_series_contains_empty_hours_and_preserves_medians()
    {
        var start = new DateTime(2026, 9, 17, 0, 0, 0, DateTimeKind.Utc);
        var source = new Dictionary<DateTime, SensorMedianBucket>
        {
            [start.AddHours(2)] = new(start.AddHours(2), 2, 3, 2, 2, 2, 2, 200, 3),
        };

        var buckets = SensorMedianBuckets.Complete(start, 24, TimeSpan.FromHours(1), source);

        Assert.Equal(24, buckets.Count);
        Assert.Equal(2, buckets[2].MedianTemperature);
        Assert.Equal(3, buckets[2].MedianSolutionTemperature);
        Assert.Equal(200, buckets[2].MedianLux);
        Assert.Equal(3, buckets[2].SampleCount);
        Assert.Null(buckets[0].MedianTemperature);
        Assert.Equal(0, buckets[0].SampleCount);
    }

    [Fact]
    public void Daily_series_contains_seven_days()
    {
        var start = new DateTime(2026, 9, 14, 0, 0, 0, DateTimeKind.Utc);

        var buckets = SensorMedianBuckets.Complete(start, 7, TimeSpan.FromDays(1), new Dictionary<DateTime, SensorMedianBucket>());

        Assert.Equal(7, buckets.Count);
        Assert.Equal(start.AddDays(6), buckets[6].BucketStart);
    }
}
