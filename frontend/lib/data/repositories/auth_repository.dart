// lib/data/repositories/auth_repository.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

/// A mock authentication repository. In a real app this would call an API or
/// MQTT/Firebase backend. Here we simply store a single user in
/// SharedPreferences.
class AuthRepository {
  static const _userKey = 'mock_user';

  /// Simulate network latency.
  Future<void> _delay() async => await Future.delayed(const Duration(seconds: 1));

  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_userKey);
    if (json == null) return null;
    return User.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toMap()));
  }

  Future<void> _clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  // Mock login – only accepts the fixed mock credentials.
  Future<User> login({required String email, required String password}) async {
    await _delay();
    // Fixed mock user data (as requested).
    if (email == 'mira@aerogreen.app' && password == 'password123') {
      final user = User(
        id: '1',
        fullName: 'Mira Patel',
        email: email,
        role: 'user',
        plan: 'Pro',
      );
      await _saveUser(user);
      return user;
    }
    // Any other credentials are considered invalid.
    throw Exception('Đăng nhập thất bại');
  }

  Future<User> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _delay();
    // In a mock we just accept any data and create a user.
    final user = User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fullName: fullName,
      email: email,
      role: 'user',
      plan: 'Free',
    );
    await _saveUser(user);
    return user;
  }

  Future<void> logout() async {
    await _delay();
    await _clear();
  }
}
