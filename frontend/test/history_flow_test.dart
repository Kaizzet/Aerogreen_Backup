import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iotagri_app/models/history_data.dart';
import 'package:iotagri_app/models/sensor_reading.dart';
import 'package:iotagri_app/services/history_export_service.dart';

void main() {
  final samples = [
    HistorySample(
      recordedAt: DateTime.utc(2026, 10, 8, 8),
      values: const {HistorySensor.temperature: 24, HistorySensor.humidity: 70},
    ),
    HistorySample(
      recordedAt: DateTime.utc(2026, 10, 8, 9),
      values: const {HistorySensor.temperature: 30, HistorySensor.humidity: 60},
    ),
  ];

  test('calculates min average and max for the selected sensor', () {
    final stats = HistoryStatistics.fromSamples(
      samples,
      HistorySensor.temperature,
    );

    expect(stats?.minimum, 24);
    expect(stats?.average, 27);
    expect(stats?.maximum, 30);
  });

  test('maps solution temperature and TDS into history samples', () {
    final sample = HistorySample.fromReading(
      SensorReading(
        id: 'reading-1',
        deviceId: 'device-1',
        solutionTemperature: 26.7,
        tds: 520,
        recordedAt: '2026-10-08T08:00:00Z',
      ),
    );

    expect(sample.values[HistorySensor.solutionTemperature], 26.7);
    expect(sample.values[HistorySensor.tds], 520);
  });

  test('generates a real CSV export with readings and pump events', () async {
    final file = await const HistoryExportService().generate(
      format: HistoryExportFormat.csv,
      deviceName: 'Tháp 1',
      window: HistoryWindow(
        from: DateTime.utc(2026, 10, 8),
        to: DateTime.utc(2026, 10, 9),
      ),
      sensors: const {HistorySensor.temperature, HistorySensor.humidity},
      samples: samples,
      pumpEvents: [
        PumpHistoryEvent(
          at: DateTime.utc(2026, 10, 8, 8, 30),
          isOn: true,
          status: 'Acknowledged',
        ),
      ],
    );

    final csv = utf8.decode(file.bytes.sublist(3));
    expect(file.mimeType, 'text/csv');
    expect(csv, contains('temperature'));
    expect(csv, contains('pump_event_at'));
    expect(csv, contains('Acknowledged'));
  });

  test('generates a PDF document', () async {
    final file = await const HistoryExportService().generate(
      format: HistoryExportFormat.pdf,
      deviceName: 'Tower 1',
      window: HistoryWindow(
        from: DateTime.utc(2026, 10, 8),
        to: DateTime.utc(2026, 10, 9),
      ),
      sensors: const {HistorySensor.temperature},
      samples: samples,
      pumpEvents: const [],
    );

    expect(file.mimeType, 'application/pdf');
    expect(ascii.decode(file.bytes.take(4).toList()), '%PDF');
  });
}
