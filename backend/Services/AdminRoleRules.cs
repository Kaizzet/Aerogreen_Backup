namespace IOTAgriBackend.Services;

public static class AdminRoleRules
{
    public static string? ValidateListFilter(string? filter, out string? normalized)
    {
        normalized = string.IsNullOrWhiteSpace(filter) ? null : filter.Trim().ToLowerInvariant();
        return normalized is null or "active" or "locked" or "admin" ? null : "Filter must be active, locked, or admin.";
    }

    public static string? Validate(string actorUserId, string targetUserId, string? role, bool targetIsAdmin, int adminCount)
    {
        if (role is not "User" and not "Admin") return "Role must be User or Admin.";
        if (actorUserId == targetUserId) return "Administrators cannot change their own role.";
        if (targetIsAdmin && role == "User" && adminCount <= 1) return "Cannot remove the last administrator.";
        return null;
    }

    public static string? ValidateLock(string actorUserId, string targetUserId, bool isLocked, bool targetIsAdmin, int adminCount)
    {
        if (actorUserId == targetUserId) return "Administrators cannot lock their own account.";
        if (isLocked && targetIsAdmin && adminCount <= 1) return "Cannot lock the last administrator.";
        return null;
    }
}
