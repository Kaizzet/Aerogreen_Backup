import 'device_alert.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = true,
    this.critical = true,
    this.warning = true,
    this.info = true,
    this.quietHoursEnabled = false,
    this.quietStartMinutes = 22 * 60,
    this.quietEndMinutes = 7 * 60,
  });

  final bool enabled;
  final bool critical;
  final bool warning;
  final bool info;
  final bool quietHoursEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;

  bool allows(AlertLevel level, DateTime now) {
    if (!enabled) return false;
    final severityEnabled = switch (level) {
      AlertLevel.critical => critical,
      AlertLevel.warning => warning,
      AlertLevel.info => info,
    };
    if (!severityEnabled) return false;
    if (!quietHoursEnabled || level == AlertLevel.critical) return true;

    final currentMinutes = now.hour * 60 + now.minute;
    final isQuiet = quietStartMinutes <= quietEndMinutes
        ? currentMinutes >= quietStartMinutes &&
              currentMinutes < quietEndMinutes
        : currentMinutes >= quietStartMinutes ||
              currentMinutes < quietEndMinutes;
    return !isQuiet;
  }

  NotificationPreferences copyWith({
    bool? enabled,
    bool? critical,
    bool? warning,
    bool? info,
    bool? quietHoursEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
  }) => NotificationPreferences(
    enabled: enabled ?? this.enabled,
    critical: critical ?? this.critical,
    warning: warning ?? this.warning,
    info: info ?? this.info,
    quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
    quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'critical': critical,
    'warning': warning,
    'info': info,
    'quietHoursEnabled': quietHoursEnabled,
    'quietStartMinutes': quietStartMinutes,
    'quietEndMinutes': quietEndMinutes,
  };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        enabled: json['enabled'] as bool? ?? true,
        critical: json['critical'] as bool? ?? true,
        warning: json['warning'] as bool? ?? true,
        info: json['info'] as bool? ?? true,
        quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? false,
        quietStartMinutes: json['quietStartMinutes'] as int? ?? 22 * 60,
        quietEndMinutes: json['quietEndMinutes'] as int? ?? 7 * 60,
      );
}
