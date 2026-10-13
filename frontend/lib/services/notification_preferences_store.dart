import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_preferences.dart';

class NotificationPreferencesStore {
  static const _key = 'notification_preferences_v1';

  Future<NotificationPreferences> load() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    if (value == null) return const NotificationPreferences();
    try {
      return NotificationPreferences.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
    } catch (_) {
      return const NotificationPreferences();
    }
  }

  Future<void> save(NotificationPreferences value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, jsonEncode(value.toJson()));
  }
}
