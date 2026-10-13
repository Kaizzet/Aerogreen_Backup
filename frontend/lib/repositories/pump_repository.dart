import '../models/pump_command.dart';
import '../models/pump_schedule.dart';

abstract class PumpRepository {
  Future<PumpCommand> sendPumpCommand(
    String deviceId,
    String commandId,
    bool isOn,
    int? durationSeconds,
  );
  Future<List<PumpCommand>> getPumpCommands(
    String deviceId, {
    int page = 1,
    int pageSize = 20,
    int? rangeHours,
  });
  Future<List<PumpSchedule>> getPumpSchedules(String deviceId);
  Future<PumpSchedule> createPumpSchedule(
    String deviceId, {
    required bool isEnabled,
    required int weekdayMask,
    required String startTime,
    required int durationSeconds,
    required String timeZone,
  });
  Future<PumpSchedule> updatePumpSchedule(
    String deviceId,
    String scheduleId, {
    required bool isEnabled,
    required int weekdayMask,
    required String startTime,
    required int durationSeconds,
    required String timeZone,
  });
  Future<void> deletePumpSchedule(String deviceId, String scheduleId);
}
