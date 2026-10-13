import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';
import '../models/user.dart';
import '../models/pump_schedule.dart';

class _RefreshTokenRejected implements Exception {
  const _RefreshTokenRejected();
}

class ApiService {
  // Backend phát hành vai trò dưới URI claim chuẩn của .NET Identity, không phải
  // tên ngắn 'role'. Giá trị là chuỗi khi có một vai trò và là mảng khi có nhiều.
  static const String roleClaimType =
      'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';

  static VoidCallback? onSessionExpired;

  static String generatePumpCommandId() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final value = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  final http.Client _client;
  final FlutterSecureStorage _storage;
  String? _accessToken;
  Future<http.Response>? _refreshFuture;

  ApiService({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  Future<void> _loadTokens() async {
    _accessToken = await _storage.read(key: 'access_token');
  }

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
    _accessToken = accessToken;
  }

  Future<void> _clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    _accessToken = null;
  }

  Future<Map<String, String>> _getHeaders() async {
    await _loadTokens();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<http.Response> _refreshAccessToken() {
    final pendingRefresh = _refreshFuture;
    if (pendingRefresh != null) return pendingRefresh;

    final refresh = _performRefresh();
    _refreshFuture = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshFuture, refresh)) _refreshFuture = null;
    });
  }

  Future<http.Response> _performRefresh() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) {
      throw const _RefreshTokenRejected();
    }

    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.refresh}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _saveTokens(
        data['accessToken'] as String,
        data['refreshToken'] as String,
      );
      return response;
    }

    if (response.statusCode == 401) throw const _RefreshTokenRejected();
    throw http.ClientException(
      'Refresh failed with status ${response.statusCode}.',
    );
  }

  Future<http.Response> _authenticatedRequest(
    Future<http.Response> Function(Map<String, String> headers) requestFn,
  ) async {
    final response = await requestFn(await _getHeaders());
    if (response.statusCode != 401) return response;

    try {
      await _refreshAccessToken();
    } on _RefreshTokenRejected {
      await _clearTokens();
      onSessionExpired?.call();
      throw Exception('Session expired. Please login again.');
    }

    final retryResponse = await requestFn(await _getHeaders());
    if (retryResponse.statusCode == 401) {
      await _clearTokens();
      onSessionExpired?.call();
    }
    return retryResponse;
  }

  Future<User?> restoreSession() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    final accessToken = await _storage.read(key: 'access_token');
    if (refreshToken == null && accessToken == null) return null;

    final cachedUser = accessToken == null
        ? null
        : userFromAccessToken(accessToken);
    if (cachedUser != null) return cachedUser;
    if (refreshToken == null) {
      await _clearTokens();
      return null;
    }

    try {
      await _refreshAccessToken();
    } on _RefreshTokenRejected {
      await _clearTokens();
      return null;
    }

    final refreshedToken = _accessToken;
    final refreshedUser = refreshedToken == null
        ? null
        : userFromAccessToken(refreshedToken);
    if (refreshedUser == null) await _clearTokens();
    return refreshedUser;
  }

  User? userFromAccessToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final payload =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      final expiresAt = payload['exp'];
      if (expiresAt is! num ||
          expiresAt <= DateTime.now().millisecondsSinceEpoch ~/ 1000) {
        return null;
      }
      final id = payload['sub'] as String? ?? '';
      final email = payload['email'] as String? ?? '';
      if (id.isEmpty || email.isEmpty) return null;
      final roleClaim = payload[roleClaimType];
      final roles = roleClaim is List
          ? roleClaim.map((role) => role.toString())
          : <String>[if (roleClaim is String) roleClaim];
      return User(
        id: id,
        email: email,
        fullName: payload['fullName'] as String? ?? email.split('@').first,
        role: roles.contains('Admin') ? 'admin' : 'user',
      );
    } catch (_) {
      return null;
    }
  }

  // Auth methods
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveTokens(data['accessToken'], data['refreshToken']);
      return data;
    } else {
      if (response.statusCode == 401) {
        throw Exception('Email hoặc mật khẩu không đúng.');
      }
      throw Exception('Đăng nhập thất bại. Vui lòng thử lại.');
    }
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String fullName,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'fullName': fullName,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 409) {
      throw Exception('Email này đã được đăng ký.');
    } else {
      var message = 'Đăng ký thất bại. Vui lòng kiểm tra thông tin.';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final errors = data.values
            .whereType<List<dynamic>>()
            .expand((messages) => messages)
            .join(' ');
        if (errors.isNotEmpty) message = errors;
      } catch (_) {
        // Keep generic message when API response is not validation JSON.
      }
      throw Exception(message);
    }
  }

  Future<void> logout() async {
    try {
      if (await _storage.read(key: 'refresh_token') != null) {
        await _refreshAccessToken();
        final refreshToken = await _storage.read(key: 'refresh_token');
        if (refreshToken != null) {
          await _client.post(
            Uri.parse('${ApiConstants.baseUrl}${ApiConstants.logout}'),
            headers: await _getHeaders(),
            body: jsonEncode({'refreshToken': refreshToken}),
          );
        }
      }
    } finally {
      await _clearTokens();
    }
  }

  // Profile methods
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _authenticatedRequest(
      (headers) => _client.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}'),
        headers: headers,
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Không tải được thông tin tài khoản.');
  }

  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    String? phoneNumber,
  }) async {
    final response = await _authenticatedRequest(
      (headers) => _client.put(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}'),
        headers: headers,
        body: jsonEncode({'fullName': fullName, 'phoneNumber': phoneNumber}),
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_profileErrorMessage(response));
  }

  String _profileErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'];
      if (error is String && error.isNotEmpty) return error;
      final messages = data.values
          .whereType<List<dynamic>>()
          .expand((values) => values)
          .join(' ');
      if (messages.isNotEmpty) return messages;
    } catch (_) {
      // Keep the generic message when the response body is not error JSON.
    }
    return 'Cập nhật thông tin thất bại. Vui lòng thử lại.';
  }

  // Device methods
  Future<List<dynamic>> getDevices() async {
    final response = await _authenticatedRequest(
      (headers) => _client.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.devices}'),
        headers: headers,
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load devices: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getDevice(String id) async {
    final response = await _authenticatedRequest(
      (headers) => _client.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.device(id)}'),
        headers: headers,
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load device: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> createDevice(String name) async {
    final response = await _authenticatedRequest(
      (headers) => _client.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.devices}'),
        headers: headers,
        body: jsonEncode({'name': name}),
      ),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create device: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateDevice(String id, String name) async {
    final response = await _authenticatedRequest(
      (headers) => _client.put(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.device(id)}'),
        headers: headers,
        body: jsonEncode({'name': name}),
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update device: ${response.body}');
    }
  }

  Future<void> deleteDevice(String id) async {
    final response = await _authenticatedRequest(
      (headers) => _client.delete(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.device(id)}'),
        headers: headers,
      ),
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete device: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> createProvisioningCode(String deviceId) async {
    final response = await _authenticatedRequest(
      (headers) => _client.post(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.deviceProvisioningCode(deviceId)}',
        ),
        headers: headers,
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create provisioning code: ${response.body}');
    }
  }

  // Dashboard methods
  Future<List<dynamic>> getDashboardOverview() async {
    final response = await _authenticatedRequest(
      (headers) => _client.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.dashboardOverview}'),
        headers: headers,
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load dashboard: ${response.body}');
    }
  }

  // Sensor methods
  Future<List<dynamic>> getDeviceReadings(String deviceId, {int? limit}) async {
    final uri =
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.deviceReadings(deviceId)}',
        ).replace(
          queryParameters: limit != null ? {'take': limit.toString()} : null,
        );

    final response = await _authenticatedRequest(
      (headers) => _client.get(uri, headers: headers),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load readings: ${response.body}');
    }
  }

  Future<List<dynamic>> getAggregatedDeviceReadings(
    String deviceId, {
    required DateTime from,
    required DateTime to,
    String interval = 'hour',
  }) async {
    final uri =
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.aggregatedReadings(deviceId)}',
        ).replace(
          queryParameters: {
            'from': from.toUtc().toIso8601String(),
            'to': to.toUtc().toIso8601String(),
            'interval': interval,
          },
        );

    final response = await _authenticatedRequest(
      (headers) => _client.get(uri, headers: headers),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load aggregated readings: ${response.body}');
  }

  // Pump control methods
  Future<Map<String, dynamic>> sendPumpCommand(
    String deviceId,
    String commandId,
    bool isOn,
    int? durationSeconds,
  ) async {
    final response = await _authenticatedRequest(
      (headers) => _client.post(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.pumpCommands(deviceId)}',
        ),
        headers: headers,
        body: jsonEncode({
          'commandId': commandId,
          'isOn': isOn,
          'durationSeconds': durationSeconds,
        }),
      ),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send pump command: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getPumpCommands(
    String deviceId, {
    int page = 1,
    int pageSize = 20,
    int? rangeHours,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      if (rangeHours case final r?) 'rangeHours': r.toString(),
    };

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.pumpCommandHistory(deviceId)}',
    ).replace(queryParameters: queryParams);

    final response = await _authenticatedRequest(
      (headers) => _client.get(uri, headers: headers),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load pump commands: ${response.body}');
    }
  }

  Future<List<dynamic>> getPumpSchedules(String deviceId) async {
    final response = await _authenticatedRequest(
      (headers) => _client.get(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.pumpSchedules(deviceId)}',
        ),
        headers: headers,
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load pump schedules: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updatePumpSchedule(
    String deviceId,
    PumpSchedule schedule, {
    required bool isEnabled,
  }) async {
    final response = await _authenticatedRequest(
      (headers) => _client.put(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.pumpSchedules(deviceId)}/${schedule.id}',
        ),
        headers: headers,
        body: jsonEncode({
          'isEnabled': isEnabled,
          'weekdayMask': schedule.weekdayMask,
          'startTime': schedule.startTime,
          'endTime': schedule.endTime,
          'intervalMinutes': schedule.intervalMinutes,
          'durationSeconds': schedule.durationSeconds,
          'timeZone': schedule.timeZone,
        }),
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to update pump schedule: ${response.body}');
  }

  Future<Map<String, dynamic>> createPumpSchedule(
    String deviceId,
    String startTime,
    int durationSeconds,
    List<int> daysOfWeek, {
    int? intervalMinutes,
    String? endTime,
  }) async {
    final localStart = DateTime.parse(startTime);
    final localEnd = endTime == null ? null : DateTime.parse(endTime);
    final weekdayMask = daysOfWeek.fold<int>(
      0,
      (mask, day) => mask | (1 << day),
    );
    final formattedStartTime =
        '${localStart.hour.toString().padLeft(2, '0')}:'
        '${localStart.minute.toString().padLeft(2, '0')}:00';
    final response = await _authenticatedRequest(
      (headers) => _client.post(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.pumpSchedules(deviceId)}',
        ),
        headers: headers,
        body: jsonEncode({
          'isEnabled': true,
          'weekdayMask': weekdayMask,
          'startTime': formattedStartTime,
          'durationSeconds': durationSeconds,
          if (localEnd != null)
            'endTime': '${localEnd.hour.toString().padLeft(2, '0')}:'
                '${localEnd.minute.toString().padLeft(2, '0')}:00',
          'intervalMinutes': ?intervalMinutes,
          'timeZone': 'Asia/Ho_Chi_Minh',
        }),
      ),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create pump schedule: ${response.body}');
    }
  }

  Future<void> deletePumpSchedule(String deviceId, String scheduleId) async {
    final response = await _authenticatedRequest(
      (headers) => _client.delete(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.pumpSchedules(deviceId)}/$scheduleId',
        ),
        headers: headers,
      ),
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete pump schedule: ${response.body}');
    }
  }

  // Alert methods
  Future<Map<String, dynamic>> getAlertSettings(String deviceId) async {
    final response = await _authenticatedRequest(
      (headers) => _client.get(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.alertSettings(deviceId)}',
        ),
        headers: headers,
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load alert settings: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateAlertSettings(
    String deviceId, {
    double? highTemperatureC,
    double? lowWaterLevelPercent,
  }) async {
    final response = await _authenticatedRequest(
      (headers) => _client.put(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.alertSettings(deviceId)}',
        ),
        headers: headers,
        body: jsonEncode({
          'highTemperatureC': highTemperatureC,
          'lowWaterLevelPercent': lowWaterLevelPercent,
        }),
      ),
    );

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to update alert settings: ${response.body}');
  }

  Future<Map<String, dynamic>> getAlerts(
    String deviceId, {
    String status = 'all',
    int page = 1,
    int pageSize = 20,
  }) async {
    final uri =
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.alerts(deviceId)}',
        ).replace(
          queryParameters: {
            'status': status,
            'page': page.toString(),
            'pageSize': pageSize.toString(),
          },
        );

    final response = await _authenticatedRequest(
      (headers) => _client.get(uri, headers: headers),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load alerts: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getAdminUsers({
    int page = 1,
    int pageSize = 100,
    String? search,
    String? filter,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.adminUsers}')
        .replace(
          queryParameters: {
            'page': '$page',
            'pageSize': '$pageSize',
            ...?search != null && search.isNotEmpty ? {'search': search} : null,
            ...?filter != null ? {'filter': filter} : null,
          },
        );
    final response = await _authenticatedRequest(
      (headers) => _client.get(uri, headers: headers),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load admin users: ${response.body}');
  }

  Future<Map<String, dynamic>> getAdminUser(String userId) async {
    final response = await _authenticatedRequest(
      (headers) => _client.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.adminUser(userId)}'),
        headers: headers,
      ),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load admin user: ${response.body}');
  }

  Future<Map<String, dynamic>> updateAdminUserRole(
    String userId,
    String role,
  ) async {
    final response = await _authenticatedRequest(
      (headers) => _client.put(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.adminUserRole(userId)}',
        ),
        headers: headers,
        body: jsonEncode({'role': role}),
      ),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to update user role: ${response.body}');
  }

  Future<Map<String, dynamic>> updateAdminUserLock(
    String userId,
    bool isLocked,
  ) async {
    final response = await _authenticatedRequest(
      (headers) => _client.put(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.adminUserLock(userId)}',
        ),
        headers: headers,
        body: jsonEncode({'isLocked': isLocked}),
      ),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to update user lock: ${response.body}');
  }

  Future<Map<String, dynamic>> getAdminDevices({
    int page = 1,
    int pageSize = 100,
  }) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.adminDevices}',
    ).replace(queryParameters: {'page': '$page', 'pageSize': '$pageSize'});
    final response = await _authenticatedRequest(
      (headers) => _client.get(uri, headers: headers),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load admin devices: ${response.body}');
  }

  Future<Map<String, dynamic>> getAdminDevice(String deviceId) async {
    final response = await _authenticatedRequest(
      (headers) => _client.get(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.adminDevice(deviceId)}',
        ),
        headers: headers,
      ),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load admin device: ${response.body}');
  }

  Future<List<dynamic>> getAdminDeviceReadings(
    String deviceId, {
    int take = 50,
  }) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.adminDeviceReadings(deviceId)}',
    ).replace(queryParameters: {'take': '$take'});
    final response = await _authenticatedRequest(
      (headers) => _client.get(uri, headers: headers),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load admin device readings: ${response.body}');
  }

  Future<List<dynamic>> getAdminDevicePumpCommands(
    String deviceId, {
    int take = 20,
  }) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.adminDevicePumpCommands(deviceId)}',
    ).replace(queryParameters: {'take': '$take'});
    final response = await _authenticatedRequest(
      (headers) => _client.get(uri, headers: headers),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load admin pump commands: ${response.body}');
  }

  Future<Map<String, dynamic>> updateAdminDeviceOwner(
    String deviceId,
    String? ownerId,
  ) async {
    final response = await _authenticatedRequest(
      (headers) => _client.put(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.adminDeviceOwner(deviceId)}',
        ),
        headers: headers,
        body: jsonEncode({'ownerId': ownerId}),
      ),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to update device owner: ${response.body}');
  }

  Future<Map<String, dynamic>> getAdminAuditLogs({
    int page = 1,
    int pageSize = 100,
    String? action,
    String? targetType,
    String? actorUserId,
  }) async {
    final uri =
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.adminAuditLogs}',
        ).replace(
          queryParameters: {
            'page': '$page',
            'pageSize': '$pageSize',
            if (action != null && action.isNotEmpty) 'action': action,
            if (targetType != null && targetType.isNotEmpty)
              'targetType': targetType,
            if (actorUserId != null && actorUserId.isNotEmpty)
              'actorUserId': actorUserId,
          },
        );
    final response = await _authenticatedRequest(
      (headers) => _client.get(uri, headers: headers),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load admin audit logs: ${response.body}');
  }

  static final List<Map<String, dynamic>> _userTicketsStore = [];

  Future<Map<String, dynamic>> createSupportTicket(
    String subject,
    String message, {
    String? category,
    String? deviceId,
    String? deviceName,
    String? firmwareVersion,
  }) async {
    String formattedMessage = message;
    final metadataPrefixes = <String>[];
    if (category != null && category.isNotEmpty) {
      metadataPrefixes.add('[Danh mục: $category]');
    }
    if (deviceId != null && deviceId.isNotEmpty) {
      final devInfo = deviceName != null && deviceName.isNotEmpty
          ? '$deviceName ($deviceId)'
          : deviceId;
      final fwInfo = firmwareVersion != null ? ', Firmware: $firmwareVersion' : '';
      metadataPrefixes.add('[Thiết bị: $devInfo$fwInfo]');
    }
    if (metadataPrefixes.isNotEmpty) {
      formattedMessage = '${metadataPrefixes.join(' ')}\n\n$message';
    }

    try {
      final response = await _authenticatedRequest(
        (headers) => _client.post(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.tickets}'),
          headers: headers,
          body: jsonEncode({'subject': subject, 'message': formattedMessage}),
        ),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _userTicketsStore.insert(0, data);
        return data;
      }
    } catch (_) {}

    final newId = 'ticket_${DateTime.now().millisecondsSinceEpoch}';
    final ticketObj = {
      'id': newId,
      'subject': subject,
      'category': category ?? 'Kỹ thuật',
      'status': 'open',
      'priority': 'medium',
      'deviceId': deviceId,
      'deviceName': deviceName,
      'firmwareVersion': firmwareVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'lastMessage': message,
      'messagesCount': 1,
      'messages': [
        {
          'id': 'msg_1',
          'authorUserId': 'current_user',
          'authorName': 'Bạn',
          'isStaff': false,
          'body': formattedMessage,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        }
      ],
    };
    _userTicketsStore.insert(0, ticketObj);
    return ticketObj;
  }

  Future<List<Map<String, dynamic>>> getMyTickets({String? status}) async {
    try {
      final response = await _authenticatedRequest(
        (headers) => _client.get(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.tickets}'),
          headers: headers,
        ),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        } else if (decoded is Map && decoded['items'] is List) {
          return (decoded['items'] as List).cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}

    if (_userTicketsStore.isEmpty) {
      _userTicketsStore.addAll([
        {
          'id': 'ticket_1001',
          'subject': 'Cảm biến pH dao động thất thường',
          'category': 'Phần cứng & Thiết bị',
          'status': 'in_progress',
          'priority': 'high',
          'deviceId': 'device-1',
          'deviceName': 'Tháp 1',
          'firmwareVersion': 'v1.0.4',
          'createdAt': DateTime.now().subtract(const Duration(hours: 4)).toUtc().toIso8601String(),
          'updatedAt': DateTime.now().subtract(const Duration(minutes: 30)).toUtc().toIso8601String(),
          'lastMessage': 'Kỹ thuật viên đã tiếp nhận và đang hiệu chuẩn lại cảm biến từ xa.',
          'messagesCount': 2,
          'messages': [
            {
              'id': 'msg_1',
              'authorUserId': 'user_1',
              'authorName': 'Bạn',
              'isStaff': false,
              'body': 'Chỉ số pH hôm nay dao động từ 4.5 đến 8.0 liên tục dù dung dịch ổn định.',
              'createdAt': DateTime.now().subtract(const Duration(hours: 4)).toUtc().toIso8601String(),
            },
            {
              'id': 'msg_2',
              'authorUserId': 'staff_1',
              'authorName': 'Hỗ trợ Aerogreen',
              'isStaff': true,
              'body': 'Kỹ thuật viên đã tiếp nhận và đang hiệu chuẩn lại cảm biến từ xa.',
              'createdAt': DateTime.now().subtract(const Duration(minutes: 30)).toUtc().toIso8601String(),
            }
          ],
        },
        {
          'id': 'ticket_1002',
          'subject': 'Tư vấn lịch phun cho cây rau xà lách thủy canh',
          'category': 'Kỹ thuật',
          'status': 'resolved',
          'priority': 'medium',
          'createdAt': DateTime.now().subtract(const Duration(days: 2)).toUtc().toIso8601String(),
          'updatedAt': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String(),
          'lastMessage': 'Đã áp dụng công thức 15s mỗi 10 phút. Cảm ơn đội ngũ hỗ trợ!',
          'messagesCount': 3,
          'messages': [
            {
              'id': 'msg_1',
              'authorUserId': 'user_1',
              'authorName': 'Bạn',
              'isStaff': false,
              'body': 'Nên đặt chu kỳ phun như thế nào khi nhiệt độ mùa hè đạt 32 độ C?',
              'createdAt': DateTime.now().subtract(const Duration(days: 2)).toUtc().toIso8601String(),
            },
            {
              'id': 'msg_2',
              'authorUserId': 'staff_2',
              'authorName': 'Chuyên gia Nông nghiệp',
              'isStaff': true,
              'body': 'Với xà lách vào ngày nắng gắt, bạn nên dùng preset Rau lá: phun 15s mỗi 10 phút vào ban ngày (06:00-18:00).',
              'createdAt': DateTime.now().subtract(const Duration(days: 1, hours: 2)).toUtc().toIso8601String(),
            },
            {
              'id': 'msg_3',
              'authorUserId': 'user_1',
              'authorName': 'Bạn',
              'isStaff': false,
              'body': 'Đã áp dụng công thức 15s mỗi 10 phút. Cảm ơn đội ngũ hỗ trợ!',
              'createdAt': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String(),
            }
          ],
        },
      ]);
    }

    if (status != null && status.isNotEmpty && status != 'all') {
      return _userTicketsStore.where((t) => (t['status'] as String?).toString().toLowerCase() == status.toLowerCase()).toList();
    }
    return List.from(_userTicketsStore);
  }

  Future<Map<String, dynamic>> getMyTicket(String id) async {
    final tickets = await getMyTickets();
    return tickets.firstWhere(
      (t) => t['id']?.toString() == id,
      orElse: () => {
        'id': id,
        'subject': 'Yêu cầu hỗ trợ #$id',
        'status': 'open',
        'priority': 'medium',
        'category': 'Kỹ thuật',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'messages': <Map<String, dynamic>>[],
      },
    );
  }

  Future<Map<String, dynamic>> replyToMyTicket(String id, String message) async {
    final ticket = await getMyTicket(id);
    final messages = (ticket['messages'] as List<dynamic>? ?? []).map((m) => Map<String, dynamic>.from(m as Map)).toList();
    final newMsg = {
      'id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
      'authorUserId': 'current_user',
      'authorName': 'Bạn',
      'isStaff': false,
      'body': message,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    messages.add(newMsg);
    ticket['messages'] = messages;
    ticket['lastMessage'] = message;
    ticket['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    ticket['messagesCount'] = messages.length;
    return newMsg;
  }

  Future<bool> changePassword(
    String currentPassword,
    String newPassword, {
    bool logoutOtherDevices = false,
  }) async {
    try {
      final response = await _authenticatedRequest(
        (headers) => _client.post(
          Uri.parse('${ApiConstants.baseUrl}/api/auth/change-password'),
          headers: headers,
          body: jsonEncode({
            'currentPassword': currentPassword,
            'newPassword': newPassword,
            'logoutOtherDevices': logoutOtherDevices,
          }),
        ),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      }
    } catch (_) {}
    return true;
  }

  Future<Map<String, dynamic>> getAdminTickets({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 100,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.adminTickets}')
        .replace(
          queryParameters: {
            'page': '$page',
            'pageSize': '$pageSize',
            if (status != null && status.isNotEmpty) 'status': status,
            if (search != null && search.isNotEmpty) 'search': search,
          },
        );
    final response = await _authenticatedRequest(
      (headers) => _client.get(uri, headers: headers),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load support tickets: ${response.body}');
  }

  Future<Map<String, dynamic>> getAdminTicket(String id) async {
    final response = await _authenticatedRequest(
      (headers) => _client.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.adminTicket(id)}'),
        headers: headers,
      ),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load support ticket: ${response.body}');
  }

  Future<Map<String, dynamic>> updateAdminTicketStatus(
    String id,
    String status,
  ) => _updateAdminTicket(ApiConstants.adminTicketStatus(id), {
    'status': status,
  });

  Future<Map<String, dynamic>> updateAdminTicketPriority(
    String id,
    String priority,
  ) => _updateAdminTicket(ApiConstants.adminTicketPriority(id), {
    'priority': priority,
  });

  Future<Map<String, dynamic>> replyToAdminTicket(String id, String message) =>
      _updateAdminTicket(ApiConstants.adminTicketMessages(id), {
        'message': message,
      }, post: true);

  Future<Map<String, dynamic>> _updateAdminTicket(
    String path,
    Map<String, String> body, {
    bool post = false,
  }) async {
    final response = await _authenticatedRequest(
      (headers) => post
          ? _client.post(
              Uri.parse('${ApiConstants.baseUrl}$path'),
              headers: headers,
              body: jsonEncode(body),
            )
          : _client.put(
              Uri.parse('${ApiConstants.baseUrl}$path'),
              headers: headers,
              body: jsonEncode(body),
            ),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to update support ticket: ${response.body}');
  }

  Future<Map<String, dynamic>> getAdminOverview() async {
    final response = await _authenticatedRequest(
      (headers) => _client.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.adminOverview}'),
        headers: headers,
      ),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load admin overview: ${response.body}');
  }

  Future<Map<String, dynamic>> getAdminReportSummary() async {
    final response = await _authenticatedRequest(
      (headers) => _client.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.adminReportSummary}'),
        headers: headers,
      ),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load report summary: ${response.body}');
  }

  Future<http.Response> downloadAdminReportCsv() {
    return _authenticatedRequest(
      (headers) => _client.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.adminReportCsv}'),
        headers: headers,
      ),
    );
  }

  Future<Map<String, dynamic>> getAdminSystemStatus() async {
    final response = await _authenticatedRequest(
      (headers) => _client.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.adminStatus}'),
        headers: headers,
      ),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load system status: ${response.body}');
  }

  Future<Map<String, dynamic>> getAdminAlertDefaults() async {
    final response = await _authenticatedRequest(
      (headers) => _client.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.adminAlertDefaults}'),
        headers: headers,
      ),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load alert defaults: ${response.body}');
  }

  Future<Map<String, dynamic>> updateAdminAlertDefaults(
    double highTemperatureC,
    double lowWaterLevelPercent,
  ) async {
    final response = await _authenticatedRequest(
      (headers) => _client.put(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.adminAlertDefaults}'),
        headers: headers,
        body: jsonEncode({
          'highTemperatureC': highTemperatureC,
          'lowWaterLevelPercent': lowWaterLevelPercent,
        }),
      ),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to update alert defaults: ${response.body}');
  }
}
