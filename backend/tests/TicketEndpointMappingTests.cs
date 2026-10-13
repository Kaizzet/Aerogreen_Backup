using IOTAgriBackend.Endpoints;
using IOTAgriBackend.Data;
using IOTAgriBackend.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using System.Linq;
using Xunit;

namespace IOTAgriBackend.Tests;

public class TicketEndpointMappingTests
{
    [Fact]
    public void Ticket_create_requires_login_and_admin_routes_require_admin_policy()
    {
        var builder = WebApplication.CreateBuilder();
        builder.Services.AddDbContext<ApplicationDbContext>(options => options.UseNpgsql("Host=localhost;Database=ticket_endpoint_test"));
        builder.Services.AddIdentityCore<ApplicationUser>().AddRoles<IdentityRole>().AddEntityFrameworkStores<ApplicationDbContext>();
        using var app = builder.Build();
        app.MapTicketEndpoints();
        var endpoints = ((IEndpointRouteBuilder)app).DataSources.SelectMany(source => source.Endpoints)
            .OfType<RouteEndpoint>().ToList();

        var create = Assert.Single(endpoints, endpoint => endpoint.RoutePattern.RawText?.StartsWith("/api/tickets") == true);
        Assert.Contains(create.Metadata.GetOrderedMetadata<IAuthorizeData>(), data => data.Policy is null);

        var admin = endpoints.Where(endpoint => endpoint.RoutePattern.RawText?.StartsWith("/api/admin/tickets") == true).ToList();
        Assert.Equal(5, admin.Count);
        Assert.All(admin, endpoint => Assert.Contains(endpoint.Metadata.GetOrderedMetadata<IAuthorizeData>(), data => data.Policy == "AdminOnly"));
    }
}
