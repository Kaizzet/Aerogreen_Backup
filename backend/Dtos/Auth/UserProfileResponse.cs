namespace IOTAgriBackend.Dtos.Auth;

public record UserProfileResponse(
    string Id,
    string Email,
    string FullName,
    string? PhoneNumber,
    IReadOnlyList<string> Roles
);
