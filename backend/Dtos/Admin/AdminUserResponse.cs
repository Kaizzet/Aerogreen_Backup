namespace IOTAgriBackend.Dtos.Admin;

public record AdminUserResponse(string Id, string Email, string FullName, IReadOnlyList<string> Roles, bool IsLocked);

public record AdminUserPage(IReadOnlyList<AdminUserResponse> Items, int Page, int PageSize, int TotalCount);

public record AdminUserDetailResponse(AdminUserResponse User, IReadOnlyList<AdminDeviceResponse> Devices);
