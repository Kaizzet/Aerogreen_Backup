namespace IOTAgriBackend.Dtos.Admin;

public record AdminSystemStatusResponse(
    string Status,
    string Api,
    string Database,
    string Mqtt,
    DateTime? LatestIngestionAt,
    int? TotalDevices,
    int? OnlineDevices);

public record SystemAlertDefaultsResponse(double HighTemperatureC, double LowWaterLevelPercent);

public record UpdateSystemAlertDefaultsRequest(double HighTemperatureC, double LowWaterLevelPercent)
{
    public bool IsValid =>
        double.IsFinite(HighTemperatureC) &&
        double.IsFinite(LowWaterLevelPercent) &&
        LowWaterLevelPercent is >= 0 and <= 100;
}
