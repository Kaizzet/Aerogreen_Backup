import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotagri_app/cupertino/devices/cupertino_device_detail_screen.dart';
import 'package:iotagri_app/models/device.dart';
import 'package:iotagri_app/services/api_service.dart';

class _FakeSettingsApiService extends ApiService {
  Device device;
  bool deleteCalled = false;
  String? updatedName;

  _FakeSettingsApiService(this.device);

  @override
  Future<Map<String, dynamic>> getDevice(String id) async => device.toJson();

  @override
  Future<List<dynamic>> getDeviceReadings(String deviceId, {int? limit}) async => [];

  @override
  Future<Map<String, dynamic>> getPumpCommands(
    String deviceId, {
    int page = 1,
    int pageSize = 20,
    int? rangeHours,
  }) async => {'items': []};

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
        'highTemperatureC': 32.5,
        'lowWaterLevelPercent': 25.0,
      };

  @override
  Future<Map<String, dynamic>> updateAlertSettings(
    String deviceId, {
    double? highTemperatureC,
    double? lowWaterLevelPercent,
  }) async => {
        'highTemperatureC': highTemperatureC,
        'lowWaterLevelPercent': lowWaterLevelPercent,
      };

  @override
  Future<Map<String, dynamic>> updateDevice(String id, String name) async {
    updatedName = name;
    device = Device(
      id: device.id,
      name: name,
      isOnline: device.isOnline,
      createdAt: device.createdAt,
    );
    return device.toJson();
  }

  @override
  Future<void> deleteDevice(String id) async {
    deleteCalled = true;
  }
}

