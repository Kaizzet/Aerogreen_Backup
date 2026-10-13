using System.Security.Claims;
using System.Data;
using IOTAgriBackend.Data;
using IOTAgriBackend.Dtos.Alerts;
using IOTAgriBackend.Dtos.Devices;
using IOTAgriBackend.Dtos.Pumps;
using IOTAgriBackend.Models;
using IOTAgriBackend.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

namespace IOTAgriBackend.Endpoints;

public static class DeviceEndpoints
{
    public static IEndpointRouteBuilder MapDeviceEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/devices").WithTags("Devices").RequireAuthorization();

        group.MapPost("/", CreateAsync);
        group.MapGet("/", ListAsync);
        group.MapGet("/{id:guid}", GetAsync);
        group.MapPut("/{id:guid}", UpdateAsync);
        group.MapDelete("/{id:guid}", DeleteAsync);
        group.MapPost("/{id:guid}/pump/commands", SendPumpCommandAsync);
        group.MapGet("/{id:guid}/pump-commands", GetPumpCommandsAsync);
        group.MapGet("/{id:guid}/pump-schedules", ListPumpSchedulesAsync);
        group.MapPost("/{id:guid}/pump-schedules", CreatePumpScheduleAsync);
        group.MapPut("/{id:guid}/pump-schedules/{scheduleId:guid}", UpdatePumpScheduleAsync);
        group.MapDelete("/{id:guid}/pump-schedules/{scheduleId:guid}", DeletePumpScheduleAsync);
        group.MapGet("/{id:guid}/alert-settings", GetAlertSettingsAsync);
        group.MapPut("/{id:guid}/alert-settings", UpdateAlertSettingsAsync);
        group.MapGet("/{id:guid}/alerts", GetAlertsAsync);

