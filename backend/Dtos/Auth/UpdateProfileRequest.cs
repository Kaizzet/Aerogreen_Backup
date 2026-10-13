namespace IOTAgriBackend.Dtos.Auth;

public record UpdateProfileRequest(
    string? FullName,
    string? PhoneNumber
);
