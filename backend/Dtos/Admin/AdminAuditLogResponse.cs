namespace IOTAgriBackend.Dtos.Admin;

public record AdminAuditLogResponse(
    Guid Id,
    string ActorUserId,
    string Action,
    string TargetType,
    string TargetId,
    string? PreviousValue,
    string? NewValue,
    DateTime CreatedAt);

public record AdminAuditLogPage(IReadOnlyList<AdminAuditLogResponse> Items, int Page, int PageSize, int TotalCount);

public record AdminOverviewResponse(int Users, int Devices, int OnlineDevices, int UnresolvedAlerts, int OpenTickets);

public record AdminReportSummaryResponse(
    AdminUserReportSummary Users,
    AdminDeviceReportSummary Devices,
    AdminAlertReportSummary Alerts,
    AdminTicketReportSummary Tickets);

public record AdminUserReportSummary(int Total, int Active, int Locked);
public record AdminDeviceReportSummary(int Total, int Online, int Offline, int NewThisMonth);
public record AdminAlertReportSummary(int Total, int Unresolved, int Resolved);
public record AdminTicketReportSummary(int Total, int Open, int InProgress, int Closed);
