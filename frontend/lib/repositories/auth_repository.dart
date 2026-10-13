import '../models/user.dart';

abstract class AuthRepository {
  Future<Map<String, dynamic>> login(String email, String password);
  Future<Map<String, dynamic>> register(String email, String password, String fullName);
  Future<void> logout();
  Future<User?> getProfile();
  Future<User> updateProfile({required String fullName, String? phoneNumber});
  Future<bool> changePassword(String currentPassword, String newPassword, {bool logoutOtherDevices = false});
}
