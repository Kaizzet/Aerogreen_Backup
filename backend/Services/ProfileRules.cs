namespace IOTAgriBackend.Services;

public static class ProfileRules
{
    public const int MaximumFullNameLength = 100;
    public const int MaximumPhoneNumberLength = 32;

    public static string? Validate(
        string? fullName,
        string? phoneNumber,
        out string normalizedFullName,
        out string? normalizedPhoneNumber)
    {
        normalizedFullName = fullName?.Trim() ?? string.Empty;
        normalizedPhoneNumber = string.IsNullOrWhiteSpace(phoneNumber) ? null : phoneNumber.Trim();

        if (normalizedFullName.Length == 0) return "fullName is required.";
        if (normalizedFullName.Length > MaximumFullNameLength) return $"fullName must be at most {MaximumFullNameLength} characters.";

        if (normalizedPhoneNumber is not null)
        {
            if (normalizedPhoneNumber.Length > MaximumPhoneNumberLength) return $"phoneNumber must be at most {MaximumPhoneNumberLength} characters.";
            if (!IsPhoneNumber(normalizedPhoneNumber)) return "phoneNumber must contain at least 8 digits and only digits, spaces, or + - ( ) . characters.";
        }

        return null;
    }

    public static bool IsPhoneNumber(string value) =>
        value.Count(char.IsDigit) >= 8 &&
        value.All(character => char.IsDigit(character) || character is '+' or ' ' or '-' or '(' or ')' or '.');
}
