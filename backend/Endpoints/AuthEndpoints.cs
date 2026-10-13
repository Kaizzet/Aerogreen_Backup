using System.Security.Claims;
using IOTAgriBackend.Data;
using IOTAgriBackend.Dtos.Auth;
using IOTAgriBackend.Models;
using IOTAgriBackend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace IOTAgriBackend.Endpoints;

public static class AuthEndpoints
{
    public static IEndpointRouteBuilder MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/auth").WithTags("Auth");

        group.MapPost("/register", RegisterAsync);
        group.MapPost("/login", LoginAsync);
        group.MapPost("/refresh", RefreshAsync);
        group.MapPost("/logout", LogoutAsync).RequireAuthorization();
        group.MapGet("/profile", GetProfileAsync).RequireAuthorization();
        group.MapPut("/profile", UpdateProfileAsync).RequireAuthorization();

        return app;
    }

    private static async Task<IResult> RegisterAsync(
        RegisterRequest request,
        UserManager<ApplicationUser> userManager)
    {
        if (string.IsNullOrWhiteSpace(request.Email) ||
            string.IsNullOrWhiteSpace(request.Password) ||
            string.IsNullOrWhiteSpace(request.FullName))
        {
            return Results.ValidationProblem(new Dictionary<string, string[]>
            {
                ["request"] = ["Email, password, and full name are required."]
            });
        }

        var existing = await userManager.FindByEmailAsync(request.Email);
        if (existing is not null)
        {
            return Results.Conflict(new { message = "A user with this email already exists." });
        }

        var user = new ApplicationUser
        {
            UserName = request.Email,
            Email = request.Email,
            FullName = request.FullName,
        };

        var createResult = await userManager.CreateAsync(user, request.Password);
        if (!createResult.Succeeded)
        {
            var errors = createResult.Errors.ToDictionary(e => e.Code, e => new[] { e.Description });
            return Results.ValidationProblem(errors);
        }

        await userManager.AddToRoleAsync(user, "User");

        return Results.Created($"/api/users/{user.Id}", new UserSummaryResponse(user.Id, user.Email!, user.FullName));
    }

    private static async Task<IResult> LoginAsync(
        LoginRequest request,
        UserManager<ApplicationUser> userManager,
        ApplicationDbContext db,
        ITokenService tokenService,
        IConfiguration configuration)
    {
        var user = await userManager.FindByEmailAsync(request.Email);
        if (user is null || !await userManager.CheckPasswordAsync(user, request.Password))
        {
            return Results.Unauthorized();
        }

        var roles = await userManager.GetRolesAsync(user);
        var response = await IssueTokensAsync(user, roles, db, tokenService, configuration);
        return Results.Ok(response);
    }

    private static async Task<IResult> RefreshAsync(
        RefreshRequest request,
        UserManager<ApplicationUser> userManager,
        ApplicationDbContext db,
        ITokenService tokenService,
        IConfiguration configuration)
    {
        var existingToken = await db.RefreshTokens
            .Include(rt => rt.User)
            .FirstOrDefaultAsync(rt => rt.Token == request.RefreshToken);

        if (existingToken is null || !existingToken.IsActive || existingToken.User is null)
        {
            return Results.Unauthorized();
        }

        var roles = await userManager.GetRolesAsync(existingToken.User);
        var response = await IssueTokensAsync(existingToken.User, roles, db, tokenService, configuration, existingToken);
        return Results.Ok(response);
    }

    private static async Task<IResult> LogoutAsync(
        RefreshRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext db)
    {
        var userId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userId))
        {
            return Results.Unauthorized();
        }

        var token = await db.RefreshTokens
            .FirstOrDefaultAsync(rt => rt.Token == request.RefreshToken && rt.UserId == userId);

        if (token is null || !token.IsActive)
        {
            return Results.NoContent();
        }

        token.RevokedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();

        return Results.NoContent();
    }

    private static async Task<IResult> GetProfileAsync(
        ClaimsPrincipal principal,
        UserManager<ApplicationUser> userManager)
    {
        var user = await userManager.GetUserAsync(principal);
        if (user is null)
        {
            return Results.Unauthorized();
        }

        return Results.Ok(await ToProfileResponseAsync(user, userManager));
    }

    private static async Task<IResult> UpdateProfileAsync(
        UpdateProfileRequest request,
        ClaimsPrincipal principal,
        UserManager<ApplicationUser> userManager)
    {
        var user = await userManager.GetUserAsync(principal);
        if (user is null)
        {
            return Results.Unauthorized();
        }

        var error = ProfileRules.Validate(request.FullName, request.PhoneNumber, out var fullName, out var phoneNumber);
        if (error is not null)
        {
            return Results.BadRequest(new { error });
        }

        if (!string.Equals(user.PhoneNumber, phoneNumber, StringComparison.Ordinal))
        {
            user.PhoneNumberConfirmed = false;
        }

        user.FullName = fullName;
        user.PhoneNumber = phoneNumber;

        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            var errors = updateResult.Errors.ToDictionary(e => e.Code, e => new[] { e.Description });
            return Results.ValidationProblem(errors);
        }

        return Results.Ok(await ToProfileResponseAsync(user, userManager));
    }

    private static async Task<UserProfileResponse> ToProfileResponseAsync(
        ApplicationUser user,
        UserManager<ApplicationUser> userManager)
    {
        var roles = await userManager.GetRolesAsync(user);
        return new UserProfileResponse(
            user.Id,
            user.Email ?? string.Empty,
            user.FullName,
            user.PhoneNumber,
            roles.ToList());
    }

    private static async Task<AuthResponse> IssueTokensAsync(
        ApplicationUser user,
        IList<string> roles,
        ApplicationDbContext db,
        ITokenService tokenService,
        IConfiguration configuration,
        RefreshToken? tokenToRevoke = null)
    {
        var refreshExpiryDays = configuration.GetSection("Jwt").GetValue<int?>("RefreshTokenExpiryDays") ?? 7;
        var accessExpiryMinutes = configuration.GetSection("Jwt").GetValue<int?>("AccessTokenExpiryMinutes") ?? 15;

        var accessToken = tokenService.CreateAccessToken(user, roles);
        var refreshTokenValue = tokenService.GenerateRefreshTokenValue();

        var newRefreshToken = new RefreshToken
        {
            UserId = user.Id,
            Token = refreshTokenValue,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(refreshExpiryDays),
        };

        db.RefreshTokens.Add(newRefreshToken);

        if (tokenToRevoke is not null)
        {
            tokenToRevoke.RevokedAt = DateTime.UtcNow;
            tokenToRevoke.ReplacedByToken = refreshTokenValue;
        }

        await db.SaveChangesAsync();

        return new AuthResponse(accessToken, refreshTokenValue, DateTime.UtcNow.AddMinutes(accessExpiryMinutes));
    }
}
