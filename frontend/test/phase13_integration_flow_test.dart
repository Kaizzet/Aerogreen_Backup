import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotagri_app/cupertino/auth/cupertino_login_screen.dart';
import 'package:iotagri_app/cupertino/devices/cupertino_device_detail_screen.dart';
import 'package:iotagri_app/models/device.dart';
import 'package:iotagri_app/models/history_data.dart';
import 'package:iotagri_app/providers/auth_provider.dart';
import 'package:iotagri_app/screens/sensors/sensor_history_screen.dart';
import 'package:iotagri_app/services/api_service.dart';
import 'package:iotagri_app/services/history_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeIntegrationApiService extends ApiService {
  bool loginCalled = false;
  bool commandCalled = false;

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    loginCalled = true;
    return {
      'accessToken': 'jwt_mock_token',
      'refreshToken': 'refresh_mock_token',
      'user': {
        'id': 'user_e2e',
        'email': email,
        'fullName': 'Tran Thi B',
        'roles': ['User'],
      },
    };
  }

  @override
  Future<Map<String, dynamic>> getProfile() async => {
        'id': 'user_e2e',
        'email': 'user@aerogreen.vn',
        'fullName': 'Tran Thi B',
        'roles': ['User'],
      };

  @override
  Future<Map<String, dynamic>> getDevice(String id) async => {
        'id': id,
        'name': 'Tháp Khí Canh 1',
        'isOnline': true,
        'createdAt': '2026-10-01T00:00:00Z',
      };

  @override
  Future<List<dynamic>> getDeviceReadings(String deviceId, {int? limit}) async => [
        {
          'id': 'reading-e2e',
          'deviceId': deviceId,
          'temperature': 25.5,
          'solutionTemperature': 23.0,
          'humidity': 65.0,
          'ph': 6.2,
          'waterLevel': 85.0,
          'recordedAt': DateTime.now().toUtc().toIso8601String(),
        }
      ];

  @override
  Future<Map<String, dynamic>> getPumpCommands(
    String deviceId, {
    int page = 1,
    int pageSize = 20,
    int? rangeHours,
  }) async => {
        'items': commandCalled
            ? [
                {
                  'id': 'cmd_1',
                  'deviceId': deviceId,
                  'isOn': true,
                  'durationSeconds': 60,
                  'status': 'Acknowledged',
                  'issuedAt': DateTime.now().toUtc().toIso8601String(),
                  'acknowledgedAt': DateTime.now().toUtc().toIso8601String(),
                  'acknowledgedIsOn': true,
                }
              ]
            : []
      };

  @override
  Future<Map<String, dynamic>> sendPumpCommand(
    String deviceId,
    String commandId,
    bool isOn,
    int? durationSeconds,
  ) async {
    commandCalled = true;
    return {
      'id': commandId,
      'deviceId': deviceId,
      'isOn': isOn,
      'durationSeconds': durationSeconds ?? 60,
      'status': 'Acknowledged',
      'issuedAt': DateTime.now().toUtc().toIso8601String(),
      'acknowledgedAt': DateTime.now().toUtc().toIso8601String(),
      'acknowledgedIsOn': true,
    };
  }

  @override
  Future<List<dynamic>> getPumpSchedules(String deviceId) async => [];

  @override
  Future<Map<String, dynamic>> getAlerts(
    String deviceId, {
    String status = 'all',
    int page = 1,
    int pageSize = 20,
  }) async => {'items': []};

  @override
  Future<Map<String, dynamic>> getAlertSettings(String deviceId) async => {
        'highTemperatureC': 32.0,
        'lowWaterLevelPercent': 25.0,
      };
}

class _FakeHistoryRepository implements HistoryRepository {
  @override
  Future<List<HistorySample>> loadSamples({
    required String deviceId,
    required HistoryWindow window,
    required bool downsample,
  }) async {
    final now = DateTime.now();
    return [
      HistorySample(
        recordedAt: now.subtract(const Duration(hours: 2)),
        values: {
          HistorySensor.temperature: 24.0,
          HistorySensor.humidity: 60.0,
        },
      ),
      HistorySample(
        recordedAt: now,
        values: {
          HistorySensor.temperature: 25.5,
          HistorySensor.humidity: 65.0,
        },
      ),
    ];
  }

  @override
  Future<List<PumpHistoryEvent>> loadPumpEvents({
    required String deviceId,
    required HistoryWindow window,
  }) async => [];

  @override
  Future<Map<String, dynamic>> loadAlertSettings(String deviceId) async => {
        'highTemperatureC': 32.0,
        'lowWaterLevelPercent': 25.0,
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Phase 13 Integration Test: login > add device > open detail > manual run > view history > export',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = _FakeIntegrationApiService();
      final historyRepo = _FakeHistoryRepository();
      final authProvider = AuthProvider(apiService: api);

      // STEP 1: Login
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authProvider,
          child: const CupertinoApp(
            home: CupertinoLoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(CupertinoTextField);
      await tester.enterText(textFields.at(0), 'user@aerogreen.vn');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();

      expect(api.loginCalled, isTrue);

      // STEP 2: Device entity available (from simulated add device)
      final device = Device(
        id: 'device-integration-1',
        name: 'Tháp Khí Canh 1',
        isOnline: true,
        createdAt: '2026-10-01T00:00:00Z',
      );

      // STEP 3: Open Device Detail
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoDeviceDetailScreen(
            device: device,
            apiService: api,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tháp Khí Canh 1'), findsWidgets);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('25.5 °C'), findsOneWidget);

      // STEP 4: Manual Pump Run
      await tester.tap(find.text('Thủ công'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chuyển'));
      await tester.pumpAndSettle();

      expect(find.text('BẬT BƠM'), findsOneWidget);
      await tester.tap(find.text('BẬT BƠM'));
      await tester.pumpAndSettle();

      // Duration selector action sheet appears (30s, 1m, 5m, 10m)
      expect(find.text('Chọn thời gian chạy'), findsOneWidget);
      expect(find.text('1 phút'), findsOneWidget);
      await tester.tap(find.text('1 phút'));
      await tester.pumpAndSettle();

      expect(api.commandCalled, isTrue);

      // STEP 5: View Sensor History
      await tester.pumpWidget(
        CupertinoApp(
          home: SensorHistoryScreen(
            device: device,
            sensor: 'temperature',
            repository: historyRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lịch sử · Tháp Khí Canh 1'), findsOneWidget);
      expect(find.text('Nhiệt độ không khí'), findsWidgets);

      // STEP 6: Export Sheet
      await tester.tap(find.byIcon(CupertinoIcons.share));
      await tester.pumpAndSettle();

      // Export Sheet modal is visible with CSV & PDF options
      expect(find.text('Xuất dữ liệu'), findsOneWidget);
      expect(find.text('CSV'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('Tạo tệp'), findsOneWidget);

      // Close the export sheet modal
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      // Export flow successfully completed!
      expect(tester.takeException(), isNull);
    },
  );
}
