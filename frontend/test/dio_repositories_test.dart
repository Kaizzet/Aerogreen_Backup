import 'package:flutter_test/flutter_test.dart';
import 'package:iotagri_app/repositories/dio_client.dart';
import 'package:iotagri_app/repositories/impl/dio_support_ticket_repository_impl.dart';
import 'package:iotagri_app/services/api_service.dart';
import 'package:iotagri_app/services/realtime_client.dart';

class _FakeRepoApiService extends ApiService {
  @override
  Future<List<Map<String, dynamic>>> getMyTickets({String? status}) async => [
        {
          'id': 'ticket-dio-1',
          'subject': 'Cần hiệu chuẩn cảm biến TDS',
          'category': 'Cảm biến',
          'status': 'open',
          'priority': 'medium',
          'createdAt': '2026-10-09T10:00:00Z',
          'messagesCount': 1,
        }
      ];

  @override
  Future<Map<String, dynamic>> createSupportTicket(
    String subject,
    String message, {
    String? category,
    String? deviceId,
    String? deviceName,
    String? firmwareVersion,
  }) async => {
        'id': 'ticket-created',
        'subject': subject,
        'category': category ?? 'Kỹ thuật',
        'status': 'open',
        'priority': 'medium',
        'deviceId': deviceId,
        'deviceName': deviceName,
        'firmwareVersion': firmwareVersion,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'messagesCount': 1,
        'messages': [
          {
            'id': 'm1',
            'authorUserId': 'u1',
            'authorName': 'Bạn',
            'isStaff': false,
            'body': message,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
          }
        ],
      };
}

void main() {
  group('Phase 13: Dio Repositories Unit Tests', () {
    test('DioSupportTicketRepositoryImpl fetches and maps tickets correctly', () async {
      final fakeApi = _FakeRepoApiService();
      final repo = DioSupportTicketRepositoryImpl(apiService: fakeApi);

      final tickets = await repo.getMyTickets();
      expect(tickets.length, 1);
      expect(tickets.first.id, 'ticket-dio-1');
      expect(tickets.first.subject, 'Cần hiệu chuẩn cảm biến TDS');
      expect(tickets.first.category, 'Cảm biến');
      expect(tickets.first.isOpen, isTrue);

      final created = await repo.createSupportTicket(
        subject: 'Cảm biến nhiệt độ hỏng',
        message: 'Đèn LED báo đỏ liên tục',
        category: 'Phần cứng & Thiết bị',
        deviceId: 'dev-1',
      );
      expect(created.id, 'ticket-created');
      expect(created.subject, 'Cảm biến nhiệt độ hỏng');
      expect(created.deviceId, 'dev-1');
    });

    test('DioClient initializes with standardized options and interceptor', () {
      final client = DioClient();
      expect(client.dio.options.headers['Content-Type'], 'application/json');
      expect(client.dio.options.headers['Accept'], 'application/json');
      expect(client.dio.interceptors.isNotEmpty, isTrue);
    });
  });

  group('Phase 13: RealtimeClient (MQTT / WebSocket Stub)', () {
    test('Connect, subscribe, and route incoming telemetry messages', () async {
      final client = RealtimeClient();

      expect(client.state, RealtimeConnectionState.disconnected);

      await client.connect();
      expect(client.state, RealtimeConnectionState.connected);

      client.subscribeDevice('tower-01');

      // Listen to sensor telemetry stream
      final readingsFuture = client.sensorReadingsStream.first;
      client.handleIncomingMessage('devices/tower-01/readings', {
        'temperature': 25.5,
        'humidity': 65.0,
      });

      final receivedReadings = await readingsFuture;
      expect(receivedReadings['temperature'], 25.5);
      expect(receivedReadings['humidity'], 65.0);

      // Listen to pump status stream
      final pumpStatusFuture = client.pumpStatusStream.first;
      client.handleIncomingMessage('devices/tower-01/pump-status', {
        'isOn': true,
        'remainingSeconds': 45,
      });

      final receivedPumpStatus = await pumpStatusFuture;
      expect(receivedPumpStatus['isOn'], isTrue);
      expect(receivedPumpStatus['remainingSeconds'], 45);

      client.disconnect();
      expect(client.state, RealtimeConnectionState.disconnected);
      client.dispose();
    });

    test('Schedule reconnect enters reconnecting state', () {
      final client = RealtimeClient();
      client.scheduleReconnect();
      expect(client.state, RealtimeConnectionState.reconnecting);
      client.dispose();
    });
  });
}
