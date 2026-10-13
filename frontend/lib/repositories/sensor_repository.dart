import '../models/sensor_reading.dart';

abstract class SensorRepository {
  Future<List<SensorReading>> getDeviceReadings(String deviceId, {int? limit});
  Future<List<Map<String, dynamic>>> getAggregatedReadings(
    String deviceId, {
    String range = '24h',
    String? interval,
  });
}
