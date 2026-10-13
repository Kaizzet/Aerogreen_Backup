using IOTAgriBackend.Services;
using Xunit;

namespace IOTAgriBackend.Tests;

public class SupportTicketRulesTests
{
    [Theory]
    [InlineData("open", "in_progress", true)]
    [InlineData("in_progress", "closed", true)]
    [InlineData("closed", "open", true)]
    [InlineData("open", "closed", false)]
    [InlineData("closed", "in_progress", false)]
    public void Allows_only_safe_status_transitions(string current, string next, bool expected)
    {
        Assert.Equal(expected, SupportTicketRules.IsValidTransition(current, next));
    }

    [Theory]
    [InlineData("low")]
    [InlineData("medium")]
    [InlineData("high")]
    public void Accepts_known_priorities(string priority)
    {
        Assert.True(SupportTicketRules.IsValidPriority(priority));
    }
}
