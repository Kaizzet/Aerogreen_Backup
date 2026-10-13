using Microsoft.AspNetCore.Identity;
using IOTAgriBackend.Models;

namespace IOTAgriBackend.Data;

public static class RoleSeeder
{
    public static readonly string[] Roles = ["User", "Admin"];

    public static async Task SeedAsync(IServiceProvider services, IConfiguration configuration)
    {
        using var scope = services.CreateScope();
        var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();

        foreach (var role in Roles)
        {
            if (!await roleManager.RoleExistsAsync(role))
            {
                await roleManager.CreateAsync(new IdentityRole(role));
            }
        }

        var email = configuration["Admin:Email"];
        var password = configuration["Admin:Password"];
        var fullName = configuration["Admin:FullName"];
        if (string.IsNullOrWhiteSpace(email) &&
            string.IsNullOrWhiteSpace(password) &&
            string.IsNullOrWhiteSpace(fullName))
        {
            return;
        }

        if (string.IsNullOrWhiteSpace(email) ||
            string.IsNullOrWhiteSpace(password) ||
            string.IsNullOrWhiteSpace(fullName))
        {
            throw new InvalidOperationException(
                "Admin:Email, Admin:Password, and Admin:FullName must all be configured to seed an administrator.");
        }

        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var admin = await userManager.FindByEmailAsync(email);
        if (admin is null)
        {
            admin = new ApplicationUser
            {
                UserName = email,
                Email = email,
                FullName = fullName,
            };

            var createResult = await userManager.CreateAsync(admin, password);
            if (!createResult.Succeeded)
            {
                var errors = string.Join("; ", createResult.Errors.Select(error => error.Description));
                throw new InvalidOperationException($"Failed to create the configured administrator: {errors}");
            }
        }

        if (!await userManager.IsInRoleAsync(admin, "Admin"))
        {
            var addRoleResult = await userManager.AddToRoleAsync(admin, "Admin");
            if (!addRoleResult.Succeeded)
            {
                var errors = string.Join("; ", addRoleResult.Errors.Select(error => error.Description));
                throw new InvalidOperationException($"Failed to grant the configured administrator role: {errors}");
            }
        }
    }
}
