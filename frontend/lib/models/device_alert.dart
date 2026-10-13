class DeviceAlert {
  final String id;
  final String deviceId;
  final String type;
  final double measuredValue;
  final double threshold;
  final String triggeredAt;
  final String? resolvedAt;

  DeviceAlert({
    required this.id,
    required this.deviceId,
    required this.type,
    required this.measuredValue,
    required this.threshold,
    required this.triggeredAt,
    this.resolvedAt,
  });

  factory DeviceAlert.fromJson(Map<String, dynamic> json, {String? deviceId}) {
    return DeviceAlert(
      id: json['id'] ?? '',
      deviceId: json['deviceId'] ?? deviceId ?? '',
      type: json['type'] ?? '',
      measuredValue: (json['measuredValue'] ?? 0).toDouble(),
      threshold: (json['threshold'] ?? 0).toDouble(),
      triggeredAt: json['triggeredAt'] ?? '',
      resolvedAt: json['resolvedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'type': type,
      'measuredValue': measuredValue,
      'threshold': threshold,
      'triggeredAt': triggeredAt,
      'resolvedAt': resolvedAt,
    };
  }

  DeviceAlert copyWith({String? deviceId}) => DeviceAlert(
    id: id,
    deviceId: deviceId ?? this.deviceId,
    type: type,
    measuredValue: measuredValue,
    threshold: threshold,
    triggeredAt: triggeredAt,
    resolvedAt: resolvedAt,
  );

  AlertLevel get severity {
    final normalized = type.toUpperCase();
    if (normalized.contains('EMPTY') ||
        normalized.contains('PUMP_FAULT') ||
        normalized.contains('OFFLINE') ||
        normalized.contains('TEMPERATURE')) {
      return AlertLevel.critical;
    }
    if (normalized.contains('LOW_WATER') ||
        normalized.contains('HUMIDITY') ||
        normalized.contains('PH') ||
        normalized.contains('EC')) {
      return AlertLevel.warning;
    }
    return AlertLevel.info;
  }

  String? get sensorKey {
    final normalized = type.toUpperCase();
    if (normalized.contains('TEMPERATURE')) return 'temperature';
    if (normalized.contains('HUMIDITY')) return 'humidity';
    if (normalized.contains('WATER')) return 'waterLevel';
    if (normalized.contains('PH')) return 'ph';
    return null;
  }

  String get title {
    final normalized = type.toUpperCase();
    if (normalized.contains('HIGH_TEMPERATURE')) return 'Nhiệt độ cao';
    if (normalized.contains('LOW_TEMPERATURE')) return 'Nhiệt độ thấp';
    if (normalized.contains('LOW_WATER')) return 'Mực nước thấp';
    if (normalized.contains('HUMIDITY')) return 'Độ ẩm ngoài ngưỡng';
    if (normalized.contains('PUMP_FAULT')) return 'Lỗi bơm';
    if (normalized.contains('OFFLINE')) return 'Thiết bị mất kết nối';
    if (normalized.contains('BACK_ONLINE')) return 'Thiết bị đã trực tuyến';
    return type.replaceAll('_', ' ');
  }

  String get message {
    if (type.toUpperCase().contains('HIGH_TEMPERATURE')) {
      return 'Nhiệt độ ${measuredValue.toStringAsFixed(1)}°C vượt ngưỡng ${threshold.toStringAsFixed(1)}°C.';
    }
    if (type.toUpperCase().contains('LOW_WATER')) {
      return 'Mực nước ${measuredValue.toStringAsFixed(0)}% thấp hơn ngưỡng ${threshold.toStringAsFixed(0)}%.';
    }
    return 'Giá trị ${measuredValue.toStringAsFixed(1)} · Ngưỡng ${threshold.toStringAsFixed(1)}.';
  }
}

enum AlertLevel { critical, warning, info }
