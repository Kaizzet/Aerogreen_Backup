import 'package:dio/dio.dart';

import '../../constants/api_constants.dart';
import '../../models/pump_command.dart';
import '../../models/pump_schedule.dart';
import '../dio_client.dart';
import '../pump_repository.dart';

class DioPumpRepositoryImpl implements PumpRepository {
  final DioClient client;

  DioPumpRepositoryImpl({DioClient? dioClient})
      : client = dioClient ?? DioClient();

  Dio get _dio => client.dio;

  @override
  Future<PumpCommand> sendPumpCommand(
    String deviceId,
    String commandId,
    bool isOn,
    int? durationSeconds,
  ) async {
    final response = await _dio.post(
      ApiConstants.pumpCommands(deviceId),
      data: {
        'commandId': commandId,
        'on': isOn,
        'durationSeconds': ?durationSeconds,
      },
    );
    return PumpCommand.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<PumpCommand>> getPumpCommands(
    String deviceId, {
    int page = 1,
    int pageSize = 20,
    int? rangeHours,
  }) async {
    final response = await _dio.get(
      ApiConstants.pumpCommands(deviceId),
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        'rangeHours': ?rangeHours,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((item) => PumpCommand.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<PumpSchedule>> getPumpSchedules(String deviceId) async {
    final response = await _dio.get(ApiConstants.pumpSchedules(deviceId));
    final list = response.data as List<dynamic>;
    return list.map((item) => PumpSchedule.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<PumpSchedule> createPumpSchedule(
    String deviceId, {
    required bool isEnabled,
    required int weekdayMask,
    required String startTime,
    required int durationSeconds,
    required String timeZone,
  }) async {
    final response = await _dio.post(
      ApiConstants.pumpSchedules(deviceId),
      data: {
        'isEnabled': isEnabled,
        'weekdayMask': weekdayMask,
        'startTime': startTime,
        'durationSeconds': durationSeconds,
        'timeZone': timeZone,
      },
    );
    return PumpSchedule.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PumpSchedule> updatePumpSchedule(
    String deviceId,
    String scheduleId, {
    required bool isEnabled,
    required int weekdayMask,
    required String startTime,
    required int durationSeconds,
    required String timeZone,
  }) async {
    final response = await _dio.put(
      ApiConstants.pumpSchedule(deviceId, scheduleId),
      data: {
        'isEnabled': isEnabled,
        'weekdayMask': weekdayMask,
        'startTime': startTime,
        'durationSeconds': durationSeconds,
        'timeZone': timeZone,
      },
    );
    return PumpSchedule.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deletePumpSchedule(String deviceId, String scheduleId) async {
    await _dio.delete(ApiConstants.pumpSchedule(deviceId, scheduleId));
  }
}
