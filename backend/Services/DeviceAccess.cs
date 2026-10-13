using System.Linq.Expressions;
using IOTAgriBackend.Models;

namespace IOTAgriBackend.Services;

public static class DeviceAccess
{
    public static Expression<Func<Device, bool>> OwnedDevice(Guid deviceId, string userId) =>
        device => device.Id == deviceId && device.OwnerId == userId;
}