        return app;
    }

    private static string? GetUserId(ClaimsPrincipal principal) =>
        principal.FindFirstValue(ClaimTypes.NameIdentifier);

    private static async Task<IResult> CreateAsync(
        CreateDeviceRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext db)
    {
        var userId = GetUserId(principal);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var device = new Device
        {
            Name = request.Name,
            // URL-safe (no '+' or '/') so the key can be used as an MQTT topic segment.
            DeviceKey = Convert.ToBase64String(System.Security.Cryptography.RandomNumberGenerator.GetBytes(32))
                .Replace('+', '-').Replace('/', '_').TrimEnd('='),
            OwnerId = userId,
        };

        db.Devices.Add(device);
        await db.SaveChangesAsync();

        return Results.Created(
            $"/api/devices/{device.Id}",
            new { device.Id, device.Name, device.DeviceKey, device.CreatedAt });
    }

    private static async Task<IResult> ListAsync(ClaimsPrincipal principal, ApplicationDbContext db)
    {
        var userId = GetUserId(principal);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var devices = await db.Devices
            .Where(d => d.OwnerId == userId)
            .OrderByDescending(d => d.CreatedAt)
            .Select(d => new DeviceResponse(d.Id, d.Name, d.IsOnline, d.LastSeenAt, d.CreatedAt))
            .ToListAsync();

        return Results.Ok(devices);
    }

    private static async Task<IResult> GetAsync(Guid id, ClaimsPrincipal principal, ApplicationDbContext db)
    {
        var userId = GetUserId(principal);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var device = await db.Devices.FirstOrDefaultAsync(d => d.Id == id && d.OwnerId == userId);
        if (device is null)
        {
            return Results.NotFound();
        }

        return Results.Ok(new DeviceResponse(device.Id, device.Name, device.IsOnline, device.LastSeenAt, device.CreatedAt));
    }

    private static async Task<IResult> UpdateAsync(
        Guid id,
        UpdateDeviceRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext db)
    {
        var userId = GetUserId(principal);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var device = await db.Devices.FirstOrDefaultAsync(d => d.Id == id && d.OwnerId == userId);
        if (device is null)
        {
            return Results.NotFound();
        }

        device.Name = request.Name;
        await db.SaveChangesAsync();

        return Results.Ok(new DeviceResponse(device.Id, device.Name, device.IsOnline, device.LastSeenAt, device.CreatedAt));
    }

    private static async Task<IResult> DeleteAsync(Guid id, ClaimsPrincipal principal, ApplicationDbContext db)
    {
        var userId = GetUserId(principal);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var device = await db.Devices.FirstOrDefaultAsync(d => d.Id == id && d.OwnerId == userId);
        if (device is null)
        {
            return Results.NotFound();
        }

        db.Devices.Remove(device);
        await db.SaveChangesAsync();

        return Results.NoContent();
    }

    private static async Task<IResult> SendPumpCommandAsync(
        Guid id,
        PumpCommandRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext db,
        IConfiguration configuration,
        MqttIngestionService mqtt,
        CancellationToken cancellationToken)
    {
        var userId = GetUserId(principal);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var device = await db.Devices.FirstOrDefaultAsync(d => d.Id == id && d.OwnerId == userId, cancellationToken);
        if (device is null)
        {
            return Results.NotFound();
        }

        var maximumDurationSeconds = configuration.GetValue<int?>("PumpControl:MaximumDurationSeconds") ?? 600;
        if (maximumDurationSeconds <= 0)
        {
            return Results.Problem("PumpControl:MaximumDurationSeconds must be positive.", statusCode: StatusCodes.Status503ServiceUnavailable);
        }

        if (!request.IsValid(maximumDurationSeconds))
        {
            return Results.BadRequest(new { error = "commandId, on duration, and a valid duration are required." });
        }

        var existing = await db.PumpCommands.FirstOrDefaultAsync(c => c.Id == request.CommandId, cancellationToken);
        if (existing is not null)
        {
            if (existing.DeviceId != device.Id || existing.IsOn != request.IsOn || existing.DurationSeconds != request.DurationSeconds)
            {
                return Results.Conflict(new { error = "commandId was already used for a different command." });
            }

            return Results.Ok(ToResponse(existing));
        }

        var command = new PumpCommand
        {
            Id = request.CommandId,
            DeviceId = device.Id,
            IsOn = request.IsOn,
            DurationSeconds = request.DurationSeconds,
            Source = PumpCommandSource.Manual,
        };
        db.PumpCommands.Add(command);

        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            return Results.Conflict(new { error = "commandId is already being processed." });
        }

        try
        {
            await mqtt.PublishPumpCommandAsync(device.DeviceKey, command, cancellationToken);
        }
        catch (InvalidOperationException)
        {
            return Results.Problem(
                "Pump command is pending because MQTT is unavailable.",
                statusCode: StatusCodes.Status503ServiceUnavailable);
        }

        return Results.Created($"/api/devices/{device.Id}/pump/commands/{command.Id}", ToResponse(command));
    }

    private static PumpCommandResponse ToResponse(PumpCommand command) => new(
        command.Id,
        command.IsOn,
        command.DurationSeconds,
        command.Status,
        command.IssuedAt,
        command.AcknowledgedAt,
        command.AcknowledgedIsOn);

    private static async Task<IResult> GetPumpCommandsAsync(
        Guid id,
        ClaimsPrincipal principal,
        ApplicationDbContext db,
        [AsParameters] PumpCommandHistoryQuery query)
    {
        var userId = GetUserId(principal);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var ownsDevice = await db.Devices.AnyAsync(d => d.Id == id && d.OwnerId == userId);
        if (!ownsDevice)
        {
            return Results.NotFound();
        }

        if (!query.TryGetRange(DateTimeOffset.UtcNow, out var rangeStart, out var rangeEnd))
        {
            return Results.BadRequest(new { error = "Range must be positive and no more than 31 days." });
        }

        if (!query.HasValidPagination)
        {
            return Results.BadRequest(new { error = "page must be positive and pageSize must be between 1 and 100." });
        }

        var commands = db.PumpCommands.Where(command =>
            command.DeviceId == id && command.IssuedAt >= rangeStart && command.IssuedAt < rangeEnd);
        var totalCount = await commands.CountAsync();
        var items = await commands
            .OrderByDescending(command => command.IssuedAt)
            .ThenByDescending(command => command.Id)
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .Select(command => new PumpCommandHistoryResponse(
                command.Id,
                command.IsOn,
                command.DurationSeconds,
                command.Source,
                command.Status,
                command.IssuedAt,
                command.AcknowledgedAt,
                command.AcknowledgedIsOn,
                command.FailureReason))
            .ToListAsync();

        return Results.Ok(new PumpCommandHistoryPage(items, query.Page, query.PageSize, totalCount));
    }

    private static async Task<IResult> ListPumpSchedulesAsync(Guid id, ClaimsPrincipal principal, ApplicationDbContext db)
    {
        var userId = GetUserId(principal);
        if (userId is null) return Results.Unauthorized();

        var ownsDevice = await db.Devices.AnyAsync(device => device.Id == id && device.OwnerId == userId);
        if (!ownsDevice) return Results.NotFound();

        var schedules = await db.PumpSchedules.Where(schedule => schedule.DeviceId == id)
            .OrderBy(schedule => schedule.StartTime).ThenBy(schedule => schedule.Id)
            .ToListAsync();
        return Results.Ok(schedules.Select(ToResponse).ToList());
    }

    private static async Task<IResult> CreatePumpScheduleAsync(
        Guid id,
        PumpScheduleRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext db,
        IConfiguration configuration)
    {
        var userId = GetUserId(principal);
        if (userId is null) return Results.Unauthorized();
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        if (!await db.Devices.AnyAsync(device => device.Id == id && device.OwnerId == userId)) return Results.NotFound();

        var maximumDurationSeconds = configuration.GetValue<int?>("PumpControl:MaximumDurationSeconds") ?? 600;
        if (maximumDurationSeconds <= 0) return Results.Problem("PumpControl:MaximumDurationSeconds must be positive.", statusCode: StatusCodes.Status503ServiceUnavailable);

        var error = PumpScheduleRules.Validate(request.IsEnabled, request.WeekdayMask, request.StartTime, request.DurationSeconds, request.TimeZone, maximumDurationSeconds, request.EndTime, request.IntervalMinutes);
        if (error is not null) return Results.BadRequest(new { error });

        var schedule = new PumpSchedule
        {
            DeviceId = id,
            IsEnabled = request.IsEnabled!.Value,
            WeekdayMask = request.WeekdayMask,
            StartTime = request.StartTime!.Value,
            EndTime = request.EndTime,
            IntervalMinutes = request.IntervalMinutes,
            DurationSeconds = request.DurationSeconds,
            TimeZone = request.TimeZone!,
        };
        var existingSchedules = await db.PumpSchedules.Where(existing => existing.DeviceId == id).ToListAsync();
        if (PumpScheduleRules.Overlaps(schedule, existingSchedules)) return Results.BadRequest(new { error = "Schedule overlaps an enabled schedule for this device." });

        db.PumpSchedules.Add(schedule);
        var saveResult = await SavePumpScheduleAsync(db, transaction);
        if (saveResult is not null) return saveResult;
        return Results.Created($"/api/devices/{id}/pump-schedules/{schedule.Id}", ToResponse(schedule));
    }

    private static async Task<IResult> UpdatePumpScheduleAsync(
        Guid id,
        Guid scheduleId,
        PumpScheduleRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext db,
        IConfiguration configuration)
    {
        var userId = GetUserId(principal);
        if (userId is null) return Results.Unauthorized();
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);

        var schedule = await db.PumpSchedules.FirstOrDefaultAsync(candidate =>
            candidate.Id == scheduleId && candidate.DeviceId == id && candidate.Device!.OwnerId == userId);
        if (schedule is null) return Results.NotFound();

        var maximumDurationSeconds = configuration.GetValue<int?>("PumpControl:MaximumDurationSeconds") ?? 600;
        if (maximumDurationSeconds <= 0) return Results.Problem("PumpControl:MaximumDurationSeconds must be positive.", statusCode: StatusCodes.Status503ServiceUnavailable);

        var error = PumpScheduleRules.Validate(request.IsEnabled, request.WeekdayMask, request.StartTime, request.DurationSeconds, request.TimeZone, maximumDurationSeconds, request.EndTime, request.IntervalMinutes);
        if (error is not null) return Results.BadRequest(new { error });

        schedule.IsEnabled = request.IsEnabled!.Value;
        schedule.WeekdayMask = request.WeekdayMask;
        schedule.StartTime = request.StartTime!.Value;
        schedule.EndTime = request.EndTime;
        schedule.IntervalMinutes = request.IntervalMinutes;
        schedule.DurationSeconds = request.DurationSeconds;
        schedule.TimeZone = request.TimeZone!;

        var existingSchedules = await db.PumpSchedules.Where(existing => existing.DeviceId == id && existing.Id != scheduleId).ToListAsync();
        if (PumpScheduleRules.Overlaps(schedule, existingSchedules)) return Results.BadRequest(new { error = "Schedule overlaps an enabled schedule for this device." });

        var saveResult = await SavePumpScheduleAsync(db, transaction);
        if (saveResult is not null) return saveResult;
        return Results.Ok(ToResponse(schedule));
    }

    private static async Task<IResult> DeletePumpScheduleAsync(Guid id, Guid scheduleId, ClaimsPrincipal principal, ApplicationDbContext db)
    {
        var userId = GetUserId(principal);
        if (userId is null) return Results.Unauthorized();

        var schedule = await db.PumpSchedules.FirstOrDefaultAsync(candidate =>
            candidate.Id == scheduleId && candidate.DeviceId == id && candidate.Device!.OwnerId == userId);
        if (schedule is null) return Results.NotFound();

        db.PumpSchedules.Remove(schedule);
        await db.SaveChangesAsync();
        return Results.NoContent();
    }

    private static PumpScheduleResponse ToResponse(PumpSchedule schedule) => new(
        schedule.Id,
        schedule.DeviceId,
        schedule.IsEnabled,
        schedule.WeekdayMask,
        schedule.StartTime,
        schedule.EndTime,
        schedule.IntervalMinutes,
        schedule.DurationSeconds,
        schedule.TimeZone,
        schedule.LastDispatchedOccurrenceUtc,
        schedule.CreatedAt);

    private static async Task<IResult?> SavePumpScheduleAsync(
        ApplicationDbContext db,
        Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction transaction)
    {
        try
        {
            await db.SaveChangesAsync();
            await transaction.CommitAsync();
            return null;
        }
        catch (Npgsql.PostgresException exception) when (exception.SqlState == "40001")
        {
            return Results.Conflict(new { error = "Schedule changed concurrently. Retry." });
        }
    }

    private static async Task<IResult> GetAlertSettingsAsync(
        Guid id,
        ClaimsPrincipal principal,
        ApplicationDbContext db)
    {
        var userId = GetUserId(principal);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var settings = await db.Devices
            .Where(device => device.Id == id && device.OwnerId == userId)
            .Select(device => new DeviceAlertSettingsResponse(
                device.HighTemperatureAlertC,
                device.LowWaterLevelAlertPercent))
            .FirstOrDefaultAsync();

        return settings is null ? Results.NotFound() : Results.Ok(settings);
    }

    private static async Task<IResult> UpdateAlertSettingsAsync(
        Guid id,
        DeviceAlertSettingsRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext db)
    {
        var userId = GetUserId(principal);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var device = await db.Devices.FirstOrDefaultAsync(device => device.Id == id && device.OwnerId == userId);
        if (device is null)
        {
            return Results.NotFound();
        }

        if (!request.IsValid)
        {
            return Results.BadRequest(new { error = "Thresholds must be finite and water level must be between 0 and 100." });
        }

        device.HighTemperatureAlertC = request.HighTemperatureC;
        device.LowWaterLevelAlertPercent = request.LowWaterLevelPercent;
        await db.SaveChangesAsync();

        return Results.Ok(new DeviceAlertSettingsResponse(
            device.HighTemperatureAlertC,
            device.LowWaterLevelAlertPercent));
    }

    private static async Task<IResult> GetAlertsAsync(
        Guid id,
        ClaimsPrincipal principal,
        ApplicationDbContext db,
        [AsParameters] DeviceAlertHistoryQuery query)
    {
        var userId = GetUserId(principal);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var ownsDevice = await db.Devices.AnyAsync(device => device.Id == id && device.OwnerId == userId);
        if (!ownsDevice)
        {
            return Results.NotFound();
        }

        if (!query.HasValidStatus)
        {
            return Results.BadRequest(new { error = "status must be active, resolved, or all." });
        }

        if (!query.HasValidPagination)
        {
            return Results.BadRequest(new { error = "page must be positive and pageSize must be between 1 and 100." });
        }

        var alerts = db.DeviceAlerts.Where(alert => alert.DeviceId == id);
        if (query.Status == "active")
        {
            alerts = alerts.Where(alert => alert.ResolvedAt == null);
        }
        else if (query.Status == "resolved")
        {
            alerts = alerts.Where(alert => alert.ResolvedAt != null);
        }

        var totalCount = await alerts.CountAsync();
        var items = await alerts
            .OrderByDescending(alert => alert.TriggeredAt)
            .ThenByDescending(alert => alert.Id)
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToListAsync();

        return Results.Ok(new DeviceAlertPage(
            items.Select(DeviceAlertResponse.From).ToList(),
            query.Page,
            query.PageSize,
            totalCount));
    }
}
