import 'package:dio/dio.dart';

import '../../constants/api_constants.dart';
import '../../models/device_alert.dart';
import '../alert_repository.dart';
import '../dio_client.dart';

class DioAlertRepositoryImpl implements AlertRepository {
  final DioClient client;

  DioAlertRepositoryImpl({DioClient? dioClient})
      : client = dioClient ?? DioClient();

  Dio get _dio => client.dio;

  @override
  Future<List<DeviceAlert>> getAlerts(
    String deviceId, {
    String status = 'all',
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get(
      ApiConstants.alerts(deviceId),
      queryParameters: {
        'status': status,
        'page': page,
        'pageSize': pageSize,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((item) => DeviceAlert.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> resolveAlert(String deviceId, String alertId) async {
    await _dio.put(ApiConstants.resolveAlert(deviceId, alertId));
  }

  @override
  Future<Map<String, dynamic>> getAlertSettings(String deviceId) async {
    final response = await _dio.get(ApiConstants.alertSettings(deviceId));
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> updateAlertSettings(
    String deviceId, {
    double? highTemperatureC,
    double? lowWaterLevelPercent,
  }) async {
    final response = await _dio.put(
      ApiConstants.alertSettings(deviceId),
      data: {
        'highTemperatureC': ?highTemperatureC,
        'lowWaterLevelPercent': ?lowWaterLevelPercent,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
