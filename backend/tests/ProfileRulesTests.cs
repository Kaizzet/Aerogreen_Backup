using IOTAgriBackend.Services;
using Xunit;

namespace IOTAgriBackend.Tests;

public class ProfileRulesTests
{
    [Fact]
    public void Accepts_name_with_optional_phone()
    {
        Assert.Null(ProfileRules.Validate("Nguyễn Văn A", null, out var name, out var phone));
        Assert.Equal("Nguyễn Văn A", name);
        Assert.Null(phone);

        Assert.Null(ProfileRules.Validate("  Nguyễn Văn A  ", " +84 912 345 678 ", out name, out phone));
        Assert.Equal("Nguyễn Văn A", name);
        Assert.Equal("+84 912 345 678", phone);
    }

    [Fact]
    public void Treats_blank_phone_as_removal()
    {
        Assert.Null(ProfileRules.Validate("Nguyễn Văn A", "   ", out _, out var phone));
        Assert.Null(phone);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Requires_full_name(string? fullName)
    {
        Assert.NotNull(ProfileRules.Validate(fullName, null, out _, out _));
    }

    [Fact]
    public void Rejects_overlong_name()
    {
        var name = new string('a', ProfileRules.MaximumFullNameLength + 1);
        Assert.NotNull(ProfileRules.Validate(name, null, out _, out _));
    }

    [Theory]
    [InlineData("12345")]
    [InlineData("not-a-phone")]
    [InlineData("0912-345-678; DROP")]
    public void Rejects_malformed_phone(string phone)
    {
        Assert.NotNull(ProfileRules.Validate("Nguyễn Văn A", phone, out _, out _));
    }

    [Theory]
    [InlineData("0912345678")]
    [InlineData("+84 912 345 678")]
    [InlineData("(028) 3822-1234")]
    public void Accepts_supported_phone_shapes(string phone)
    {
        Assert.Null(ProfileRules.Validate("Nguyễn Văn A", phone, out _, out _));
    }

    [Fact]
    public void Rejects_overlong_phone()
    {
        var phone = new string('1', ProfileRules.MaximumPhoneNumberLength + 1);
        Assert.NotNull(ProfileRules.Validate("Nguyễn Văn A", phone, out _, out _));
    }
}
