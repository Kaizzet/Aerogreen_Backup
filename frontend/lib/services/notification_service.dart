import 'dart:async';

import '../models/device.dart';
import '../models/device_alert.dart';

class NotificationMessage {
  const NotificationMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.level,
    this.device,
    this.sensor,
    this.isResolved = false,
    this.isStillActive = false,
  });

  final String id;
  final String title;
  final String body;
  final AlertLevel level;
  final Device? device;
  final String? sensor;
  final bool isResolved;
  final bool isStillActive;
}

abstract interface class NotificationService {
  Stream<NotificationMessage> get foregroundMessages;
  Stream<NotificationMessage> get taps;

  Future<bool> requestPermission();

  Future<void> show(
    NotificationMessage message, {
    bool systemNotification = true,
  });

  void open(NotificationMessage message);
  void dispose();
}

/// Development implementation used until Firebase Messaging and the native
/// local-notification adapter are configured by the host applications.
class FakeNotificationService implements NotificationService {
  final _foregroundController =
      StreamController<NotificationMessage>.broadcast();
  final _tapController = StreamController<NotificationMessage>.broadcast();
  final List<NotificationMessage> delivered = [];
  bool permissionGranted = false;

  @override
  Stream<NotificationMessage> get foregroundMessages =>
      _foregroundController.stream;

  @override
  Stream<NotificationMessage> get taps => _tapController.stream;

  @override
  Future<bool> requestPermission() async {
    permissionGranted = true;
    return true;
  }

  @override
  Future<void> show(
    NotificationMessage message, {
    bool systemNotification = true,
  }) async {
    delivered.add(message);
    _foregroundController.add(message);
  }

  @override
  void open(NotificationMessage message) => _tapController.add(message);

  @override
  void dispose() {
    _foregroundController.close();
    _tapController.close();
  }
}

class AlertDeliveryGate {
  AlertDeliveryGate({this.repeatInterval = const Duration(minutes: 30)});

  final Duration repeatInterval;
  final Map<String, DateTime> _lastDeliveredAt = {};

  bool shouldDeliver(String key, DateTime now) {
    final previous = _lastDeliveredAt[key];
    if (previous != null && now.difference(previous) < repeatInterval) {
      return false;
    }
    _lastDeliveredAt[key] = now;
    return true;
  }

  void clear(String key) => _lastDeliveredAt.remove(key);
}
