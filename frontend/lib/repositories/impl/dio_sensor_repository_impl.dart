import 'package:dio/dio.dart';

import '../../constants/api_constants.dart';
import '../../models/sensor_reading.dart';
import '../dio_client.dart';
import '../sensor_repository.dart';

class DioSensorRepositoryImpl implements SensorRepository {
  final DioClient client;

  DioSensorRepositoryImpl({DioClient? dioClient})
      : client = dioClient ?? DioClient();

  Dio get _dio => client.dio;

  @override
  Future<List<SensorReading>> getDeviceReadings(String deviceId, {int? limit}) async {
    final response = await _dio.get(
      ApiConstants.deviceReadings(deviceId),
      queryParameters: limit != null ? {'limit': limit} : null,
    );
    final list = response.data as List<dynamic>;
    return list.map((item) => SensorReading.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAggregatedReadings(
    String deviceId, {
    String range = '24h',
    String? interval,
  }) async {
    final response = await _dio.get(
      ApiConstants.deviceAggregatedReadings(deviceId),
      queryParameters: {
        'range': range,
        'interval': ?interval,
      },
    );
    final list = response.data as List<dynamic>;
    return list.map((item) => item as Map<String, dynamic>).toList();
  }
}
