using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using IOTAgriBackend.Models;
using IOTAgriBackend.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using Xunit;

namespace IOTAgriBackend.Tests;

public class TokenServiceTests
{
    private const string TestKey = "unit-test-only-signing-key-32-characters-minimum";
    private static IConfiguration Configuration(int? minutes = null, string? key = TestKey) =>
        new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Jwt:Key"] = key, ["Jwt:Issuer"] = "unit-tests", ["Jwt:Audience"] = "unit-clients",
            ["Jwt:AccessTokenExpiryMinutes"] = minutes?.ToString(),
        }).Build();

    [Theory]
    [InlineData(null, 15)]
    [InlineData(30, 30)]
    public void Signs_claims_roles_and_configured_expiry(int? configured, int expected)
    {
        var service = new TokenService(Configuration(configured));
        var user = new ApplicationUser { Id = "fixture-user", Email = "fixture@example.invalid", FullName = "Fixture" };
        var earliestExpiry = DateTime.UtcNow.AddMinutes(expected).AddSeconds(-1);
        var encoded = service.CreateAccessToken(user, ["User", "Admin"]);
        var latestExpiry = DateTime.UtcNow.AddMinutes(expected).AddSeconds(1);
        var handler = new JwtSecurityTokenHandler();
        var token = handler.ReadJwtToken(encoded);
        // Production has no injectable clock. Bound the timestamp, allowing JWT second precision.
        Assert.InRange(token.ValidTo, earliestExpiry, latestExpiry);
        Assert.Equal("fixture-user", token.Subject);
        Assert.Equal("Fixture", token.Claims.Single(c => c.Type == "fullName").Value);
        Assert.Equal(2, token.Claims.Count(c => c.Type == ClaimTypes.Role));
        handler.ValidateToken(encoded, new TokenValidationParameters
        {
            ValidIssuer = "unit-tests", ValidAudience = "unit-clients", ValidateLifetime = false,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(TestKey)),
        }, out _);
        Assert.NotEqual(token.Id, handler.ReadJwtToken(service.CreateAccessToken(user, [])).Id);
    }

    [Fact]
    public void Missing_signing_key_fails_explicitly() =>
        Assert.Throws<InvalidOperationException>(() => new TokenService(Configuration(key: null)).CreateAccessToken(new ApplicationUser(), []));

    [Fact]
    public void Refresh_values_contain_64_random_bytes_and_are_distinct()
    {
        var service = new TokenService(Configuration());
        var values = Enumerable.Range(0, 20).Select(_ => service.GenerateRefreshTokenValue()).ToList();
        Assert.Equal(values.Count, values.Distinct().Count());
        Assert.All(values, value => Assert.Equal(64, Convert.FromBase64String(value).Length));
    }
}
