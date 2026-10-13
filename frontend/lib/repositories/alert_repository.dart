import '../models/device_alert.dart';

abstract class AlertRepository {
  Future<List<DeviceAlert>> getAlerts(
    String deviceId, {
    String status = 'all',
    int page = 1,
    int pageSize = 20,
  });
  Future<void> resolveAlert(String deviceId, String alertId);
  Future<Map<String, dynamic>> getAlertSettings(String deviceId);
  Future<Map<String, dynamic>> updateAlertSettings(
    String deviceId, {
    double? highTemperatureC,
    double? lowWaterLevelPercent,
  });
}
