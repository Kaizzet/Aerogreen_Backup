import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotagri_app/cupertino/profile/cupertino_change_password_screen.dart';
import 'package:iotagri_app/cupertino/profile/cupertino_profile_screen.dart';
import 'package:iotagri_app/cupertino/tickets/cupertino_create_ticket_screen.dart';
import 'package:iotagri_app/cupertino/tickets/cupertino_support_tickets_screen.dart';
import 'package:iotagri_app/cupertino/tickets/cupertino_ticket_detail_screen.dart';
import 'package:iotagri_app/models/device.dart';
import 'package:iotagri_app/models/support_ticket.dart';
import 'package:iotagri_app/providers/app_settings_provider.dart';
import 'package:iotagri_app/providers/auth_provider.dart';
import 'package:iotagri_app/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePhase11ApiService extends ApiService {
  bool changePasswordCalled = false;
  bool createTicketCalled = false;
  bool replyCalled = false;
  String? createdSubject;
  String? createdDeviceId;

  @override
  Future<Map<String, dynamic>> getProfile() async => {
        'id': 'user_1',
        'email': 'user@aerogreen.vn',
        'fullName': 'Nguyen Van A',
        'phoneNumber': '0901234567',
        'roles': ['User'],
      };

  @override
  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phoneNumber,
  }) async => {
        'id': 'user_1',
        'email': 'user@aerogreen.vn',
        'fullName': fullName ?? 'Nguyen Van A',
        'phoneNumber': phoneNumber ?? '0901234567',
        'roles': ['User'],
      };

  @override
  Future<bool> changePassword(
    String currentPassword,
    String newPassword, {
    bool logoutOtherDevices = false,
  }) async {
    changePasswordCalled = true;
    return true;
  }

  @override
  Future<List<dynamic>> getDevices() async => [
        {
          'id': 'device-001',
          'name': 'Tháp Rau 1',
          'isOnline': true,
          'createdAt': '2026-10-01T00:00:00Z',
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
  }) async {
    createTicketCalled = true;
    createdSubject = subject;
    createdDeviceId = deviceId;
    return {
      'id': 'ticket_999',
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
          'id': 'msg_1',
          'authorUserId': 'user_1',
          'authorName': 'Bạn',
          'isStaff': false,
          'body': message,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        }
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getMyTickets({String? status}) async => [
        {
          'id': 'ticket_1',
          'subject': 'Lỗi rò rỉ khớp nối bơm',
          'category': 'Phần cứng & Thiết bị',
          'status': 'open',
          'priority': 'high',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'lastMessage': 'Ống cấp nước bị rò ở chân tháp.',
          'messagesCount': 1,
        },
        {
          'id': 'ticket_2',
          'subject': 'Tư vấn nồng độ EC mùa nắng',
          'category': 'Kỹ thuật',
          'status': 'resolved',
          'priority': 'medium',
          'createdAt': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String(),
          'lastMessage': 'Đã hỗ trợ điều chỉnh nồng độ.',
          'messagesCount': 2,
        },
      ];

  @override
  Future<Map<String, dynamic>> getMyTicket(String id) async {
    if (id == 'ticket-1') {
      return {
        'id': 'ticket-1',
        'subject': 'Cần hướng dẫn pha dinh dưỡng',
        'category': 'Kỹ thuật',
        'status': 'open',
        'priority': 'medium',
        'createdAt': '2026-10-09T08:00:00Z',
        'messages': [
          {
            'id': 'm1',
            'authorUserId': 'u1',
            'authorName': 'Bạn',
            'isStaff': false,
            'body': 'Tỷ lệ A/B cho rau bina là bao nhiêu?',
            'createdAt': '2026-10-09T08:00:00Z',
          },
        ],
      };
    }
    return super.getMyTicket(id);
  }

  @override
  Future<Map<String, dynamic>> replyToMyTicket(String id, String message) async {
    replyCalled = true;
    return {
      'id': 'msg_new',
      'authorUserId': 'user_1',
      'authorName': 'Bạn',
      'isStaff': false,
      'body': message,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 11: Account Page & Settings Live Persistence', () {
    testWidgets('Account page renders all required rows', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = AuthProvider(apiService: _FakePhase11ApiService());
      final settingsProvider = AppSettingsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
          ],
          child: const CupertinoApp(
            home: CupertinoPageScaffold(
              child: CupertinoProfileScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tài khoản'), findsNWidgets(2));
      expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
      expect(find.text('Đổi mật khẩu'), findsOneWidget);
      expect(find.text('Tùy chọn thông báo'), findsOneWidget);
      expect(find.text('Hỗ trợ khách hàng'), findsOneWidget);
      expect(find.text('Ngôn ngữ'), findsOneWidget);
      expect(find.text('Đơn vị nhiệt độ'), findsOneWidget);
      expect(find.text('Giao diện'), findsOneWidget);
      expect(find.text('Phiên bản & Giới thiệu'), findsOneWidget);
      expect(find.text('Đăng xuất'), findsOneWidget);
    });

    test('AppSettingsProvider persists live updates to SharedPreferences', () async {
      final settings = AppSettingsProvider();
      await settings.setLocale(const Locale('en'));
      expect(settings.locale.languageCode, 'en');

      await settings.setTemperatureUnit(TemperatureUnit.fahrenheit);
      expect(settings.temperatureUnit, TemperatureUnit.fahrenheit);
      expect(settings.formatTemperature(0), 32);
      expect(settings.temperatureUnitString(), '°F');

      await settings.setThemeMode(AppThemeMode.dark);
      expect(settings.themeMode, AppThemeMode.dark);
    });
  });

  group('Phase 11: Change Password Screen', () {
    testWidgets('Strength meter updates dynamically and submission succeeds', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = _FakePhase11ApiService();
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoChangePasswordScreen(apiService: api),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(CupertinoTextField);
      expect(textFields, findsNWidgets(3));

      // 1. Enter weak password
      await tester.enterText(textFields.at(1), 'abc');
      await tester.pumpAndSettle();
      expect(find.textContaining('Yếu'), findsOneWidget);

      // 2. Enter strong password
      await tester.enterText(textFields.at(1), 'Aerogreen@2026Strong!');
      await tester.pumpAndSettle();
      expect(find.textContaining('Mạnh'), findsOneWidget);

      // 3. Fill current and confirmation password
      await tester.enterText(textFields.at(0), 'OldPassword123');
      await tester.enterText(textFields.at(2), 'Aerogreen@2026Strong!');
      await tester.pumpAndSettle();

      // 4. Submit
      await tester.tap(find.text('Xác nhận đổi mật khẩu'));
      await tester.pumpAndSettle();

      expect(api.changePasswordCalled, isTrue);
      expect(find.text('Thành công'), findsOneWidget);
    });
  });

  group('Phase 11: Support Flow', () {
    testWidgets('Support tickets list displays tickets and filter chips work', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = _FakePhase11ApiService();
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoSupportTicketsScreen(apiService: api),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hỗ trợ kỹ thuật'), findsOneWidget);
      expect(find.text('Lỗi rò rỉ khớp nối bơm'), findsOneWidget);
      expect(find.text('Tư vấn nồng độ EC mùa nắng'), findsOneWidget);

      // Filter to open tickets
      await tester.tap(find.text('Đang mở').first);
      await tester.pumpAndSettle();
      expect(find.text('Lỗi rò rỉ khớp nối bơm'), findsOneWidget);
    });

    testWidgets('Create ticket auto-attaches device information', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = _FakePhase11ApiService();
      final device = Device(
        id: 'device-001',
        name: 'Tháp Rau 1',
        isOnline: true,
        createdAt: '2026-10-01T00:00:00Z',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoCreateTicketScreen(
            apiService: api,
            preselectedDevice: device,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Tháp Rau 1 (device-001)'), findsOneWidget);
      expect(find.textContaining('Firmware: v1.0.4'), findsOneWidget);

      // Enter subject and description
      final textFields = find.byType(CupertinoTextField);
      await tester.enterText(textFields.at(0), 'Bơm không tự ngắt');
      await tester.enterText(textFields.at(1), 'Bơm chạy quá 120s không dừng.');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gửi yêu cầu hỗ trợ'));
      await tester.pumpAndSettle();

      expect(api.createTicketCalled, isTrue);
      expect(api.createdSubject, 'Bơm không tự ngắt');
      expect(api.createdDeviceId, 'device-001');
    });

    testWidgets('Ticket detail displays messages and allows replies', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = _FakePhase11ApiService();
      final ticket = SupportTicket(
        id: 'ticket-1',
        subject: 'Cần hướng dẫn pha dinh dưỡng',
        category: 'Kỹ thuật',
        status: 'open',
        createdAt: '2026-10-09T08:00:00Z',
        messages: const [
          SupportTicketMessage(
            id: 'm1',
            authorUserId: 'u1',
            authorName: 'Bạn',
            body: 'Tỷ lệ A/B cho rau bina là bao nhiêu?',
            createdAt: '2026-10-09T08:00:00Z',
          ),
        ],
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoTicketDetailScreen(
            initialTicket: ticket,
            apiService: api,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cần hướng dẫn pha dinh dưỡng'), findsOneWidget);
      expect(find.text('Tỷ lệ A/B cho rau bina là bao nhiêu?'), findsOneWidget);

      // Reply
      await tester.enterText(find.byType(CupertinoTextField), 'Tôi đã pha 5ml/L.');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(CupertinoIcons.arrow_up_circle_fill));
      await tester.pumpAndSettle();

      expect(api.replyCalled, isTrue);
      expect(find.text('Tôi đã pha 5ml/L.'), findsOneWidget);
    });
  });
}
