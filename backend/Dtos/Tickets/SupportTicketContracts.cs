namespace IOTAgriBackend.Dtos.Tickets;

public record CreateSupportTicketRequest(string? Subject, string? Message);
public record UpdateSupportTicketStatusRequest(string? Status);
public record UpdateSupportTicketPriorityRequest(string? Priority);
public record AddSupportTicketMessageRequest(string? Message);

public record SupportTicketResponse(
    Guid Id,
    string Subject,
    string Status,
    string Priority,
    string UserId,
    string UserName,
    string UserEmail,
    string? LastMessage,
    int MessageCount,
    DateTime CreatedAt,
    DateTime UpdatedAt);

public record SupportTicketPage(IReadOnlyList<SupportTicketResponse> Items, int Page, int PageSize, int TotalCount);

public record SupportTicketMessageResponse(Guid Id, string AuthorUserId, string AuthorName, bool IsAdmin, string Message, DateTime CreatedAt);

public record SupportTicketDetailResponse(SupportTicketResponse Ticket, IReadOnlyList<SupportTicketMessageResponse> Messages);
