using System.Security.Claims;
using IOTAgriBackend.Data;
using IOTAgriBackend.Dtos.Tickets;
using IOTAgriBackend.Models;
using IOTAgriBackend.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace IOTAgriBackend.Endpoints;

public static class TicketEndpoints
{
    public static IEndpointRouteBuilder MapTicketEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGroup("/api/tickets").WithTags("Tickets").RequireAuthorization()
            .MapPost("", CreateAsync);

        var admin = app.MapGroup("/api/admin/tickets").WithTags("Admin").RequireAuthorization("AdminOnly");
        admin.MapGet("", ListAsync);
        admin.MapGet("/{id:guid}", GetAsync);
        admin.MapPut("/{id:guid}/status", UpdateStatusAsync);
        admin.MapPut("/{id:guid}/priority", UpdatePriorityAsync);
        admin.MapPost("/{id:guid}/messages", ReplyAsync);
        return app;
    }

    private static string? GetUserId(ClaimsPrincipal principal) => principal.FindFirstValue(ClaimTypes.NameIdentifier);
    private static bool HasValidPagination(int page, int pageSize) => page > 0 && pageSize is >= 1 and <= 100;
    private static bool IsValidText(string? text, int maximum) => !string.IsNullOrWhiteSpace(text) && text.Trim().Length <= maximum;

    private static async Task<IResult> CreateAsync(
        CreateSupportTicketRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext db,
        UserManager<ApplicationUser> userManager)
    {
        var userId = GetUserId(principal);
        if (userId is null) return Results.Unauthorized();
        if (!IsValidText(request.Subject, 200) || !IsValidText(request.Message, 4000))
            return Results.BadRequest(new { error = "subject and message are required and must be at most 200 and 4000 characters." });

        var user = await userManager.FindByIdAsync(userId);
        if (user is null) return Results.Unauthorized();

        var ticket = new SupportTicket { UserId = userId, User = user, Subject = request.Subject!.Trim() };
        var message = new SupportTicketMessage { Ticket = ticket, AuthorUserId = userId, Author = user, Body = request.Message!.Trim() };
        ticket.Messages.Add(message);
        db.SupportTickets.Add(ticket);
        await db.SaveChangesAsync();
        return Results.Created($"/api/tickets/{ticket.Id}", ToDetail(ticket));
    }

    private static async Task<IResult> ListAsync(ApplicationDbContext db, string? status = null, string? search = null, int page = 1, int pageSize = 50)
    {
        if (!HasValidPagination(page, pageSize)) return Results.BadRequest(new { error = "page must be positive and pageSize must be between 1 and 100." });
        var normalizedStatus = string.IsNullOrWhiteSpace(status) ? null : status.Trim().ToLowerInvariant();
        if (normalizedStatus is not null && !SupportTicketRules.IsValidStatus(normalizedStatus))
            return Results.BadRequest(new { error = "status must be open, in_progress, or closed." });

        var tickets = db.SupportTickets.AsQueryable();
        if (normalizedStatus is not null) tickets = tickets.Where(ticket => ticket.Status == normalizedStatus);
        if (!string.IsNullOrWhiteSpace(search))
        {
            var pattern = $"%{search.Trim()}%";
            tickets = tickets.Where(ticket =>
                EF.Functions.ILike(ticket.Subject, pattern) ||
                EF.Functions.ILike(ticket.User!.FullName, pattern) ||
                EF.Functions.ILike(ticket.User!.Email!, pattern));
        }

        var totalCount = await tickets.CountAsync();
        var items = await tickets.OrderByDescending(ticket => ticket.UpdatedAt).ThenByDescending(ticket => ticket.Id)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .Select(ticket => new SupportTicketResponse(
                ticket.Id, ticket.Subject, ticket.Status, ticket.Priority, ticket.UserId,
                ticket.User!.FullName, ticket.User.Email!,
                ticket.Messages.OrderByDescending(message => message.CreatedAt).Select(message => message.Body).FirstOrDefault(),
                ticket.Messages.Count, ticket.CreatedAt, ticket.UpdatedAt))
            .ToListAsync();
        return Results.Ok(new SupportTicketPage(items, page, pageSize, totalCount));
    }

    private static async Task<IResult> GetAsync(Guid id, ApplicationDbContext db)
    {
        var ticket = await db.SupportTickets.Include(candidate => candidate.User)
            .Include(candidate => candidate.Messages).ThenInclude(message => message.Author)
            .FirstOrDefaultAsync(candidate => candidate.Id == id);
        return ticket is null ? Results.NotFound() : Results.Ok(ToDetail(ticket));
    }

    private static async Task<IResult> UpdateStatusAsync(
        Guid id,
        UpdateSupportTicketStatusRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext db)
    {
        var actorUserId = GetUserId(principal);
        if (actorUserId is null) return Results.Unauthorized();
        var status = request.Status?.Trim().ToLowerInvariant();
        if (!SupportTicketRules.IsValidStatus(status)) return Results.BadRequest(new { error = "status must be open, in_progress, or closed." });

        var ticket = await db.SupportTickets.Include(candidate => candidate.User)
            .Include(candidate => candidate.Messages).ThenInclude(message => message.Author)
            .FirstOrDefaultAsync(candidate => candidate.Id == id);
        if (ticket is null) return Results.NotFound();
        if (!SupportTicketRules.IsValidTransition(ticket.Status, status!)) return Results.BadRequest(new { error = "Invalid ticket status transition." });

        var previous = ticket.Status;
        ticket.Status = status!;
        ticket.UpdatedAt = DateTime.UtcNow;
        AddAudit(db, actorUserId, "ticket.status.updated", ticket.Id, previous, ticket.Status);
        await db.SaveChangesAsync();
        return Results.Ok(ToDetail(ticket));
    }

    private static async Task<IResult> UpdatePriorityAsync(
        Guid id,
        UpdateSupportTicketPriorityRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext db)
    {
        var actorUserId = GetUserId(principal);
        if (actorUserId is null) return Results.Unauthorized();
        var priority = request.Priority?.Trim().ToLowerInvariant();
        if (!SupportTicketRules.IsValidPriority(priority)) return Results.BadRequest(new { error = "priority must be low, medium, or high." });

        var ticket = await db.SupportTickets.Include(candidate => candidate.User)
            .Include(candidate => candidate.Messages).ThenInclude(message => message.Author)
            .FirstOrDefaultAsync(candidate => candidate.Id == id);
        if (ticket is null) return Results.NotFound();
        if (ticket.Priority == priority) return Results.Ok(ToDetail(ticket));

        var previous = ticket.Priority;
        ticket.Priority = priority!;
        ticket.UpdatedAt = DateTime.UtcNow;
        AddAudit(db, actorUserId, "ticket.priority.updated", ticket.Id, previous, ticket.Priority);
        await db.SaveChangesAsync();
        return Results.Ok(ToDetail(ticket));
    }

    private static async Task<IResult> ReplyAsync(
        Guid id,
        AddSupportTicketMessageRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext db,
        UserManager<ApplicationUser> userManager)
    {
        var actorUserId = GetUserId(principal);
        if (actorUserId is null) return Results.Unauthorized();
        if (!IsValidText(request.Message, 4000)) return Results.BadRequest(new { error = "message is required and must be at most 4000 characters." });

        var ticket = await db.SupportTickets.Include(candidate => candidate.User)
            .Include(candidate => candidate.Messages).ThenInclude(message => message.Author)
            .FirstOrDefaultAsync(candidate => candidate.Id == id);
        if (ticket is null) return Results.NotFound();
        var actor = await userManager.FindByIdAsync(actorUserId);
        if (actor is null) return Results.Unauthorized();

        ticket.Messages.Add(new SupportTicketMessage { AuthorUserId = actorUserId, Author = actor, Body = request.Message!.Trim() });
        ticket.UpdatedAt = DateTime.UtcNow;
        AddAudit(db, actorUserId, "ticket.message.added", ticket.Id, null, "admin reply");
        await db.SaveChangesAsync();
        return Results.Ok(ToDetail(ticket));
    }

    private static void AddAudit(ApplicationDbContext db, string actorUserId, string action, Guid ticketId, string? previous, string? next) =>
        db.AdminAuditLogs.Add(new AdminAuditLog { ActorUserId = actorUserId, Action = action, TargetType = "ticket", TargetId = ticketId.ToString(), PreviousValue = previous, NewValue = next });

    private static SupportTicketDetailResponse ToDetail(SupportTicket ticket)
    {
        var messages = ticket.Messages.OrderBy(message => message.CreatedAt).ThenBy(message => message.Id)
            .Select(message => new SupportTicketMessageResponse(message.Id, message.AuthorUserId, message.Author?.FullName ?? string.Empty, message.AuthorUserId != ticket.UserId, message.Body, message.CreatedAt))
            .ToList();
        var response = new SupportTicketResponse(ticket.Id, ticket.Subject, ticket.Status, ticket.Priority, ticket.UserId,
            ticket.User?.FullName ?? string.Empty, ticket.User?.Email ?? string.Empty,
            messages.LastOrDefault()?.Message, messages.Count, ticket.CreatedAt, ticket.UpdatedAt);
        return new SupportTicketDetailResponse(response, messages);
    }
}
