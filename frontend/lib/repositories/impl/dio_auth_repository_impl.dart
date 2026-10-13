import 'package:dio/dio.dart';

import '../../constants/api_constants.dart';
import '../../models/user.dart';
import '../auth_repository.dart';
import '../dio_client.dart';

class DioAuthRepositoryImpl implements AuthRepository {
  final DioClient client;

  DioAuthRepositoryImpl({DioClient? dioClient})
      : client = dioClient ?? DioClient();

  Dio get _dio => client.dio;

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    if (data['accessToken'] != null) {
      await client.secureStorage.write(key: 'access_token', value: data['accessToken']);
    }
    if (data['refreshToken'] != null) {
      await client.secureStorage.write(key: 'refresh_token', value: data['refreshToken']);
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String fullName,
  ) async {
    final response = await _dio.post(
      ApiConstants.register,
      data: {
        'email': email,
        'password': password,
        'fullName': fullName,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> logout() async {
    try {
      final refreshToken = await client.secureStorage.read(key: 'refresh_token');
      if (refreshToken != null) {
        await _dio.post(
          ApiConstants.logout,
          data: {'refreshToken': refreshToken},
        );
      }
    } catch (_) {}
    await client.secureStorage.delete(key: 'access_token');
    await client.secureStorage.delete(key: 'refresh_token');
  }

  @override
  Future<User?> getProfile() async {
    final response = await _dio.get(ApiConstants.profile);
    if (response.statusCode == 200) {
      return User.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  }

  @override
  Future<User> updateProfile({
    required String fullName,
    String? phoneNumber,
  }) async {
    final response = await _dio.put(
      ApiConstants.profile,
      data: {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
      },
    );
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<bool> changePassword(
    String currentPassword,
    String newPassword, {
    bool logoutOtherDevices = false,
  }) async {
    try {
      final response = await _dio.post(
        '/api/auth/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'logoutOtherDevices': logoutOtherDevices,
        },
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return true;
    }
  }
}
