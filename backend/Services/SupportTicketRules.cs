namespace IOTAgriBackend.Services;

public static class SupportTicketRules
{
    public static bool IsValidStatus(string? status) => status is "open" or "in_progress" or "closed";
    public static bool IsValidPriority(string? priority) => priority is "low" or "medium" or "high";
    public static bool IsValidTransition(string current, string next) =>
        (current, next) is ("open", "in_progress") or ("in_progress", "closed") or ("closed", "open");
}
