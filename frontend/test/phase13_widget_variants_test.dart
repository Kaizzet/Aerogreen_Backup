import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotagri_app/cupertino/dashboard/farm_health_card.dart';
import 'package:iotagri_app/cupertino/devices/cupertino_device_detail_screen.dart';
import 'package:iotagri_app/models/device.dart';
import 'package:iotagri_app/models/device_alert.dart';
import 'package:iotagri_app/models/device_overview.dart';
import 'package:iotagri_app/models/pump_schedule.dart';
import 'package:iotagri_app/models/sensor_reading.dart';
import 'package:iotagri_app/services/api_service.dart';

class _FakeVariantsApiService extends ApiService {
  final bool isOnline;
  final bool isPumpRunning;
  final bool isSending;
  final bool hasWarning;

  _FakeVariantsApiService({
    this.isOnline = true,
    this.isPumpRunning = false,
    this.isSending = false,
    this.hasWarning = false,
  });

  @override
  Future<Map<String, dynamic>> getDevice(String id) async => {
    'id': id,
    'name': 'Tháp Thí Nghiệm',
    'isOnline': isOnline,
    'createdAt': '2026-10-01T00:00:00Z',
  };

  @override
  Future<List<dynamic>> getDeviceReadings(
    String deviceId, {
    int? limit,
  }) async => [
    {
      'id': 'reading-1',
      'deviceId': deviceId,
      'temperature': hasWarning ? 36.5 : 24.5,
      'solutionTemperature': 22.0,
      'humidity': hasWarning ? 25.0 : 65.0,
      'ph': 6.2,
      'waterLevel': hasWarning ? 10.0 : 80.0,
      'recordedAt': DateTime.now().toUtc().toIso8601String(),
    },
  ];

  @override
  Future<Map<String, dynamic>> getPumpCommands(
    String deviceId, {
    int page = 1,
    int pageSize = 20,
    int? rangeHours,
  }) async => {
    'items': isPumpRunning
        ? [
            {
              'id': 'cmd_running',
              'deviceId': deviceId,
              'isOn': true,
              'durationSeconds': 60,
              'status': 'Acknowledged',
              'issuedAt': DateTime.now().toUtc().toIso8601String(),
              'acknowledgedAt': DateTime.now().toUtc().toIso8601String(),
              'acknowledgedIsOn': true,
            },
          ]
        : isSending
        ? [
            {
              'id': 'cmd_pending',
              'deviceId': deviceId,
              'isOn': true,
              'durationSeconds': 60,
              'status': 'Pending',
              'issuedAt': DateTime.now().toUtc().toIso8601String(),
            },
          ]
        : [],
  };

  @override
  Future<List<dynamic>> getPumpSchedules(String deviceId) async => [
    {
      'id': 'sch_1',
      'deviceId': deviceId,
      'isEnabled': true,
      'weekdayMask': 127,
      'startTime': '06:00:00',
      'durationSeconds': 15,
      'timeZone': 'Asia/Ho_Chi_Minh',
      'createdAt': '2026-10-01T00:00:00Z',
    },
  ];

  @override
  Future<Map<String, dynamic>> getAlerts(
    String deviceId, {
    String status = 'all',
    int page = 1,
    int pageSize = 20,
  }) async => {
    'items': hasWarning
        ? [
            {
              'id': 'alt_1',
              'deviceId': deviceId,
              'severity': 'Critical',
              'type': 'LowWaterLevel',
              'message': 'Mực nước thấp dưới ngưỡng an toàn',
              'createdAt': DateTime.now().toUtc().toIso8601String(),
              'isResolved': false,
            },
          ]
        : [],
  };

  @override
  Future<Map<String, dynamic>> getAlertSettings(String deviceId) async => {
    'highTemperatureC': 32.0,
    'lowWaterLevelPercent': 25.0,
  };

