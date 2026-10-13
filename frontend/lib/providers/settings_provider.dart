// lib/providers/settings_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings model persisted in SharedPreferences.
class AppSettings {
  final String temperatureUnit; // "°C" or "°F"
  final String volumeUnit; // "ml" or "oz"
  final String language; // "Tiếng Việt" or "English"
  final bool lowWaterAlert;
  final bool lowNutrientAlert;
  final bool temperatureAlert;
  final bool harvestReminder;

  const AppSettings({
    required this.temperatureUnit,
    required this.volumeUnit,
    required this.language,
    required this.lowWaterAlert,
    required this.lowNutrientAlert,
    required this.temperatureAlert,
    required this.harvestReminder,
  });

  AppSettings copyWith({
    String? temperatureUnit,
    String? volumeUnit,
    String? language,
    bool? lowWaterAlert,
    bool? lowNutrientAlert,
    bool? temperatureAlert,
    bool? harvestReminder,
  }) {
    return AppSettings(
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      volumeUnit: volumeUnit ?? this.volumeUnit,
      language: language ?? this.language,
      lowWaterAlert: lowWaterAlert ?? this.lowWaterAlert,
      lowNutrientAlert: lowNutrientAlert ?? this.lowNutrientAlert,
      temperatureAlert: temperatureAlert ?? this.temperatureAlert,
      harvestReminder: harvestReminder ?? this.harvestReminder,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(_default) {
    _loadFromPrefs();
  }

  static const _default = AppSettings(
    temperatureUnit: '°C',
    volumeUnit: 'ml',
    language: 'Tiếng Việt',
    lowWaterAlert: true,
    lowNutrientAlert: true,
    temperatureAlert: true,
    harvestReminder: true,
  );

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      temperatureUnit: prefs.getString('temperatureUnit') ?? state.temperatureUnit,
      volumeUnit: prefs.getString('volumeUnit') ?? state.volumeUnit,
      language: prefs.getString('language') ?? state.language,
      lowWaterAlert: prefs.getBool('lowWaterAlert') ?? state.lowWaterAlert,
      lowNutrientAlert: prefs.getBool('lowNutrientAlert') ?? state.lowNutrientAlert,
      temperatureAlert: prefs.getBool('temperatureAlert') ?? state.temperatureAlert,
      harvestReminder: prefs.getBool('harvestReminder') ?? state.harvestReminder,
    );
  }

  Future<void> _saveToPrefs(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('temperatureUnit', settings.temperatureUnit);
    await prefs.setString('volumeUnit', settings.volumeUnit);
    await prefs.setString('language', settings.language);
    await prefs.setBool('lowWaterAlert', settings.lowWaterAlert);
    await prefs.setBool('lowNutrientAlert', settings.lowNutrientAlert);
    await prefs.setBool('temperatureAlert', settings.temperatureAlert);
    await prefs.setBool('harvestReminder', settings.harvestReminder);
  }

  void update({
    String? temperatureUnit,
    String? volumeUnit,
    String? language,
    bool? lowWaterAlert,
    bool? lowNutrientAlert,
    bool? temperatureAlert,
    bool? harvestReminder,
  }) async {
    final newSettings = state.copyWith(
      temperatureUnit: temperatureUnit,
      volumeUnit: volumeUnit,
      language: language,
      lowWaterAlert: lowWaterAlert,
      lowNutrientAlert: lowNutrientAlert,
      temperatureAlert: temperatureAlert,
      harvestReminder: harvestReminder,
    );
    state = newSettings;
    await _saveToPrefs(newSettings);
  }
}

/// Provider exposing the settings notifier.
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());
