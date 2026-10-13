// lib/data/mock_data.dart

import 'package:flutter/material.dart';
import 'models.dart';

/// Mock list of plants used for the demo.
final List<Plant> mockPlants = [
  Plant(
    id: '1',
    name: 'Xà lách',
    variety: 'Butterhead',
    durationWeeks: 4,
    difficulty: 'Dễ',
    pumpMinutes: 2,
    pumpEveryMinutes: 15,
    nutrientMl: 5,
    nutrientEveryDays: 3,
    tempMin: 18,
    tempMax: 22,
    illustration: '🥬',
    tintColor: const Color(0xFF8FAF94),
  ),
  Plant(
    id: '2',
    name: 'Húng quế',
    variety: 'Genovese',
    durationWeeks: 5,
    difficulty: 'Dễ',
    pumpMinutes: 3,
    pumpEveryMinutes: 20,
    nutrientMl: 7,
    nutrientEveryDays: 4,
    tempMin: 20,
    tempMax: 25,
    illustration: '🌿',
    tintColor: const Color(0xFF6FAF80),
  ),
  Plant(
    id: '3',
    name: 'Rau chân vịt',
    variety: 'Baby leaf',
    durationWeeks: 6,
    difficulty: 'Dễ',
    pumpMinutes: 2,
    pumpEveryMinutes: 12,
    nutrientMl: 6,
    nutrientEveryDays: 3,
    tempMin: 16,
    tempMax: 20,
    illustration: '🥗',
    tintColor: const Color(0xFFAFCF8E),
  ),
  Plant(
    id: '4',
    name: 'Bạc hà',
    variety: 'Spearmint',
    durationWeeks: 4,
    difficulty: 'Dễ',
    pumpMinutes: 4,
    pumpEveryMinutes: 25,
    nutrientMl: 5,
    nutrientEveryDays: 5,
    tempMin: 18,
    tempMax: 24,
    illustration: '🌱',
    tintColor: const Color(0xFF8FDFA0),
  ),
  Plant(
    id: '5',
    name: 'Cải xoăn',
    variety: 'Tuscan',
    durationWeeks: 7,
    difficulty: 'Trung bình',
    pumpMinutes: 3,
    pumpEveryMinutes: 18,
    nutrientMl: 8,
    nutrientEveryDays: 4,
    tempMin: 15,
    tempMax: 21,
    illustration: '🥦',
    tintColor: const Color(0xFF7FAF70),
  ),
  Plant(
    id: '6',
    name: 'Rau mùi',
    variety: 'Slow-bolt',
    durationWeeks: 5,
    difficulty: 'Trung bình',
    pumpMinutes: 3,
    pumpEveryMinutes: 20,
    nutrientMl: 6,
    nutrientEveryDays: 4,
    tempMin: 17,
    tempMax: 22,
    illustration: '🌾',
    tintColor: const Color(0xFF9FAF90),
  ),
];

// Default active plant (Xà lách) – day 14 of a 28‑day cycle.
final ActivePlant defaultActivePlant = ActivePlant(
  plant: mockPlants[0],
  startDate: DateTime.now().subtract(const Duration(days: 14)),
  currentDay: 14,
);

// Default sensor reading used as a starting point for the drift stream.
final SensorReading defaultSensorReading = const SensorReading(
  waterLevel: 68,
  nutrientLevel: 42,
  temperature: 23,
);
