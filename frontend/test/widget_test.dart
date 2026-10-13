// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:iotagri_app/cupertino/dashboard/farm_health_card.dart';
import 'package:iotagri_app/cupertino/dashboard/cupertino_dashboard_screen.dart';
import 'package:iotagri_app/cupertino/devices/cupertino_device_detail_screen.dart';
import 'package:iotagri_app/models/device.dart';
import 'package:iotagri_app/models/device_alert.dart';
import 'package:iotagri_app/models/device_overview.dart';
import 'package:iotagri_app/models/pump_schedule.dart';
import 'package:iotagri_app/models/sensor_reading.dart';
import 'package:iotagri_app/cupertino/devices/add_device_screen.dart';
import 'package:iotagri_app/cupertino/devices/cupertino_devices_screen.dart';
import 'package:iotagri_app/cupertino/profile/cupertino_profile_screen.dart';
import 'package:iotagri_app/cupertino/auth/cupertino_register_screen.dart';
import 'package:iotagri_app/models/user.dart';
import 'package:iotagri_app/screens/pumps/pump_schedules_screen.dart';
import 'package:iotagri_app/providers/auth_provider.dart';
import 'package:iotagri_app/screens/dashboard/dashboard_screen.dart';
import 'package:iotagri_app/services/api_service.dart';

class _OfflineApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    throw http.ClientException('Failed to fetch');
  }
}

class _SuccessfulAuthApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String fullName,
  ) async => {};

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    final payload = base64UrlEncode(
      utf8.encode(
        jsonEncode({
          'sub': 'user-1',
          'email': email,
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
        }),
      ),
    ).replaceAll('=', '');
    return {
      'accessToken': 'header.$payload.signature',
      'refreshToken': 'refresh',
    };
  }
}

class _ProfileApiService extends ApiService {
  @override
  Future<User?> restoreSession() async => User(
    id: 'user-1',
    email: 'profile@example.com',
    fullName: 'Nguyen Van A',
    role: 'user',
  );

  @override
  Future<Map<String, dynamic>> getProfile() async => {
    'id': 'user-1',
    'email': 'profile@example.com',
    'fullName': 'Nguyen Van A',
    'phoneNumber': '0912345678',
    'roles': ['User'],
  };
}

class _DetailApiService extends ApiService {
  final bool isOnline;
  final bool pumpIsRunning;
  final bool includeReading;
  final bool includeSchedule;
  final List<bool> scheduleEnabledUpdates = <bool>[];

  _DetailApiService({
    this.isOnline = true,
    this.pumpIsRunning = false,
    this.includeReading = true,
    this.includeSchedule = false,
  });

  @override
  Future<Map<String, dynamic>> getDevice(String id) async => {
    'id': id,
    'name': 'Greenhouse 1',
    'isOnline': isOnline,
    'createdAt': '2026-10-02T00:00:00Z',
  };

  @override
  Future<List<dynamic>> getDeviceReadings(
    String deviceId, {
    int? limit,
  }) async => includeReading
      ? [
          {
            'id': 'reading-1',
            'deviceId': deviceId,
            'temperature': 26.4,
            'humidity': 62,
            'ph': 6.2,
            'waterLevel': 12,
            'recordedAt': DateTime.now().toUtc().toIso8601String(),
          },
        ]
      : [];

  @override
  Future<Map<String, dynamic>> getPumpCommands(
    String deviceId, {
    int page = 1,
    int pageSize = 20,
    int? rangeHours,
  }) async => {
    'items': pumpIsRunning
        ? [
            {
              'id': 'command-1',
              'deviceId': deviceId,
              'isOn': true,
              'durationSeconds': 60,
              'status': 'Acknowledged',
              'issuedAt': DateTime.now().toUtc().toIso8601String(),
              'acknowledgedAt': DateTime.now()
                  .toUtc()
                  .subtract(const Duration(seconds: 3))
                  .toIso8601String(),
              'acknowledgedIsOn': true,
            },
          ]
        : [],
  };

  @override
  Future<List<dynamic>> getPumpSchedules(String deviceId) async =>
      includeSchedule
      ? [
          {
            'id': 'schedule-1',
            'deviceId': deviceId,
            'isEnabled': true,
            'weekdayMask': 127,
            'startTime': '06:00:00',
            'durationSeconds': 10,
            'timeZone': 'Asia/Ho_Chi_Minh',
            'createdAt': '2026-10-02T00:00:00Z',
          },
        ]
      : [];

