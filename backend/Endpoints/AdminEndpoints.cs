using System.Security.Claims;
using System.Data;
using System.Text;
using IOTAgriBackend.Data;
using IOTAgriBackend.Dtos.Admin;
using IOTAgriBackend.Dtos.Pumps;
using IOTAgriBackend.Dtos.Sensors;
using IOTAgriBackend.Models;
using IOTAgriBackend.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace IOTAgriBackend.Endpoints;

public static class AdminEndpoints
{
    public static IEndpointRouteBuilder MapAdminEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/admin").WithTags("Admin").RequireAuthorization("AdminOnly");
        group.MapGet("/users", ListUsersAsync);
        group.MapGet("/users/{userId}", GetUserAsync);
        group.MapPut("/users/{userId}/role", UpdateRoleAsync);
        group.MapPut("/users/{userId}/lock", UpdateLockAsync);
        group.MapGet("/devices", ListDevicesAsync);
        group.MapGet("/devices/{id:guid}", GetDeviceAsync);
        group.MapGet("/devices/{id:guid}/readings", GetReadingsAsync);
        group.MapGet("/devices/{id:guid}/pump-commands", GetPumpHistoryAsync);
        group.MapPut("/devices/{id:guid}/owner", UpdateDeviceOwnerAsync);
        group.MapGet("/audit-logs", ListAuditLogsAsync);
        group.MapGet("/overview", GetOverviewAsync);
        group.MapGet("/reports/summary", GetReportSummaryAsync);
        group.MapGet("/reports.csv", DownloadReportCsvAsync);
        group.MapGet("/status", GetStatusAsync);
        group.MapGet("/settings/alert-defaults", GetAlertDefaultsAsync);
        group.MapPut("/settings/alert-defaults", UpdateAlertDefaultsAsync);
        return app;
    }

    private static bool HasValidPagination(int page, int pageSize) => page > 0 && pageSize is >= 1 and <= 100;

    private static string? GetUserId(ClaimsPrincipal principal) => principal.FindFirstValue(ClaimTypes.NameIdentifier);

    private static async Task<IResult> ListUsersAsync(
        UserManager<ApplicationUser> userManager,
        ApplicationDbContext db,
        string? search = null,
        string? filter = null,
        int page = 1,
        int pageSize = 50)
    {
        if (!HasValidPagination(page, pageSize)) return Results.BadRequest(new { error = "page must be positive and pageSize must be between 1 and 100." });
        var filterError = AdminRoleRules.ValidateListFilter(filter, out var normalizedFilter);
        if (filterError is not null) return Results.BadRequest(new { error = filterError });

        var usersQuery = userManager.Users.AsQueryable();
        if (!string.IsNullOrWhiteSpace(search))
        {
            var pattern = $"%{search.Trim()}%";
            usersQuery = usersQuery.Where(user =>
                EF.Functions.ILike(user.Email!, pattern) || EF.Functions.ILike(user.FullName, pattern));
        }

        var now = DateTimeOffset.UtcNow;
        switch (normalizedFilter)
        {
            case "active":
                usersQuery = usersQuery.Where(user => user.LockoutEnd == null || user.LockoutEnd <= now);
                break;
            case "locked":
                usersQuery = usersQuery.Where(user => user.LockoutEnd > now);
                break;
            case "admin":
                var adminRoleId = await db.Roles.Where(role => role.Name == "Admin").Select(role => role.Id).SingleOrDefaultAsync();
                usersQuery = usersQuery.Where(user => db.UserRoles.Any(userRole => userRole.UserId == user.Id && userRole.RoleId == adminRoleId));
                break;
        }

        var totalCount = await usersQuery.CountAsync();
        var users = await usersQuery.OrderBy(user => user.Email).Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();
        var items = new List<AdminUserResponse>(users.Count);
        foreach (var user in users)
            items.Add(ToUserResponse(user, (await userManager.GetRolesAsync(user)).ToList()));

        return Results.Ok(new AdminUserPage(items, page, pageSize, totalCount));
    }

    private static async Task<IResult> GetUserAsync(string userId, UserManager<ApplicationUser> userManager, ApplicationDbContext db)
    {
        var user = await userManager.FindByIdAsync(userId);
        if (user is null) return Results.NotFound();

        var devices = await db.Devices.Where(device => device.OwnerId == userId).OrderByDescending(device => device.CreatedAt)
            .Select(device => new AdminDeviceResponse(device.Id, device.Name, device.OwnerId, device.Owner == null ? null : device.Owner.Email, device.IsOnline, device.IsPumpOn, device.LastSeenAt, device.CreatedAt))
            .ToListAsync();
        return Results.Ok(new AdminUserDetailResponse(ToUserResponse(user, (await userManager.GetRolesAsync(user)).ToList()), devices));
    }

    private static async Task<IResult> UpdateRoleAsync(
        string userId,
        UpdateUserRoleRequest request,
        ClaimsPrincipal principal,
        UserManager<ApplicationUser> userManager,
        ApplicationDbContext db)
    {
        var actorUserId = GetUserId(principal);
        if (actorUserId is null) return Results.Unauthorized();

        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var target = await userManager.FindByIdAsync(userId);
        if (target is null) return Results.NotFound();

        var roles = await userManager.GetRolesAsync(target);
        var targetIsAdmin = roles.Contains("Admin");
        var adminCount = targetIsAdmin ? (await userManager.GetUsersInRoleAsync("Admin")).Count : 0;
        var error = AdminRoleRules.Validate(actorUserId, userId, request.Role, targetIsAdmin, adminCount);
        if (error is not null) return Results.BadRequest(new { error });

        if (roles.Count == 1 && roles[0] == request.Role)
            return Results.Ok(new AdminUserResponse(target.Id, target.Email ?? string.Empty, target.FullName, roles.ToList(), target.LockoutEnd > DateTimeOffset.UtcNow));

        var removeResult = await userManager.RemoveFromRolesAsync(target, roles.Where(role => role is "User" or "Admin"));
        if (!removeResult.Succeeded) return Results.ValidationProblem(removeResult.Errors.ToDictionary(error => error.Code, error => new[] { error.Description }));

        var addResult = await userManager.AddToRoleAsync(target, request.Role!);
        if (!addResult.Succeeded) return Results.ValidationProblem(addResult.Errors.ToDictionary(error => error.Code, error => new[] { error.Description }));

        db.AdminAuditLogs.Add(new AdminAuditLog
        {
            ActorUserId = actorUserId,
            Action = "role.updated",
            TargetType = "user",
            TargetId = target.Id,
            PreviousValue = string.Join(',', roles.Where(role => role is "User" or "Admin")),
            NewValue = request.Role,
        });
        await db.SaveChangesAsync();
        await transaction.CommitAsync();

        return Results.Ok(new AdminUserResponse(target.Id, target.Email ?? string.Empty, target.FullName, [request.Role!], target.LockoutEnd > DateTimeOffset.UtcNow));
    }

    private static async Task<IResult> UpdateLockAsync(
        string userId,
        UpdateUserLockRequest request,
        ClaimsPrincipal principal,
        UserManager<ApplicationUser> userManager,
        ApplicationDbContext db)
    {
        var actorUserId = GetUserId(principal);
        if (actorUserId is null) return Results.Unauthorized();

        var target = await userManager.FindByIdAsync(userId);
        if (target is null) return Results.NotFound();

        var roles = await userManager.GetRolesAsync(target);
        var targetIsAdmin = roles.Contains("Admin");
        var adminCount = targetIsAdmin ? (await userManager.GetUsersInRoleAsync("Admin")).Count : 0;
        var error = AdminRoleRules.ValidateLock(actorUserId, userId, request.IsLocked, targetIsAdmin, adminCount);
        if (error is not null) return Results.BadRequest(new { error });

        var wasLocked = target.LockoutEnd > DateTimeOffset.UtcNow;
        if (wasLocked == request.IsLocked)
            return Results.Ok(new AdminUserResponse(target.Id, target.Email ?? string.Empty, target.FullName, roles.ToList(), wasLocked));

        target.LockoutEnabled = true;
        target.LockoutEnd = request.IsLocked ? DateTimeOffset.MaxValue : null;
        var result = await userManager.UpdateAsync(target);
        if (!result.Succeeded) return Results.ValidationProblem(result.Errors.ToDictionary(error => error.Code, error => new[] { error.Description }));

        db.AdminAuditLogs.Add(new AdminAuditLog
        {
            ActorUserId = actorUserId,
            Action = "user.lock.updated",
            TargetType = "user",
            TargetId = target.Id,
            PreviousValue = wasLocked.ToString(),
            NewValue = request.IsLocked.ToString(),
        });
        await db.SaveChangesAsync();

        return Results.Ok(new AdminUserResponse(target.Id, target.Email ?? string.Empty, target.FullName, roles.ToList(), request.IsLocked));
    }

    private static async Task<IResult> ListDevicesAsync(
        ApplicationDbContext db,
        string? search = null,
        string? status = null,
        int page = 1,
        int pageSize = 50)
    {
        if (!HasValidPagination(page, pageSize)) return Results.BadRequest(new { error = "page must be positive and pageSize must be between 1 and 100." });
        var normalizedStatus = string.IsNullOrWhiteSpace(status) ? null : status.Trim().ToLowerInvariant();
        if (normalizedStatus is not null and not "online" and not "offline" and not "pumping")
            return Results.BadRequest(new { error = "status must be online, offline, or pumping." });

        var devices = db.Devices.AsQueryable();
        if (!string.IsNullOrWhiteSpace(search))
        {
            var pattern = $"%{search.Trim()}%";
            devices = devices.Where(device =>
                EF.Functions.ILike(device.Name, pattern) ||
                (device.Owner != null && EF.Functions.ILike(device.Owner.Email!, pattern)));
        }
        devices = normalizedStatus switch
        {
            "online" => devices.Where(device => device.IsOnline),
            "offline" => devices.Where(device => !device.IsOnline),
            "pumping" => devices.Where(device => device.IsPumpOn),
            _ => devices,
        };

        var totalCount = await devices.CountAsync();
        var items = await devices.OrderByDescending(device => device.CreatedAt).Skip((page - 1) * pageSize).Take(pageSize)
            .Select(device => new AdminDeviceResponse(device.Id, device.Name, device.OwnerId, device.Owner == null ? null : device.Owner.Email, device.IsOnline, device.IsPumpOn, device.LastSeenAt, device.CreatedAt))
            .ToListAsync();
        return Results.Ok(new AdminDevicePage(items, page, pageSize, totalCount));
    }

    private static async Task<IResult> GetDeviceAsync(Guid id, ApplicationDbContext db)
    {
        var device = await db.Devices.Where(candidate => candidate.Id == id)
            .Select(candidate => new AdminDeviceResponse(candidate.Id, candidate.Name, candidate.OwnerId, candidate.Owner == null ? null : candidate.Owner.Email, candidate.IsOnline, candidate.IsPumpOn, candidate.LastSeenAt, candidate.CreatedAt))
            .FirstOrDefaultAsync();
        if (device is null) return Results.NotFound();

        var latestReading = await db.SensorReadings.Where(reading => reading.DeviceId == id).OrderByDescending(reading => reading.RecordedAt)
            .Select(reading => new SensorReadingResponse(reading.Id, reading.Temperature, reading.SolutionTemperature, reading.Humidity, reading.Ph, reading.Tds, reading.WaterLevel, reading.Lux, reading.RecordedAt))
            .FirstOrDefaultAsync();
        var pumpCommands = await db.PumpCommands.Where(command => command.DeviceId == id)
            .OrderByDescending(command => command.IssuedAt).ThenByDescending(command => command.Id).Take(20)
            .Select(command => new PumpCommandHistoryResponse(command.Id, command.IsOn, command.DurationSeconds, command.Source, command.Status, command.IssuedAt, command.AcknowledgedAt, command.AcknowledgedIsOn, command.FailureReason))
            .ToListAsync();
        return Results.Ok(new AdminDeviceDetailResponse(device, latestReading, pumpCommands));
    }

    private static async Task<IResult> GetReadingsAsync(Guid id, ApplicationDbContext db, int take = 50)
    {
        if (!await db.Devices.AnyAsync(device => device.Id == id)) return Results.NotFound();

        var readings = await db.SensorReadings.Where(reading => reading.DeviceId == id).OrderByDescending(reading => reading.RecordedAt)
            .Take(Math.Clamp(take, 1, 500))
            .Select(reading => new SensorReadingResponse(reading.Id, reading.Temperature, reading.SolutionTemperature, reading.Humidity, reading.Ph, reading.Tds, reading.WaterLevel, reading.Lux, reading.RecordedAt))
            .ToListAsync();
        return Results.Ok(readings);
    }

    private static async Task<IResult> GetPumpHistoryAsync(Guid id, ApplicationDbContext db, int take = 20)
    {
        if (!await db.Devices.AnyAsync(device => device.Id == id)) return Results.NotFound();

        var commands = await db.PumpCommands.Where(command => command.DeviceId == id)
            .OrderByDescending(command => command.IssuedAt).ThenByDescending(command => command.Id)
            .Take(Math.Clamp(take, 1, 100))
            .Select(command => new PumpCommandHistoryResponse(
                command.Id, command.IsOn, command.DurationSeconds, command.Source, command.Status,
                command.IssuedAt, command.AcknowledgedAt, command.AcknowledgedIsOn, command.FailureReason))
            .ToListAsync();
        return Results.Ok(commands);
    }

    private static async Task<IResult> UpdateDeviceOwnerAsync(
        Guid id,
        UpdateDeviceOwnerRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext db,
        UserManager<ApplicationUser> userManager)
    {
        var actorUserId = GetUserId(principal);
        if (actorUserId is null) return Results.Unauthorized();
        if (request.OwnerId is not null && string.IsNullOrWhiteSpace(request.OwnerId)) return Results.BadRequest(new { error = "ownerId must be a user ID or null." });

        var device = await db.Devices.FirstOrDefaultAsync(device => device.Id == id);
        if (device is null) return Results.NotFound();

        ApplicationUser? owner = null;
        if (request.OwnerId is not null)
        {
            owner = await userManager.FindByIdAsync(request.OwnerId);
            if (owner is null) return Results.NotFound();
        }

        if (device.OwnerId == request.OwnerId) return Results.Ok(ToDeviceResponse(device, owner));

        var previousOwnerId = device.OwnerId;
        device.OwnerId = request.OwnerId;
        db.AdminAuditLogs.Add(new AdminAuditLog
        {
            ActorUserId = actorUserId,
            Action = "device.owner.updated",
            TargetType = "device",
            TargetId = device.Id.ToString(),
            PreviousValue = previousOwnerId,
            NewValue = request.OwnerId,
        });
        await db.SaveChangesAsync();
        return Results.Ok(ToDeviceResponse(device, owner));
    }

    private static AdminDeviceResponse ToDeviceResponse(Device device, ApplicationUser? owner) =>
        new(device.Id, device.Name, device.OwnerId, owner?.Email, device.IsOnline, device.IsPumpOn, device.LastSeenAt, device.CreatedAt);

    private static AdminUserResponse ToUserResponse(ApplicationUser user, IReadOnlyList<string> roles) =>
        new(user.Id, user.Email ?? string.Empty, user.FullName, roles, user.LockoutEnd > DateTimeOffset.UtcNow);

    private static async Task<IResult> ListAuditLogsAsync(
        ApplicationDbContext db,
        string? action = null,
        string? targetType = null,
        string? actorUserId = null,
        int page = 1,
        int pageSize = 50)
    {
        if (!HasValidPagination(page, pageSize)) return Results.BadRequest(new { error = "page must be positive and pageSize must be between 1 and 100." });

        var logs = db.AdminAuditLogs.AsQueryable();
        if (!string.IsNullOrWhiteSpace(action))
            logs = logs.Where(log => EF.Functions.ILike(log.Action, $"%{action.Trim()}%"));
        if (!string.IsNullOrWhiteSpace(targetType))
            logs = logs.Where(log => log.TargetType == targetType.Trim());
        if (!string.IsNullOrWhiteSpace(actorUserId))
            logs = logs.Where(log => log.ActorUserId == actorUserId.Trim());

        var totalCount = await logs.CountAsync();
        var items = await logs.OrderByDescending(log => log.CreatedAt).ThenByDescending(log => log.Id)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .Select(log => new AdminAuditLogResponse(log.Id, log.ActorUserId, log.Action, log.TargetType, log.TargetId, log.PreviousValue, log.NewValue, log.CreatedAt))
            .ToListAsync();
        return Results.Ok(new AdminAuditLogPage(items, page, pageSize, totalCount));
    }

    private static async Task<IResult> GetOverviewAsync(ApplicationDbContext db)
    {
        var report = await GetReportSummaryAsync(db);
        return Results.Ok(new AdminOverviewResponse(
            report.Users.Total,
            report.Devices.Total,
            report.Devices.Online,
            report.Alerts.Unresolved,
            report.Tickets.Open));
    }

    private static async Task<AdminReportSummaryResponse> GetReportSummaryAsync(ApplicationDbContext db)
    {
        var monthStart = new DateTime(DateTime.UtcNow.Year, DateTime.UtcNow.Month, 1, 0, 0, 0, DateTimeKind.Utc);
        var now = DateTimeOffset.UtcNow;
        var users = await db.Users.CountAsync();
        var lockedUsers = await db.Users.CountAsync(user => user.LockoutEnd > now);
        var devices = await db.Devices.CountAsync();
        var onlineDevices = await db.Devices.CountAsync(device => device.IsOnline);
        var alerts = await db.DeviceAlerts.CountAsync();
        var unresolvedAlerts = await db.DeviceAlerts.CountAsync(alert => alert.ResolvedAt == null);
        var tickets = await db.SupportTickets.CountAsync();
        var openTickets = await db.SupportTickets.CountAsync(ticket => ticket.Status == "open");
        var inProgressTickets = await db.SupportTickets.CountAsync(ticket => ticket.Status == "in_progress");
        var closedTickets = await db.SupportTickets.CountAsync(ticket => ticket.Status == "closed");

        return new AdminReportSummaryResponse(
            new AdminUserReportSummary(users, users - lockedUsers, lockedUsers),
            new AdminDeviceReportSummary(devices, onlineDevices, devices - onlineDevices, await db.Devices.CountAsync(device => device.CreatedAt >= monthStart)),
            new AdminAlertReportSummary(alerts, unresolvedAlerts, alerts - unresolvedAlerts),
            new AdminTicketReportSummary(tickets, openTickets, inProgressTickets, closedTickets));
    }

    private static async Task<IResult> DownloadReportCsvAsync(ApplicationDbContext db)
    {
        var report = await GetReportSummaryAsync(db);
        var rows = new (string Metric, int Value)[]
        {
            ("users.total", report.Users.Total), ("users.active", report.Users.Active), ("users.locked", report.Users.Locked),
            ("devices.total", report.Devices.Total), ("devices.online", report.Devices.Online), ("devices.offline", report.Devices.Offline), ("devices.new_this_month", report.Devices.NewThisMonth),
            ("alerts.total", report.Alerts.Total), ("alerts.unresolved", report.Alerts.Unresolved), ("alerts.resolved", report.Alerts.Resolved),
            ("tickets.total", report.Tickets.Total), ("tickets.open", report.Tickets.Open), ("tickets.in_progress", report.Tickets.InProgress), ("tickets.closed", report.Tickets.Closed)
        };
        var csv = "Metric,Value\r\n" + string.Join("\r\n", rows.Select(row => $"{row.Metric},{row.Value}")) + "\r\n";
        return Results.File(new UTF8Encoding(encoderShouldEmitUTF8Identifier: true).GetBytes(csv), "text/csv; charset=utf-8", "admin-report.csv");
    }

    private static async Task<IResult> GetStatusAsync(
        ApplicationDbContext db,
        [FromServices] MqttIngestionService mqtt,
        CancellationToken cancellationToken)
    {
        var databaseConnected = false;
        try
        {
            databaseConnected = await db.Database.CanConnectAsync(cancellationToken);
        }
        catch (Exception)
        {
            // Status must report a failed dependency rather than repeat stale values.
        }

        DateTime? latestIngestionAt = null;
        int? totalDevices = null;
        int? onlineDevices = null;
        if (databaseConnected)
        {
            latestIngestionAt = await db.SensorReadings.OrderByDescending(reading => reading.RecordedAt)
                .Select(reading => (DateTime?)reading.RecordedAt).FirstOrDefaultAsync(cancellationToken);
            totalDevices = await db.Devices.CountAsync(cancellationToken);
            onlineDevices = await db.Devices.CountAsync(device => device.IsOnline, cancellationToken);
        }

        var mqttConnected = mqtt.IsConnected;
        return Results.Ok(new AdminSystemStatusResponse(
            databaseConnected && mqttConnected ? "healthy" : "degraded",
            "healthy",
            databaseConnected ? "healthy" : "degraded",
            mqttConnected ? "connected" : "disconnected",
            latestIngestionAt,
            totalDevices,
            onlineDevices));
    }

    private static async Task<IResult> GetAlertDefaultsAsync(ApplicationDbContext db)
    {
        var settings = await db.SystemAlertDefaults.SingleOrDefaultAsync();
        return Results.Ok(new SystemAlertDefaultsResponse(
            settings?.HighTemperatureC ?? SystemAlertDefaults.DefaultHighTemperatureC,
            settings?.LowWaterLevelPercent ?? SystemAlertDefaults.DefaultLowWaterLevelPercent));
    }

    private static async Task<IResult> UpdateAlertDefaultsAsync(
        UpdateSystemAlertDefaultsRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext db)
    {
        var actorUserId = GetUserId(principal);
        if (actorUserId is null) return Results.Unauthorized();
        if (!request.IsValid)
            return Results.BadRequest(new { error = "Thresholds must be finite and water level must be between 0 and 100." });

        var settings = await db.SystemAlertDefaults.SingleOrDefaultAsync();
        if (settings is null)
        {
            settings = new SystemAlertDefaults();
            db.SystemAlertDefaults.Add(settings);
        }

        var previous = $"{settings.HighTemperatureC},{settings.LowWaterLevelPercent}";
        settings.HighTemperatureC = request.HighTemperatureC;
        settings.LowWaterLevelPercent = request.LowWaterLevelPercent;
        settings.UpdatedAt = DateTime.UtcNow;
        db.AdminAuditLogs.Add(new AdminAuditLog
        {
            ActorUserId = actorUserId,
            Action = "settings.alert-defaults.updated",
            TargetType = "settings",
            TargetId = "alert-defaults",
            PreviousValue = previous,
            NewValue = $"{settings.HighTemperatureC},{settings.LowWaterLevelPercent}",
        });
        await db.SaveChangesAsync();
        return Results.Ok(new SystemAlertDefaultsResponse(settings.HighTemperatureC, settings.LowWaterLevelPercent));
    }
}
