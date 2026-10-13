import 'dart:async';
import 'dart:math';

enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class RealtimeMessage {
  final String topic;
  final Map<String, dynamic> payload;
  final DateTime receivedAt;

  const RealtimeMessage({
    required this.topic,
    required this.payload,
    required this.receivedAt,
  });
}

class RealtimeClient {
  final String serverUrl;
  final String? clientToken;

  RealtimeConnectionState _state = RealtimeConnectionState.disconnected;
  final Set<String> _subscriptions = {};

  final _stateController = StreamController<RealtimeConnectionState>.broadcast();
  final _messageController = StreamController<RealtimeMessage>.broadcast();
  final _sensorReadingsController = StreamController<Map<String, dynamic>>.broadcast();
  final _pumpStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _alertController = StreamController<Map<String, dynamic>>.broadcast();

  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;

  RealtimeConnectionState get state => _state;
  Stream<RealtimeConnectionState> get stateStream => _stateController.stream;
  Stream<RealtimeMessage> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get sensorReadingsStream => _sensorReadingsController.stream;
  Stream<Map<String, dynamic>> get pumpStatusStream => _pumpStatusController.stream;
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;

  RealtimeClient({
    this.serverUrl = 'wss://api.aerogreen.vn/mqtt',
    this.clientToken,
  });

  Future<void> connect() async {
    if (_state == RealtimeConnectionState.connected ||
        _state == RealtimeConnectionState.connecting) {
      return;
    }

    _setState(RealtimeConnectionState.connecting);

    // Simulate connection delay
    await Future.delayed(const Duration(milliseconds: 300));
    _setState(RealtimeConnectionState.connected);
    _reconnectAttempts = 0;

    _startHeartbeat();
  }

  void _setState(RealtimeConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      // Keepalive ping
    });
  }

  void subscribe(String topic) {
    _subscriptions.add(topic);
  }

  void unsubscribe(String topic) {
    _subscriptions.remove(topic);
  }

  void subscribeDevice(String deviceId) {
    subscribe('devices/$deviceId/readings');
    subscribe('devices/$deviceId/pump-status');
    subscribe('devices/$deviceId/alerts');
  }

  void unsubscribeDevice(String deviceId) {
    unsubscribe('devices/$deviceId/readings');
    unsubscribe('devices/$deviceId/pump-status');
    unsubscribe('devices/$deviceId/alerts');
  }

  Future<void> publish(String topic, Map<String, dynamic> payload) async {
    if (_state != RealtimeConnectionState.connected) {
      throw StateError('Cannot publish message while not connected: $_state');
    }
    // Stub publish implementation
    await Future.delayed(const Duration(milliseconds: 50));
  }

  /// Injects incoming simulated or test message
  void handleIncomingMessage(String topic, Map<String, dynamic> payload) {
    final msg = RealtimeMessage(
      topic: topic,
      payload: payload,
      receivedAt: DateTime.now(),
    );
    _messageController.add(msg);

    if (topic.endsWith('/readings')) {
      _sensorReadingsController.add(payload);
    } else if (topic.endsWith('/pump-status')) {
      _pumpStatusController.add(payload);
    } else if (topic.endsWith('/alerts')) {
      _alertController.add(payload);
    }
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _setState(RealtimeConnectionState.disconnected);
  }

  void scheduleReconnect() {
    _heartbeatTimer?.cancel();
    _setState(RealtimeConnectionState.reconnecting);
    _reconnectAttempts++;

    final backoffSeconds = min(60, pow(2, _reconnectAttempts).toInt());
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: backoffSeconds), () {
      connect();
    });
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _messageController.close();
    _sensorReadingsController.close();
    _pumpStatusController.close();
    _alertController.close();
  }
}
