import 'sensor_reading.dart';

enum HistorySensor {
  temperature('temperature', 'Nhiệt độ không khí', '°C'),
  solutionTemperature('solutionTemperature', 'Nhiệt độ dung dịch', '°C'),
  humidity('humidity', 'Độ ẩm', '%'),
  tds('tds', 'TDS', 'ppm'),
  ph('ph', 'pH', ''),
  waterLevel('waterLevel', 'Mực nước', '%');

  const HistorySensor(this.key, this.label, this.unit);

  final String key;
  final String label;
  final String unit;

  double? valueFromReading(SensorReading reading) => switch (this) {
    HistorySensor.temperature => reading.temperature,
    HistorySensor.solutionTemperature => reading.solutionTemperature,
    HistorySensor.humidity => reading.humidity,
    HistorySensor.tds => reading.tds,
    HistorySensor.ph => reading.ph,
    HistorySensor.waterLevel => reading.waterLevel,
  };

  double? valueFromAggregate(Map<String, dynamic> json) {
    final key = switch (this) {
      HistorySensor.temperature => 'avgTemperature',
      HistorySensor.solutionTemperature => 'avgSolutionTemperature',
      HistorySensor.humidity => 'avgHumidity',
      HistorySensor.tds => 'avgTds',
      HistorySensor.ph => 'avgPh',
      HistorySensor.waterLevel => 'avgWaterLevel',
    };
    return (json[key] as num?)?.toDouble();
  }
}

enum HistoryRange {
  day('24h', Duration(hours: 24)),
  week('7 ngày', Duration(days: 7)),
  month('30 ngày', Duration(days: 30)),
  custom('Tùy chọn', null);

  const HistoryRange(this.label, this.duration);

  final String label;
  final Duration? duration;

  bool get isDownsampled => this == week || this == month;
}

class HistoryWindow {
  const HistoryWindow({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  int get rangeHours => to.difference(from).inHours.clamp(1, 24 * 31).toInt();
}

class HistorySample {
  const HistorySample({required this.recordedAt, required this.values});

  final DateTime recordedAt;
  final Map<HistorySensor, double> values;

  factory HistorySample.fromReading(SensorReading reading) {
    final values = <HistorySensor, double>{};
    for (final sensor in HistorySensor.values) {
      final value = sensor.valueFromReading(reading);
      if (value != null) values[sensor] = value;
    }
    return HistorySample(
      recordedAt:
          DateTime.tryParse(reading.recordedAt)?.toLocal() ?? DateTime.now(),
      values: values,
    );
  }

  factory HistorySample.fromAggregate(Map<String, dynamic> json) {
    final values = <HistorySensor, double>{};
    for (final sensor in HistorySensor.values) {
      final value = sensor.valueFromAggregate(json);
      if (value != null) values[sensor] = value;
    }
    return HistorySample(
      recordedAt:
          DateTime.tryParse(json['bucketStart']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      values: values,
    );
  }
}

class PumpHistoryEvent {
  const PumpHistoryEvent({
    required this.at,
    required this.isOn,
    required this.status,
  });

  final DateTime at;
  final bool isOn;
  final String status;

  factory PumpHistoryEvent.fromJson(Map<String, dynamic> json) =>
      PumpHistoryEvent(
        at:
            DateTime.tryParse(json['issuedAt']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
        isOn: json['isOn'] == true,
        status: json['status']?.toString() ?? '',
      );
}

class HistoryStatistics {
  const HistoryStatistics({
    required this.minimum,
    required this.average,
    required this.maximum,
  });

  final double minimum;
  final double average;
  final double maximum;

  static HistoryStatistics? fromSamples(
    Iterable<HistorySample> samples,
    HistorySensor sensor,
  ) {
    final values = samples
        .map((sample) => sample.values[sensor])
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    return HistoryStatistics(
      minimum: values.reduce((a, b) => a < b ? a : b),
      average: values.reduce((a, b) => a + b) / values.length,
      maximum: values.reduce((a, b) => a > b ? a : b),
    );
  }
}
