using System.Security.Claims;
using IOTAgriBackend.Data;
using IOTAgriBackend.Dtos.Dashboard;
using IOTAgriBackend.Dtos.Sensors;
using Microsoft.EntityFrameworkCore;

namespace IOTAgriBackend.Endpoints;

public static class SensorEndpoints
{
    private static readonly HashSet<string> AllowedIntervals = new(StringComparer.OrdinalIgnoreCase)
    {
        "minute", "hour", "day", "week", "month",
    };

    public static IEndpointRouteBuilder MapSensorEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/devices/{deviceId:guid}/readings")
            .WithTags("Sensors")
            .RequireAuthorization();
        group.MapGet("/", GetReadingsAsync);
        group.MapGet("/aggregated", GetAggregatedReadingsAsync);
        group.MapGet("/medians/hourly", GetHourlyMediansAsync);
        group.MapGet("/medians/daily", GetDailyMediansAsync);

        return app;
    }

    private static async Task<IResult> GetReadingsAsync(
        Guid deviceId,
        ClaimsPrincipal principal,
        ApplicationDbContext db,
        int take = 50)
    {
        var userId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var ownsDevice = await db.Devices.AnyAsync(d => d.Id == deviceId && d.OwnerId == userId);
        if (!ownsDevice)
        {
            return Results.NotFound();
        }

        var readings = await db.SensorReadings
            .Where(r => r.DeviceId == deviceId)
            .OrderByDescending(r => r.RecordedAt)
            .Take(Math.Clamp(take, 1, 500))
            .Select(r => new SensorReadingResponse(r.Id, r.Temperature, r.SolutionTemperature, r.Humidity, r.Ph, r.Tds, r.WaterLevel, r.Lux, r.RecordedAt))
            .ToListAsync();

        return Results.Ok(readings);
    }

    private static async Task<IResult> GetAggregatedReadingsAsync(
        Guid deviceId,
        ClaimsPrincipal principal,
        ApplicationDbContext db,
        string interval = "hour",
        DateTime? from = null,
        DateTime? to = null)
    {
        var userId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        if (!AllowedIntervals.Contains(interval))
        {
            return Results.BadRequest($"Invalid interval. Allowed values: {string.Join(", ", AllowedIntervals)}.");
        }

        var ownsDevice = await db.Devices.AnyAsync(d => d.Id == deviceId && d.OwnerId == userId);
        if (!ownsDevice)
        {
            return Results.NotFound();
        }

        var rangeEnd = to ?? DateTime.UtcNow;
        var rangeStart = from ?? rangeEnd.AddDays(-7);

        // Raw SQL (not raw string concatenation): {n} placeholders become bound Npgsql parameters, so this is not
        // vulnerable to SQL injection despite `interval` being caller-supplied. EF Core's GroupBy translation for
        // this many aggregates over a GroupBy key derived from a mapped scalar function does not translate to SQL.
        var buckets = await db.Database.SqlQueryRaw<AggregatedReadingBucket>(
            """
            SELECT date_trunc({0}, "RecordedAt") AS "BucketStart",
                   AVG("Temperature") AS "AvgTemperature", MIN("Temperature") AS "MinTemperature", MAX("Temperature") AS "MaxTemperature",
                   AVG("SolutionTemperature") AS "AvgSolutionTemperature", MIN("SolutionTemperature") AS "MinSolutionTemperature", MAX("SolutionTemperature") AS "MaxSolutionTemperature",
                   AVG("Humidity") AS "AvgHumidity", MIN("Humidity") AS "MinHumidity", MAX("Humidity") AS "MaxHumidity",
                   AVG("Ph") AS "AvgPh", MIN("Ph") AS "MinPh", MAX("Ph") AS "MaxPh",
                   AVG("Tds") AS "AvgTds", MIN("Tds") AS "MinTds", MAX("Tds") AS "MaxTds",
                   AVG("WaterLevel") AS "AvgWaterLevel", MIN("WaterLevel") AS "MinWaterLevel", MAX("WaterLevel") AS "MaxWaterLevel",
                   AVG("Lux") AS "AvgLux", MIN("Lux") AS "MinLux", MAX("Lux") AS "MaxLux",
                   CAST(COUNT(*) AS integer) AS "SampleCount"
            FROM "SensorReadings"
            WHERE "DeviceId" = {1} AND "RecordedAt" >= {2} AND "RecordedAt" <= {3}
            GROUP BY date_trunc({0}, "RecordedAt")
            ORDER BY 1
            """,
            interval, deviceId, rangeStart, rangeEnd)
            .ToListAsync();

        return Results.Ok(buckets);
    }

    private static async Task<IResult> GetHourlyMediansAsync(
        Guid deviceId,
        DateOnly date,
        ClaimsPrincipal principal,
        ApplicationDbContext db)
    {
        var userId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var ownsDevice = await db.Devices.AnyAsync(d => d.Id == deviceId && d.OwnerId == userId);
        if (!ownsDevice)
        {
            return Results.NotFound();
        }

        var start = date.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        var buckets = await GetMedianBucketsAsync(db, deviceId, start, start.AddDays(1), "hour");
        return Results.Ok(SensorMedianBuckets.Complete(
            start,
            24,
            TimeSpan.FromHours(1),
            buckets.ToDictionary(bucket => bucket.BucketStart)));
    }

    private static async Task<IResult> GetDailyMediansAsync(
        Guid deviceId,
        DateOnly weekStart,
        ClaimsPrincipal principal,
        ApplicationDbContext db)
    {
        if (weekStart.DayOfWeek != DayOfWeek.Monday)
        {
            return Results.BadRequest(new { error = "weekStart must be a Monday." });
        }

        var userId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var ownsDevice = await db.Devices.AnyAsync(d => d.Id == deviceId && d.OwnerId == userId);
        if (!ownsDevice)
        {
            return Results.NotFound();
        }

        var start = weekStart.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        var buckets = await GetMedianBucketsAsync(db, deviceId, start, start.AddDays(7), "day");
        return Results.Ok(SensorMedianBuckets.Complete(
            start,
            7,
            TimeSpan.FromDays(1),
            buckets.ToDictionary(bucket => bucket.BucketStart)));
    }

    private static Task<List<SensorMedianBucket>> GetMedianBucketsAsync(
        ApplicationDbContext db,
        Guid deviceId,
        DateTime rangeStart,
        DateTime rangeEnd,
        string interval)
        => db.Database.SqlQueryRaw<SensorMedianBucket>(
            """
            SELECT date_trunc({0}, "RecordedAt") AS "BucketStart",
                   percentile_cont(0.5) WITHIN GROUP (ORDER BY "Temperature") AS "MedianTemperature",
                   percentile_cont(0.5) WITHIN GROUP (ORDER BY "SolutionTemperature") AS "MedianSolutionTemperature",
                   percentile_cont(0.5) WITHIN GROUP (ORDER BY "Humidity") AS "MedianHumidity",
                   percentile_cont(0.5) WITHIN GROUP (ORDER BY "Ph") AS "MedianPh",
                   percentile_cont(0.5) WITHIN GROUP (ORDER BY "Tds") AS "MedianTds",
                   percentile_cont(0.5) WITHIN GROUP (ORDER BY "WaterLevel") AS "MedianWaterLevel",
                   percentile_cont(0.5) WITHIN GROUP (ORDER BY "Lux") AS "MedianLux",
                   CAST(COUNT(*) AS integer) AS "SampleCount"
            FROM "SensorReadings"
            WHERE "DeviceId" = {1} AND "RecordedAt" >= {2} AND "RecordedAt" < {3}
            GROUP BY date_trunc({0}, "RecordedAt")
            ORDER BY 1
            """,
            interval, deviceId, rangeStart, rangeEnd)
            .ToListAsync();
}