void main() {
  group('Phase 10: Device Settings flow', () {
    testWidgets('displays device info (model, firmware, serial, Wi-Fi signal)', (
      WidgetTester tester,
    ) async {
      final initialDevice = Device(
        id: 'dev-12345-6789',
        name: 'Tháp Rau 1',
        isOnline: true,
        createdAt: '2026-10-01T00:00:00Z',
      );
      final apiService = _FakeSettingsApiService(initialDevice);

      await tester.pumpWidget(
        CupertinoApp(
          home: DeviceSettingsScreen(
            device: initialDevice,
            apiService: apiService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thông tin thiết bị'), findsOneWidget);
      expect(find.text('ESP32 Hydroponic Gateway'), findsOneWidget);
      expect(find.text('v1.2.0'), findsOneWidget);
      expect(find.text('AGRI-DEV12345'), findsOneWidget);
      expect(find.text('Tín hiệu Wi-Fi'), findsOneWidget);
      expect(find.text('Tốt (-65 dBm)'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.wifi), findsOneWidget);
    });

    testWidgets('offline device shows offline Wi-Fi signal info', (
      WidgetTester tester,
    ) async {
      final offlineDevice = Device(
        id: 'dev-offline-99',
        name: 'Tháp Rau Offline',
        isOnline: false,
        createdAt: '2026-10-01T00:00:00Z',
      );
      final apiService = _FakeSettingsApiService(offlineDevice);

      await tester.pumpWidget(
        CupertinoApp(
          home: DeviceSettingsScreen(
            device: offlineDevice,
            apiService: apiService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Không có tín hiệu'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.wifi_slash), findsOneWidget);
    });

    testWidgets('rename device prefilled dialog, validation, and update', (
      WidgetTester tester,
    ) async {
      final initialDevice = Device(
        id: 'dev-1',
        name: 'Tháp 1',
        isOnline: true,
        createdAt: '2026-10-01T00:00:00Z',
      );
      final apiService = _FakeSettingsApiService(initialDevice);

      await tester.pumpWidget(
        CupertinoApp(
          home: DeviceSettingsScreen(
            device: initialDevice,
            apiService: apiService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tháp 1'), findsOneWidget);

      // Tap Rename button
      await tester.tap(find.text('Đổi tên'));
      await tester.pumpAndSettle();

      // Dialog is open and prefilled
      expect(find.text('Đổi tên thiết bị'), findsOneWidget);
      final dialogTextField = find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.byType(CupertinoTextField),
      );
      expect(dialogTextField, findsOneWidget);

      // Validation test: clear text and hit Lưu
      await tester.enterText(dialogTextField, '   ');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(find.text('Tên thiết bị không được để trống'), findsOneWidget);

      // Valid text and submit
      await tester.enterText(dialogTextField, 'Tháp Rau Xà Lách');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(apiService.updatedName, 'Tháp Rau Xà Lách');
      expect(find.text('Tháp Rau Xà Lách'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('remove device flow with destructive button and warning text', (
      WidgetTester tester,
    ) async {
      final initialDevice = Device(
        id: 'dev-to-delete',
        name: 'Thiết bị cũ',
        isOnline: true,
        createdAt: '2026-10-01T00:00:00Z',
      );
      final apiService = _FakeSettingsApiService(initialDevice);

      await tester.pumpWidget(
        CupertinoApp(
          home: DeviceSettingsScreen(
            device: initialDevice,
            apiService: apiService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Remove button at bottom by dragging ListView
      final removeBtn = find.text('Xóa thiết bị');
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(removeBtn, findsOneWidget);

      // Tap remove button
      await tester.tap(removeBtn);
      await tester.pumpAndSettle();

      // Warning text matching spec
      const warningMessage =
          'Thiết bị sẽ được đặt lại và ngừng báo cáo. Lịch phun đã lưu có thể dừng. Hãy chắc chắn cây đã được chăm sóc.';
      expect(find.text(warningMessage), findsOneWidget);

      // Cancel first
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(apiService.deleteCalled, isFalse);

      // Tap remove and confirm
      await tester.tap(removeBtn);
      await tester.pumpAndSettle();

      // In the alert dialog, tap the destructive 'Xóa thiết bị' action
      final dialogDeleteAction = find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('Xóa thiết bị'),
      );
      await tester.tap(dialogDeleteAction);
      await tester.pumpAndSettle();

      expect(apiService.deleteCalled, isTrue);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('remove device from detail screen pops back to devices screen with toast', (
      WidgetTester tester,
    ) async {
      final initialDevice = Device(
        id: 'dev-flow-1',
        name: 'Tháp Kiểm Tra',
        isOnline: true,
        createdAt: '2026-10-01T00:00:00Z',
      );
      final apiService = _FakeSettingsApiService(initialDevice);

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => CupertinoButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    CupertinoPageRoute<void>(
                      builder: (_) => CupertinoDeviceDetailScreen(
                        device: initialDevice,
                        apiService: apiService,
                      ),
                    ),
                  );
                },
                child: const Text('Mở chi tiết'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open detail screen
      await tester.tap(find.text('Mở chi tiết'));
      await tester.pumpAndSettle();
      expect(find.text('Tháp Kiểm Tra'), findsWidgets);

      // Tap settings button (gear icon)
      await tester.tap(find.byIcon(CupertinoIcons.settings));
      await tester.pumpAndSettle();
      expect(find.text('Cài đặt thiết bị'), findsOneWidget);

      // Scroll to remove button and tap
      final removeBtn = find.text('Xóa thiết bị');
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(removeBtn);
      await tester.pumpAndSettle();

      // Confirm in dialog
      final dialogDeleteAction = find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('Xóa thiết bị'),
      );
      await tester.tap(dialogDeleteAction);
      await tester.pumpAndSettle();

      // Wait for toast to appear
      await tester.pump(const Duration(milliseconds: 500));

      // Should be back to the devices screen (Mở chi tiết)
      expect(find.text('Mở chi tiết'), findsOneWidget);
      expect(find.text('Cài đặt thiết bị'), findsNothing);
      expect(find.text('Đã xóa thiết bị thành công'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });
  });
}