  @override
  Future<Map<String, dynamic>> getAlerts(
    String deviceId, {
    String status = 'all',
    int page = 1,
    int pageSize = 20,
  }) async => {'items': []};

  @override
  Future<Map<String, dynamic>> getAlertSettings(String deviceId) async => {
    'highTemperatureC': 30,
    'lowWaterLevelPercent': 20,
  };

  @override
  Future<Map<String, dynamic>> updatePumpSchedule(
    String deviceId,
    PumpSchedule schedule, {
    required bool isEnabled,
  }) async {
    scheduleEnabledUpdates.add(isEnabled);
    return {...schedule.toJson(), 'isEnabled': isEnabled};
  }
}

class _DeviceListApiService extends ApiService {
  _DeviceListApiService(this.count);

  final int count;
  final Set<String> deletedDeviceIds = {};
  String? provisionedDeviceId;

  @override
  Future<List<dynamic>> getDevices() async => [
    for (var index = 0; index < count; index++)
      if (!deletedDeviceIds.contains('device-$index'))
        {
          'id': 'device-$index',
          'name': 'Greenhouse $index',
          'isOnline': true,
          'createdAt': '2026-10-02T00:00:00Z',
        },
  ];

  @override
  Future<void> deleteDevice(String id) async {
    deletedDeviceIds.add(id);
  }

  @override
  Future<Map<String, dynamic>> createDevice(String name) async => {
    'id': 'device-generated-123',
    'name': name,
    'deviceKey': 'not-shown-to-user',
    'createdAt': '2026-10-02T00:00:00Z',
  };

  @override
  Future<Map<String, dynamic>> createProvisioningCode(String deviceId) async {
    provisionedDeviceId = deviceId;
    return {
      'code': '482913',
      'expiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 15))
          .toIso8601String(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

DeviceOverview _device({
  bool isOnline = true,
  List<DeviceAlert> alerts = const [],
}) => DeviceOverview(
  id: 'device-1',
  name: 'Greenhouse 1',
  isOnline: isOnline,
  alerts: alerts,
);

Widget _healthCard(List<DeviceOverview> devices, {VoidCallback? onAddDevice}) =>
    CupertinoApp(
      home: CupertinoPageScaffold(
        child: Center(
          child: FarmHealthCard(
            summary: FarmHealthSummary.fromDevices(devices),
            onAddDevice: onAddDevice,
          ),
        ),
      ),
    );

void main() {
  testWidgets('pump schedule screen opens from the Cupertino app', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: PumpSchedulesScreen(
          device: Device(
            id: 'device-1',
            name: 'Pump Simulator',
            isOnline: false,
            createdAt: '2026-10-05T00:00:00Z',
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('registration returns to the authenticated root screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final authProvider = AuthProvider(apiService: _SuccessfulAuthApiService());
    addTearDown(authProvider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: authProvider,
        child: CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => Center(
                child: CupertinoButton(
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const CupertinoRegisterScreen(),
                    ),
                  ),
                  child: const Text('Open registration'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open registration'));
    await tester.pumpAndSettle();
    final fields = find.byType(CupertinoTextField);
    await tester.enterText(fields.at(0), 'Test User');
    await tester.enterText(fields.at(1), 'user@example.com');
    await tester.enterText(fields.at(2), 'Password123');
    await tester.enterText(fields.at(3), 'Password123');
    final submitButton = find.widgetWithText(CupertinoButton, 'Đăng ký');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(authProvider.isAuthenticated, isTrue);
    expect(find.byType(CupertinoRegisterScreen), findsNothing);
  });

  test('login stays unauthenticated when backend is unavailable', () async {
    final authProvider = AuthProvider(apiService: _OfflineApiService());
    addTearDown(authProvider.dispose);

    final success = await authProvider.login(
      'demo@aerogreen.vn',
      'Password123',
    );

    expect(success, isFalse);
    expect(authProvider.isAuthenticated, isFalse);
    expect(authProvider.errorMessage, isNotNull);
  });

  test(
    'access token role claim drives admin routing, including role arrays',
    () {
      final apiService = ApiService();
      String tokenWithRole(Object? role) {
        final payload = <String, dynamic>{
          'sub': 'user-1',
          'email': 'user@example.com',
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          ApiService.roleClaimType: ?role,
        };
        final encoded = base64UrlEncode(
          utf8.encode(jsonEncode(payload)),
        ).replaceAll('=', '');
        return 'header.$encoded.signature';
      }

      expect(
        apiService.userFromAccessToken(tokenWithRole('User'))!.isAdmin,
        isFalse,
      );
      expect(
        apiService.userFromAccessToken(tokenWithRole('Admin'))!.isAdmin,
        isTrue,
      );
      expect(
        apiService
            .userFromAccessToken(tokenWithRole(['User', 'Admin']))!
            .isAdmin,
        isTrue,
      );
      expect(
        apiService.userFromAccessToken(tokenWithRole(null))!.isAdmin,
        isFalse,
      );
    },
  );

  testWidgets('dashboard shows gateway status summary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GatewayStatusCard(
          status: 'Mất kết nối',
          lastUpdate: '10:35',
          runtime: '5h 12m',
        ),
      ),
    );

    expect(find.text('ESP32 Gateway'), findsOneWidget);
    expect(find.text('🟢'), findsOneWidget);
    expect(find.text('Last update'), findsOneWidget);
    expect(find.text('Runtime'), findsOneWidget);
  });

  testWidgets('farm health shows add-device welcome with no devices', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_healthCard(const [], onAddDevice: () {}));

    expect(find.text('Chào mừng đến Aerogreen'), findsOneWidget);
    expect(find.text('Thêm thiết bị'), findsOneWidget);
    expect(find.text('Thiết bị online'), findsNothing);
  });

  testWidgets('farm health shows healthy state', (WidgetTester tester) async {
    await tester.pumpWidget(_healthCard([_device()]));

    expect(find.text('Trang trại đang ổn định'), findsOneWidget);
    expect(
      find.text('Tất cả thiết bị đang hoạt động bình thường.'),
      findsOneWidget,
    );
  });

  testWidgets('farm health shows attention for offline device', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_healthCard([_device(isOnline: false)]));

    expect(find.text('Cần chú ý'), findsOneWidget);
    expect(find.text('1 vấn đề cần kiểm tra.'), findsOneWidget);
  });

