import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotagri_app/cupertino/notifications/notification_banner_host.dart';
import 'package:iotagri_app/models/device.dart';
import 'package:iotagri_app/models/device_alert.dart';
import 'package:iotagri_app/models/notification_preferences.dart';
import 'package:iotagri_app/providers/alert_center_provider.dart';
import 'package:iotagri_app/services/notification_preferences_store.dart';
import 'package:iotagri_app/services/notification_service.dart';

void main() {
  final device = Device(
    id: 'device-1',
    name: 'Tháp 1',
    isOnline: true,
    createdAt: DateTime.utc(2026, 10, 8).toIso8601String(),
  );

  test('tracks unread alerts and filters critical alerts', () async {
    final repository = _FakeAlertRepository([
      _alert('a1', 'PUMP_FAULT'),
      _alert('a2', 'LOW_WATER_LEVEL'),
    ]);
    final readStore = _MemoryReadStore();
    final provider = AlertCenterProvider(
      repository: repository,
      readStore: readStore,
      notificationService: FakeNotificationService(),
    );

    await provider.loadDevices([device]);
    expect(provider.unreadCount, 2);

    provider.setFilter(AlertListFilter.critical);
    expect(provider.filteredItems.map((item) => item.alert.id), ['a1']);

    await provider.markRead('a1');
    expect(provider.unreadCount, 1);
    expect(readStore.ids, contains('a1'));
  });

  test('debounces repeated alert delivery within the interval', () {
    final gate = AlertDeliveryGate(repeatInterval: const Duration(minutes: 10));
    final now = DateTime.utc(2026, 10, 8, 9);

    expect(gate.shouldDeliver('device:temperature', now), isTrue);
    expect(
      gate.shouldDeliver(
        'device:temperature',
        now.add(const Duration(minutes: 5)),
      ),
      isFalse,
    );
    expect(
      gate.shouldDeliver(
        'device:temperature',
        now.add(const Duration(minutes: 11)),
      ),
      isTrue,
    );
  });

  test('quiet hours suppress non-critical alerts but allow critical ones', () {
    const preferences = NotificationPreferences(
      quietHoursEnabled: true,
      quietStartMinutes: 22 * 60,
      quietEndMinutes: 7 * 60,
    );
    final duringQuietHours = DateTime.utc(2026, 10, 8, 23);

    expect(preferences.allows(AlertLevel.warning, duringQuietHours), isFalse);
    expect(preferences.allows(AlertLevel.critical, duringQuietHours), isTrue);
  });

  test('delivers new, repeated, and resolved alert transitions', () async {
    final repository = _FakeAlertRepository([]);
    final notifications = FakeNotificationService();
    final provider = AlertCenterProvider(
      repository: repository,
      readStore: _MemoryReadStore(),
      notificationService: notifications,
      preferencesStore: _MemoryPreferencesStore(),
    );

    await provider.loadDevices([device]);

    repository.alerts.add(_alert('a1', 'HIGH_TEMPERATURE'));
    await provider.loadDevices([device]);
    expect(notifications.delivered.single.isStillActive, isFalse);

    repository.alerts.add(_alert('a2', 'HIGH_TEMPERATURE'));
    await provider.loadDevices([device]);
    expect(notifications.delivered.last.title, 'Vẫn đang xảy ra');
    expect(notifications.delivered.last.isStillActive, isTrue);

    repository.alerts[0] = _alert(
      'a1',
      'HIGH_TEMPERATURE',
      resolvedAt: DateTime.utc(2026, 10, 8, 10).toIso8601String(),
    );
    await provider.loadDevices([device]);
    expect(notifications.delivered.last.title, 'Đã khôi phục');
    expect(notifications.delivered.last.isResolved, isTrue);
  });

  test('targeted device refresh preserves alerts from other devices', () async {
    final otherDevice = Device(
      id: 'device-2',
      name: 'Tháp 2',
      isOnline: true,
      createdAt: DateTime.utc(2026, 10, 8).toIso8601String(),
    );
    final repository = _FakeAlertRepository([_alert('a1', 'PUMP_FAULT')]);
    final provider = AlertCenterProvider(
      repository: repository,
      readStore: _MemoryReadStore(),
      notificationService: FakeNotificationService(),
      preferencesStore: _MemoryPreferencesStore(),
    );

    await provider.loadDevices([device, otherDevice]);
    repository.alerts
      ..clear()
      ..add(_alert('a2', 'LOW_WATER_LEVEL'));
    await provider.loadDevices([device], replaceAll: false);

    expect(provider.items.map((item) => item.device.id).toSet(), {
      'device-1',
      'device-2',
    });
  });

  testWidgets('notification banner tap follows the tap deep link stream', (
    tester,
  ) async {
    final service = FakeNotificationService();
    NotificationMessage? opened;
    const message = NotificationMessage(
      id: 'n1',
      title: 'Nhiệt độ cao',
      body: 'Tháp 1 cần chú ý',
      level: AlertLevel.critical,
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: NotificationBannerHost(
          service: service,
          onOpen: (message) => opened = message,
          child: const CupertinoPageScaffold(child: SizedBox.expand()),
        ),
      ),
    );
    await service.show(message);
    await tester.pump();
    await tester.tap(find.text('Nhiệt độ cao'));
    await tester.pump();

    expect(opened, same(message));
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });
}

DeviceAlert _alert(String id, String type, {String? resolvedAt}) => DeviceAlert(
  id: id,
  deviceId: 'device-1',
  type: type,
  measuredValue: 40,
  threshold: 30,
  triggeredAt: DateTime.utc(2026, 10, 8, 9).toIso8601String(),
  resolvedAt: resolvedAt,
);

class _FakeAlertRepository implements AlertRepository {
  _FakeAlertRepository(this.alerts);

  final List<DeviceAlert> alerts;

  @override
  Future<List<DeviceAlert>> loadAlerts(Device device) async => alerts;

  @override
  Future<Map<String, dynamic>> loadSettings(String deviceId) async => {};

  @override
  Future<Map<String, dynamic>> saveSettings(
    String deviceId, {
    double? highTemperatureC,
    double? lowWaterLevelPercent,
  }) async => {};
}

class _MemoryReadStore implements AlertReadStore {
  Set<String> ids = {};

  @override
  Future<Set<String>> loadReadIds() async => {...ids};

  @override
  Future<void> saveReadIds(Set<String> ids) async => this.ids = {...ids};
}

class _MemoryPreferencesStore extends NotificationPreferencesStore {
  NotificationPreferences value = const NotificationPreferences();

  @override
  Future<NotificationPreferences> load() async => value;

  @override
  Future<void> save(NotificationPreferences value) async {
    this.value = value;
  }
}
