using IOTAgriBackend.Data;
using IOTAgriBackend.Endpoints;
using IOTAgriBackend.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using System.Linq;
using System.Threading.Tasks;
using Xunit;

namespace IOTAgriBackend.Tests;

public class AdminEndpointMappingTests
{
    [Fact]
    public async Task Every_admin_endpoint_requires_admin_policy()
    {
        var builder = WebApplication.CreateBuilder();
        builder.Services.AddDbContext<ApplicationDbContext>(options => options.UseNpgsql("Host=localhost;Database=admin_endpoint_test"));
        builder.Services.AddIdentityCore<ApplicationUser>().AddRoles<IdentityRole>().AddEntityFrameworkStores<ApplicationDbContext>();
        await using var app = builder.Build();
        app.MapAdminEndpoints();

        var endpoints = ((IEndpointRouteBuilder)app).DataSources.SelectMany(source => source.Endpoints)
            .OfType<RouteEndpoint>()
            .Where(endpoint => endpoint.RoutePattern.RawText?.StartsWith("/api/admin") == true)
            .ToList();

        Assert.Equal(16, endpoints.Count);
        Assert.Contains(endpoints, endpoint => endpoint.RoutePattern.RawText == "/api/admin/overview");
        Assert.Contains(endpoints, endpoint => endpoint.RoutePattern.RawText == "/api/admin/reports/summary");
        Assert.Contains(endpoints, endpoint => endpoint.RoutePattern.RawText == "/api/admin/reports.csv");
        Assert.Contains(endpoints, endpoint => endpoint.RoutePattern.RawText == "/api/admin/status");
        Assert.Contains(endpoints, endpoint => endpoint.RoutePattern.RawText == "/api/admin/settings/alert-defaults");
        Assert.All(endpoints, endpoint => Assert.Contains(endpoint.Metadata.GetOrderedMetadata<IAuthorizeData>(), data => data.Policy == "AdminOnly"));
    }
}
