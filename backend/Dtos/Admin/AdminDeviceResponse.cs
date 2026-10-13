using IOTAgriBackend.Dtos.Pumps;
using IOTAgriBackend.Dtos.Sensors;

namespace IOTAgriBackend.Dtos.Admin;

public record AdminDeviceResponse(
    Guid Id,
    string Name,
    string? OwnerId,
    string? OwnerEmail,
    bool IsOnline,
    bool IsPumpOn,
    DateTime? LastSeenAt,
    DateTime CreatedAt);

public record AdminDevicePage(IReadOnlyList<AdminDeviceResponse> Items, int Page, int PageSize, int TotalCount);

public record AdminDeviceDetailResponse(
    AdminDeviceResponse Device,
    SensorReadingResponse? LatestReading,
    IReadOnlyList<PumpCommandHistoryResponse> PumpCommands);
