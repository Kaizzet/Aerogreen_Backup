// lib/providers/data_providers.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';
import '../data/mock_data.dart';
import '../repositories/plant_repository.dart';

// Provides the currently selected active plant.
final currentPlantProvider = StateProvider<ActivePlant>((ref) => defaultActivePlant);

// Stream of sensor readings that fetch from the backend API every few seconds.
final sensorStreamProvider = StreamProvider<SensorReading>((ref) {
  final repo = ref.read(plantRepositoryProvider);
  // Emit the initial reading (fallback to mock default).
  return Stream.periodic(const Duration(seconds: 3)).asyncMap((_) async {
    try {
      return await repo.getLatestSensor();
    } catch (e) {
      // If the backend call fails, fall back to the mock default reading.
      return defaultSensorReading;
    }
  });
});

// List of alerts generated from the latest sensor reading.
final alertsProvider = Provider<List<AppAlert>>((ref) {
  final sensor = ref.watch(sensorStreamProvider).valueOrNull ?? defaultSensorReading;
  final List<AppAlert> alerts = [];
  if (sensor.waterLevel < 30) {
    alerts.add(const AppAlert(
      id: 'water_low',
      title: 'Nước thấp',
      message: 'Nước mức đang dưới 30% – cần nạp thêm nước.',
      actionLabel: 'Nạp nước',
      type: 'warning',
    ));
  }
  if (sensor.nutrientLevel < 45) {
    alerts.add(const AppAlert(
      id: 'nutrient_low',
      title: 'Dinh dưỡng thấp',
      message: 'Mức dinh dưỡng dưới 45% – cần bón thêm.',
      actionLabel: 'Bổ dinh dưỡng',
      type: 'warning',
    ));
  }
  return alerts;
});

// Control mode (smart or manual).
final controlModeProvider = StateProvider<String>((ref) => 'smart'); // could be an enum later

// Provider to track pump running state.
final pumpRunningProvider = StateProvider<bool>((ref) => false);

// Provider for nutrient spray duration (seconds).
final nutrientDurationProvider = StateProvider<double>((ref) => 30.0);