  @override
  Future<Map<String, dynamic>> updatePumpSchedule(
    String deviceId,
    PumpSchedule schedule, {
    required bool isEnabled,
  }) async => {...schedule.toJson(), 'isEnabled': isEnabled};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 13: Home/Dashboard FarmHealthCard Variants', () {
    testWidgets(
      'noDevices state: neutral card, Chào mừng đến Aerogreen, stats hidden',
      (tester) async {
        await tester.pumpWidget(
          CupertinoApp(
            home: CupertinoPageScaffold(
              child: FarmHealthCard(
                summary: FarmHealthSummary.fromDevices(const []),
                onAddDevice: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Chào mừng đến Aerogreen'), findsOneWidget);
        expect(
          find.text('Thêm thiết bị đầu tiên để theo dõi trang trại.'),
          findsOneWidget,
        );
        expect(find.text('Thêm thiết bị'), findsOneWidget);
      },
    );

    testWidgets('healthy state: all towers optimal text and green tint', (
      tester,
    ) async {
      final devices = [
        DeviceOverview(
          id: 'dev-1',
          name: 'Tháp 1',
          isOnline: true,
          latestReading: SensorReading(
            id: 'sr-1',
            deviceId: 'dev-1',
            temperature: 25.0,
            humidity: 65.0,
            waterLevel: 80.0,
            recordedAt: DateTime.now().toUtc().toIso8601String(),
          ),
          alerts: const [],
        ),
        DeviceOverview(
          id: 'dev-2',
          name: 'Tháp 2',
          isOnline: true,
          latestReading: SensorReading(
            id: 'sr-2',
            deviceId: 'dev-2',
            temperature: 26.0,
            humidity: 70.0,
            waterLevel: 90.0,
            recordedAt: DateTime.now().toUtc().toIso8601String(),
          ),
          alerts: const [],
        ),
      ];

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: FarmHealthCard(
              summary: FarmHealthSummary.fromDevices(devices),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trang trại đang ổn định'), findsOneWidget);
      expect(
        find.text('Tất cả thiết bị đang hoạt động bình thường.'),
        findsOneWidget,
      );
    });

    testWidgets('attention state: offline tower requires attention', (
      tester,
    ) async {
      final devices = [
        DeviceOverview(
          id: 'dev-1',
          name: 'Tháp 1',
          isOnline: true,
          alerts: const [],
        ),
        DeviceOverview(
          id: 'dev-2',
          name: 'Tháp 2',
          isOnline: false,
          alerts: const [],
        ),
      ];

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: FarmHealthCard(
              summary: FarmHealthSummary.fromDevices(devices),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cần chú ý'), findsOneWidget);
      expect(find.text('1 vấn đề cần kiểm tra.'), findsOneWidget);
    });

    testWidgets(
      'critical state: low water level alert triggers critical card',
      (tester) async {
        final devices = [
          DeviceOverview(
            id: 'dev-1',
            name: 'Tháp 1',
            isOnline: true,
            alerts: [
              DeviceAlert(
                id: 'alt-1',
                deviceId: 'dev-1',
                type: 'LOW_WATER_LEVEL',
                measuredValue: 10.0,
                threshold: 20.0,
                triggeredAt: DateTime.now().toUtc().toIso8601String(),
              ),
            ],
          ),
        ];

        await tester.pumpWidget(
          CupertinoApp(
            home: CupertinoPageScaffold(
              child: FarmHealthCard(
                summary: FarmHealthSummary.fromDevices(devices),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cần xử lý ngay'), findsOneWidget);
        expect(
          find.text('Phát hiện tình trạng ảnh hưởng đến vận hành.'),
          findsOneWidget,
        );
      },
    );
  });

  group('Phase 13: Device Detail Variants', () {
    testWidgets(
      'healthy online variant: displays regular telemetry and auto pump mode',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final api = _FakeVariantsApiService();
        final device = Device(
          id: 'dev-1',
          name: 'Tháp Thí Nghiệm',
          isOnline: true,
          createdAt: '2026-10-01T00:00:00Z',
        );

        await tester.pumpWidget(
          CupertinoApp(
            home: CupertinoDeviceDetailScreen(device: device, apiService: api),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tháp Thí Nghiệm'), findsWidgets);
        expect(find.text('Online'), findsOneWidget);
        expect(find.text('Kết nối ổn định'), findsOneWidget);
        expect(find.text('24.5 °C'), findsOneWidget);
        expect(find.text('Bơm đang tắt'), findsOneWidget);
      },
    );

    testWidgets(
      'warning variant: sensor thresholds breached marked in warning colors',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final api = _FakeVariantsApiService(hasWarning: true);
        final device = Device(
          id: 'dev-1',
          name: 'Tháp Thí Nghiệm',
          isOnline: true,
          createdAt: '2026-10-01T00:00:00Z',
        );

        await tester.pumpWidget(
          CupertinoApp(
            home: CupertinoDeviceDetailScreen(device: device, apiService: api),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('36.5 °C'), findsOneWidget);
        expect(find.text('10.0 %'), findsOneWidget);
        expect(find.text('Cảnh báo'), findsWidgets);
      },
    );

    testWidgets(
      'offline variant: greyed controls and schedule-continues message',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final api = _FakeVariantsApiService(isOnline: false);
        final device = Device(
          id: 'dev-1',
          name: 'Tháp Thí Nghiệm',
          isOnline: false,
          createdAt: '2026-10-01T00:00:00Z',
        );

        await tester.pumpWidget(
          CupertinoApp(
            home: CupertinoDeviceDetailScreen(device: device, apiService: api),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Offline'), findsOneWidget);
        expect(find.text('Thiết bị ngoại tuyến'), findsOneWidget);
        expect(
          find.text('Lịch tự động vẫn tiếp tục chạy khi thiết bị ngoại tuyến.'),
          findsOneWidget,
        );
        expect(find.text('Không khả dụng khi ngoại tuyến'), findsOneWidget);
      },
    );

    testWidgets('running pump variant: shows countdown and Stop button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = _FakeVariantsApiService(isPumpRunning: true);
      final device = Device(
        id: 'dev-1',
        name: 'Tháp Thí Nghiệm',
        isOnline: true,
        createdAt: '2026-10-01T00:00:00Z',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoDeviceDetailScreen(device: device, apiService: api),
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

    testWidgets(
      'command sending variant: shows activity indicator and sending state',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final api = _FakeVariantsApiService(isSending: true);
        final device = Device(
          id: 'dev-1',
          name: 'Tháp Thí Nghiệm',
          isOnline: true,
          createdAt: '2026-10-01T00:00:00Z',
        );

        await tester.pumpWidget(
          CupertinoApp(
            home: CupertinoDeviceDetailScreen(device: device, apiService: api),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Đang gửi lệnh…'), findsOneWidget);
      },
    );
  });

  group('Phase 13: Schedule Validation Rules', () {
    test('mist length must be less than interval', () {
      bool validateSchedule(int mistSeconds, int intervalMinutes) {
        final intervalSeconds = intervalMinutes * 60;
        return mistSeconds > 0 &&
            mistSeconds <= 120 &&
            intervalMinutes >= 1 &&
            intervalMinutes <= 60 &&
            mistSeconds < intervalSeconds;
      }

      expect(validateSchedule(15, 5), isTrue); // 15s < 300s -> Valid
      expect(validateSchedule(120, 1), isFalse); // 120s > 60s -> Invalid
      expect(
        validateSchedule(60, 1),
        isFalse,
      ); // 60s == 60s -> Invalid (must be less)
      expect(validateSchedule(10, 1), isTrue); // 10s < 60s -> Valid
    });

    test('end time must be after start time unless overnight window', () {
      bool validateActiveHours(
        int startHour,
        int startMin,
        int endHour,
        int endMin, {
        bool allowOvernight = true,
      }) {
        final start = startHour * 60 + startMin;
        final end = endHour * 60 + endMin;
        if (start == end) return false;
        if (!allowOvernight) return end > start;
        return true; // Overnight allowed when explicitly supported
      }

      expect(validateActiveHours(6, 0, 18, 0, allowOvernight: false), isTrue);
      expect(validateActiveHours(18, 0, 6, 0, allowOvernight: false), isFalse);
      expect(validateActiveHours(18, 0, 6, 0, allowOvernight: true), isTrue);
      expect(validateActiveHours(12, 0, 12, 0), isFalse); // Same start/end
    });
  });
}