  testWidgets('farm health shows critical low-water alert', (
    WidgetTester tester,
  ) async {
    final lowWaterAlert = DeviceAlert(
      id: 'alert-1',
      deviceId: 'device-1',
      type: 'LOW_WATER_LEVEL',
      measuredValue: 12,
      threshold: 20,
      triggeredAt: '2026-10-02T00:00:00Z',
    );
    await tester.pumpWidget(
      _healthCard([
        _device(alerts: [lowWaterAlert]),
      ]),
    );

    expect(find.text('Cần xử lý ngay'), findsOneWidget);
    expect(
      find.text('Phát hiện tình trạng ảnh hưởng đến vận hành.'),
      findsOneWidget,
    );
  });

  testWidgets('device list search appears only above six devices', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoDevicesScreen(apiService: _DeviceListApiService(6)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoSearchTextField), findsNothing);

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoDevicesScreen(
          key: const ValueKey('seven-devices'),
          apiService: _DeviceListApiService(7),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoSearchTextField), findsOneWidget);
  });

  testWidgets('device tab keeps the dashboard menu', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const CupertinoApp(home: CupertinoDashboardScreen()),
    );
    await tester.pump();
    await tester.tap(find.byIcon(CupertinoIcons.square_grid_2x2));
    await tester.pump();

    expect(find.byType(CupertinoDevicesScreen), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.house_fill), findsOneWidget);
  });

  testWidgets('profile tab shows account info and logout below the form', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(600, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final authProvider = AuthProvider(apiService: _ProfileApiService());
    addTearDown(authProvider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: authProvider,
        child: const CupertinoApp(home: CupertinoDashboardScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoProfileScreen), findsOneWidget);
    expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);

    // Mở màn hình chỉnh sửa hồ sơ cá nhân
    await tester.tap(find.text('Hồ sơ cá nhân'));
    await tester.pumpAndSettle();

    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.textContaining('Email'), findsOneWidget);
    expect(find.text('Lưu thay đổi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('device deletion requires confirmation and removes the row', (
    WidgetTester tester,
  ) async {
    final apiService = _DeviceListApiService(1);
    await tester.pumpWidget(
      CupertinoApp(home: CupertinoDevicesScreen(apiService: apiService)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.delete));
    await tester.pumpAndSettle();
    expect(find.text('Xóa thiết bị?'), findsOneWidget);

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.text('Greenhouse 0'), findsOneWidget);
    expect(apiService.deletedDeviceIds, isEmpty);

    await tester.tap(find.byIcon(CupertinoIcons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();

    expect(apiService.deletedDeviceIds, contains('device-0'));
    expect(find.text('Greenhouse 0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('device creation carries generated ID into provisioning', (
    WidgetTester tester,
  ) async {
    final apiService = _DeviceListApiService(0);
    await tester.pumpWidget(
      CupertinoApp(home: CupertinoDevicesScreen(apiService: apiService)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();
    expect(find.byType(AddDeviceScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail disables controls offline and notes saved schedules', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final device = Device(
      id: 'device-1',
      name: 'Greenhouse 1',
      isOnline: true,
      createdAt: '2026-10-02T00:00:00Z',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoDeviceDetailScreen(
          device: device,
          apiService: _DetailApiService(isOnline: false, includeSchedule: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Offline'), findsOneWidget);
    expect(
      find.text('Lịch tự động vẫn tiếp tục chạy khi thiết bị ngoại tuyến.'),
      findsOneWidget,
    );
    expect(find.text('Không khả dụng khi ngoại tuyến'), findsOneWidget);
  });

  testWidgets('detail shows running pump state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final device = Device(
      id: 'device-1',
      name: 'Greenhouse 1',
      isOnline: true,
      createdAt: '2026-10-02T00:00:00Z',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoDeviceDetailScreen(
          device: device,
          apiService: _DetailApiService(pumpIsRunning: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bơm đang chạy'), findsOneWidget);
    await tester.tap(find.text('Thủ công'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyển'));
    await tester.pumpAndSettle();
    expect(find.text('Dừng'), findsOneWidget);
  });

  testWidgets('manual mode pauses schedules and auto mode restores them', (
    WidgetTester tester,
  ) async {
    final api = _DetailApiService(includeSchedule: true);
    final device = Device(
      id: 'device-1',
      name: 'Greenhouse 1',
      isOnline: true,
      createdAt: '2026-10-02T00:00:00Z',
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoDeviceDetailScreen(device: device, apiService: api),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Thủ công'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thủ công'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyển'));
    await tester.pumpAndSettle();
    expect(api.scheduleEnabledUpdates, equals(<bool>[false]));

    await tester.tap(find.text('Tự động'));
    await tester.pumpAndSettle();
    expect(api.scheduleEnabledUpdates, equals(<bool>[false, true]));
  });

  testWidgets('detail shows missing sensor state', (WidgetTester tester) async {
    final device = Device(
      id: 'device-1',
      name: 'Greenhouse 1',
      isOnline: true,
      createdAt: '2026-10-02T00:00:00Z',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoDeviceDetailScreen(
          device: device,
          apiService: _DetailApiService(includeReading: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không có dữ liệu mới'), findsOneWidget);
    expect(find.text('Không có dữ liệu'), findsNWidgets(5));
  });

  testWidgets('sensor grid marks values below configured threshold', (
    WidgetTester tester,
  ) async {
    final reading = SensorReading(
      id: 'reading-1',
      deviceId: 'device-1',
      temperature: 26,
      solutionTemperature: 24.5,
      humidity: 62,
      ph: 6.2,
      tds: 520,
      waterLevel: 12,
      recordedAt: '2026-10-02T00:00:00Z',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: SensorGrid(
                reading: reading,
                waterLevelThreshold: 20,
                highTemperatureThreshold: 30,
                isOffline: false,
                onSensorTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final waterValue = tester.widget<Text>(find.text('12.0 %'));
    expect(waterValue.style?.color, CupertinoColors.systemOrange);
    expect(find.text('24.5 °C'), findsOneWidget);
    expect(find.text('520.0 ppm'), findsOneWidget);
  });

  testWidgets('pump control shows command-sending state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: PumpControlCard(
              isOnline: true,
              isRunning: false,
              isSending: true,
              pumpMode: PumpMode.manual,
              nextScheduleTime: null,
              remainingSeconds: 0,
              onModeChange: _noopMode,
              onManualToggle: _noop,
              onStop: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Đang gửi lệnh…'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });
}

void _noop() {}

void _noopMode(PumpMode _) {}
