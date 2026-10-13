import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/device.dart';
import '../models/device_alert.dart';
import '../services/api_service.dart';
import '../services/notification_preferences_store.dart';
import '../services/notification_service.dart';

enum AlertListFilter { all, critical, unread }

class AlertItem {
  const AlertItem({required this.alert, required this.device});

  final DeviceAlert alert;
  final Device device;
}

abstract interface class AlertRepository {
  Future<List<DeviceAlert>> loadAlerts(Device device);
  Future<Map<String, dynamic>> loadSettings(String deviceId);
  Future<Map<String, dynamic>> saveSettings(
    String deviceId, {
    double? highTemperatureC,
    double? lowWaterLevelPercent,
  });
}

class ApiAlertRepository implements AlertRepository {
  ApiAlertRepository([ApiService? apiService])
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  @override
  Future<List<DeviceAlert>> loadAlerts(Device device) async {
    final data = await _apiService.getAlerts(
      device.id,
      status: 'all',
      pageSize: 100,
    );
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .map(
          (item) => DeviceAlert.fromJson(
            item as Map<String, dynamic>,
            deviceId: device.id,
          ),
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>> loadSettings(String deviceId) =>
      _apiService.getAlertSettings(deviceId);

  @override
  Future<Map<String, dynamic>> saveSettings(
    String deviceId, {
    double? highTemperatureC,
    double? lowWaterLevelPercent,
  }) => _apiService.updateAlertSettings(
    deviceId,
    highTemperatureC: highTemperatureC,
    lowWaterLevelPercent: lowWaterLevelPercent,
  );
}

abstract interface class AlertReadStore {
  Future<Set<String>> loadReadIds();
  Future<void> saveReadIds(Set<String> ids);
}

class SharedPreferencesAlertReadStore implements AlertReadStore {
  static const _key = 'alert_read_ids_v1';

  @override
  Future<Set<String>> loadReadIds() async =>
      (await SharedPreferences.getInstance()).getStringList(_key)?.toSet() ??
      <String>{};

  @override
  Future<void> saveReadIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, ids.toList()..sort());
  }
}

class AlertCenterProvider extends ChangeNotifier {
  AlertCenterProvider({
    AlertRepository? repository,
    AlertReadStore? readStore,
    required NotificationService notificationService,
    AlertDeliveryGate? deliveryGate,
    NotificationPreferencesStore? preferencesStore,
  }) : _repository = repository ?? ApiAlertRepository(),
       _readStore = readStore ?? SharedPreferencesAlertReadStore(),
       _notificationService = notificationService,
       _deliveryGate = deliveryGate ?? AlertDeliveryGate(),
       _preferencesStore = preferencesStore ?? NotificationPreferencesStore();

  final AlertRepository _repository;
  final AlertReadStore _readStore;
  final NotificationService _notificationService;
  final AlertDeliveryGate _deliveryGate;
  final NotificationPreferencesStore _preferencesStore;

  List<AlertItem> _items = const [];
  Set<String> _readIds = <String>{};
  bool _readIdsLoaded = false;
  bool _hasLoadedOnce = false;
  bool _isLoading = false;
  String? _errorMessage;
  AlertListFilter _filter = AlertListFilter.all;

  List<AlertItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AlertListFilter get filter => _filter;
  int get unreadCount =>
      _items.where((item) => !_readIds.contains(item.alert.id)).length;

  List<AlertItem> get filteredItems => switch (_filter) {
    AlertListFilter.all => _items,
    AlertListFilter.critical =>
      _items
          .where((item) => item.alert.severity == AlertLevel.critical)
          .toList(),
    AlertListFilter.unread =>
      _items.where((item) => !_readIds.contains(item.alert.id)).toList(),
  };

  bool isRead(String alertId) => _readIds.contains(alertId);

  void setFilter(AlertListFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  Future<void> loadDevices(
    List<Device> devices, {
    bool replaceAll = true,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (!_readIdsLoaded) {
        _readIds = await _readStore.loadReadIds();
        _readIdsLoaded = true;
      }
      final previous = {for (final item in _items) item.alert.id: item};
      final groups = await Future.wait(
        devices.map((device) async {
          final alerts = await _repository.loadAlerts(device);
          return [
            for (final alert in alerts) AlertItem(alert: alert, device: device),
          ];
        }),
      );
      final loaded = groups.expand((items) => items).toList();
      final requestedDeviceIds = devices.map((device) => device.id).toSet();
      final next = <AlertItem>[
        if (!replaceAll)
          ..._items.where(
            (item) => !requestedDeviceIds.contains(item.device.id),
          ),
        ...loaded,
      ]..sort((a, b) => b.alert.triggeredAt.compareTo(a.alert.triggeredAt));
      _items = next;
      if (_hasLoadedOnce) await _deliverChanges(previous, next);
      _hasLoadedOnce = true;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestPermission() => _notificationService.requestPermission();

  Future<void> markRead(String alertId) async {
    if (!_readIds.add(alertId)) return;
    notifyListeners();
    await _readStore.saveReadIds(_readIds);
  }

  Future<void> markAllRead() async {
    _readIds.addAll(_items.map((item) => item.alert.id));
    notifyListeners();
    await _readStore.saveReadIds(_readIds);
  }

  Future<void> _deliverChanges(
    Map<String, AlertItem> previous,
    List<AlertItem> next,
  ) async {
    final now = DateTime.now();
    final preferences = await _preferencesStore.load();
    for (final item in next) {
      final old = previous[item.alert.id];
      final active = item.alert.resolvedAt == null;
      if (old == null && active) {
        if (!preferences.allows(item.alert.severity, now)) continue;
        final key = '${item.device.id}:${item.alert.type}';
        final deliverSystem = _deliveryGate.shouldDeliver(key, now);
        await _notificationService.show(
          NotificationMessage(
            id: item.alert.id,
            title: deliverSystem ? item.alert.title : 'Vẫn đang xảy ra',
            body: item.alert.message,
            level: item.alert.severity,
            device: item.device,
            sensor: item.alert.sensorKey,
            isStillActive: !deliverSystem,
          ),
          systemNotification: deliverSystem,
        );
      } else if (old?.alert.resolvedAt == null &&
          item.alert.resolvedAt != null) {
        if (!preferences.allows(AlertLevel.info, now)) continue;
        final key = '${item.device.id}:${item.alert.type}';
        _deliveryGate.clear(key);
        await _notificationService.show(
          NotificationMessage(
            id: '${item.alert.id}:resolved',
            title: 'Đã khôi phục',
            body: '${item.device.name}: ${item.alert.title} đã được xử lý.',
            level: AlertLevel.info,
            device: item.device,
            sensor: item.alert.sensorKey,
            isResolved: true,
          ),
        );
      }
    }
  }
}
