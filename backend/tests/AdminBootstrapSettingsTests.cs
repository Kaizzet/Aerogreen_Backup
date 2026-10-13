using IOTAgriBackend.Data;
using Xunit;

namespace IOTAgriBackend.Tests;

public class AdminBootstrapSettingsTests
{
    [Theory]
    [InlineData(null, null, false)]
    [InlineData("admin@example.com", null, false)]
    [InlineData(null, "Password123", false)]
    [InlineData("admin@example.com", "Password123", true)]
    public void IsConfigured_requires_email_and_password(string? email, string? password, bool expected)
    {
        var settings = new AdminBootstrapSettings { Email = email, Password = password };

        Assert.Equal(expected, settings.IsConfigured);
    }
}
