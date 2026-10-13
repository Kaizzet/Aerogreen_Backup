import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TemperatureUnit { celsius, fahrenheit }

enum AppThemeMode { system, light, dark }

class AppSettingsProvider extends ChangeNotifier {
  static const String _keyLocale = 'app_locale';
  static const String _keyTempUnit = 'app_temp_unit';
  static const String _keyThemeMode = 'app_theme_mode';

  Locale _locale = const Locale('vi');
  TemperatureUnit _temperatureUnit = TemperatureUnit.celsius;
  AppThemeMode _themeMode = AppThemeMode.system;
  bool _isLoaded = false;

  Locale get locale => _locale;
  TemperatureUnit get temperatureUnit => _temperatureUnit;
  AppThemeMode get themeMode => _themeMode;
  bool get isLoaded => _isLoaded;

  bool get isVietnamese => _locale.languageCode == 'vi';
  bool get isCelsius => _temperatureUnit == TemperatureUnit.celsius;

  AppSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString(_keyLocale);
      if (lang != null && (lang == 'vi' || lang == 'en')) {
        _locale = Locale(lang);
      }

      final tempUnit = prefs.getString(_keyTempUnit);
      if (tempUnit == 'fahrenheit') {
        _temperatureUnit = TemperatureUnit.fahrenheit;
      } else {
        _temperatureUnit = TemperatureUnit.celsius;
      }

      final theme = prefs.getString(_keyThemeMode);
      if (theme == 'light') {
        _themeMode = AppThemeMode.light;
      } else if (theme == 'dark') {
        _themeMode = AppThemeMode.dark;
      } else {
        _themeMode = AppThemeMode.system;
      }
    } catch (_) {
      // Use defaults if SharedPreferences fails
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    if (_locale == newLocale) return;
    _locale = newLocale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLocale, newLocale.languageCode);
    } catch (_) {}
  }

  Future<void> setTemperatureUnit(TemperatureUnit unit) async {
    if (_temperatureUnit == unit) return;
    _temperatureUnit = unit;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyTempUnit, unit.name);
    } catch (_) {}
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyThemeMode, mode.name);
    } catch (_) {}
  }

  double formatTemperature(double celsius) {
    if (_temperatureUnit == TemperatureUnit.fahrenheit) {
      return (celsius * 9 / 5) + 32;
    }
    return celsius;
  }

  String temperatureUnitString() {
    return _temperatureUnit == TemperatureUnit.celsius ? '°C' : '°F';
  }
}
