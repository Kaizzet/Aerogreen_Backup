using IOTAgriBackend.Models;
using Microsoft.AspNetCore.Identity;

namespace IOTAgriBackend.Data;

public sealed class AdminBootstrapSettings
{
    public string? Email { get; init; }
    public string? Password { get; init; }
    public string? FullName { get; init; }

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(Email) && !string.IsNullOrWhiteSpace(Password);
}

public static class AdminBootstrapper
{
    public static async Task SeedAsync(IServiceProvider services, IConfiguration configuration)
    {
        var settings = configuration.GetSection("AdminBootstrap").Get<AdminBootstrapSettings>() ?? new();
        if (!settings.IsConfigured) return;

        using var scope = services.CreateScope();
        var users = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var user = await users.FindByEmailAsync(settings.Email!);
        if (user is null)
        {
            user = new ApplicationUser
            {
                UserName = settings.Email,
                Email = settings.Email,
                FullName = string.IsNullOrWhiteSpace(settings.FullName) ? "Administrator" : settings.FullName,
            };
            var result = await users.CreateAsync(user, settings.Password!);
            if (!result.Succeeded)
                throw new InvalidOperationException($"Admin bootstrap failed: {string.Join(' ', result.Errors.Select(error => error.Code))}");
        }

        if (!await users.IsInRoleAsync(user, "Admin"))
        {
            var result = await users.AddToRoleAsync(user, "Admin");
            if (!result.Succeeded)
                throw new InvalidOperationException(
                    $"Admin bootstrap role assignment failed: {string.Join(' ', result.Errors.Select(error => error.Code))}");
        }
    }
}
