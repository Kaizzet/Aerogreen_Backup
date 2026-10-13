import '../models/history_data.dart';
import '../models/sensor_reading.dart';
import 'api_service.dart';

abstract interface class HistoryRepository {
  Future<List<HistorySample>> loadSamples({
    required String deviceId,
    required HistoryWindow window,
    required bool downsample,
  });

  Future<List<PumpHistoryEvent>> loadPumpEvents({
    required String deviceId,
    required HistoryWindow window,
  });

  Future<Map<String, dynamic>> loadAlertSettings(String deviceId);
}

class ApiHistoryRepository implements HistoryRepository {
  ApiHistoryRepository([ApiService? apiService])
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  @override
  Future<List<HistorySample>> loadSamples({
    required String deviceId,
    required HistoryWindow window,
    required bool downsample,
  }) async {
    if (downsample) {
      final data = await _apiService.getAggregatedDeviceReadings(
        deviceId,
        from: window.from,
        to: window.to,
        interval: window.rangeHours > 24 * 7 ? 'day' : 'hour',
      );
      return data
          .map(
            (item) => HistorySample.fromAggregate(item as Map<String, dynamic>),
          )
          .where((sample) => sample.values.isNotEmpty)
          .toList()
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    }

    final data = await _apiService.getDeviceReadings(deviceId, limit: 500);
    return data
        .map(
          (item) => HistorySample.fromReading(
            SensorReading.fromJson(item as Map<String, dynamic>),
          ),
        )
        .where(
          (sample) =>
              !sample.recordedAt.isBefore(window.from) &&
              !sample.recordedAt.isAfter(window.to) &&
              sample.values.isNotEmpty,
        )
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  }

  @override
  Future<List<PumpHistoryEvent>> loadPumpEvents({
    required String deviceId,
    required HistoryWindow window,
  }) async {
    final data = await _apiService.getPumpCommands(
      deviceId,
      pageSize: 100,
      rangeHours: window.rangeHours,
    );
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .map((item) => PumpHistoryEvent.fromJson(item as Map<String, dynamic>))
        .where(
          (event) =>
              !event.at.isBefore(window.from) && !event.at.isAfter(window.to),
        )
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
  }

  @override
  Future<Map<String, dynamic>> loadAlertSettings(String deviceId) =>
      _apiService.getAlertSettings(deviceId);
}
