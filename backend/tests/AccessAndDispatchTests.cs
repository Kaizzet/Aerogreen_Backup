using System.Reflection;
using System.Security.Claims;
using IOTAgriBackend.Dtos.Pumps;
using IOTAgriBackend.Endpoints;
using Microsoft.AspNetCore.Http;
using Xunit;

namespace IOTAgriBackend.Tests;

public class AccessAndDispatchTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Pump_handler_rejects_missing_user_id_before_touching_data_or_broker(bool authenticated)
    {
        var identity = authenticated ? new ClaimsIdentity([], "fixture") : new ClaimsIdentity();
        var principal = new ClaimsPrincipal(identity);
        var method = typeof(DeviceEndpoints).GetMethod("SendPumpCommandAsync", BindingFlags.NonPublic | BindingFlags.Static)!;
        // All dependencies are null deliberately: unauthorized requests must return before using them.
        var task = (Task<IResult>)method.Invoke(null,
            [Guid.Empty, new PumpCommandRequest(Guid.NewGuid(), true, 60), principal, null, null, null, CancellationToken.None])!;
        var result = await task;
        Assert.Equal(StatusCodes.Status401Unauthorized, Assert.IsAssignableFrom<IStatusCodeHttpResult>(result).StatusCode);
    }
    // Authenticated ownership queries and dispatch persistence require integration tests.
}
