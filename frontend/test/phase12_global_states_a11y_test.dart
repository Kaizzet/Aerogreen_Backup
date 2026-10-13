import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotagri_app/cupertino/widgets/global_offline_banner.dart';
import 'package:iotagri_app/providers/app_settings_provider.dart';
import 'package:iotagri_app/services/connectivity_service.dart';
import 'package:iotagri_app/utils/l10n.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 12: Global OfflineBanner Tests', () {
    testWidgets('Offline banner displays when connectivity is offline', (tester) async {
      final connectivity = ConnectivityService();
      connectivity.setOfflineForTesting(true);

      await tester.pumpWidget(
        ChangeNotifierProvider<ConnectivityService>.value(
          value: connectivity,
          child: const CupertinoApp(
            home: GlobalOfflineBanner(
              child: CupertinoPageScaffold(
                child: Center(child: Text('Main Content')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Main Content'), findsOneWidget);
      expect(
        find.text('Bạn đang offline. Hiển thị dữ liệu gần nhất.'),
        findsOneWidget,
      );
      expect(find.byIcon(CupertinoIcons.wifi_slash), findsOneWidget);
    });

    testWidgets('Offline banner is hidden when online', (tester) async {
      final connectivity = ConnectivityService();
      connectivity.setOfflineForTesting(false);

      await tester.pumpWidget(
        ChangeNotifierProvider<ConnectivityService>.value(
          value: connectivity,
          child: const CupertinoApp(
            home: GlobalOfflineBanner(
              child: CupertinoPageScaffold(
                child: Center(child: Text('Main Content')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Main Content'), findsOneWidget);
      expect(
        find.text('Bạn đang offline. Hiển thị dữ liệu gần nhất.'),
        findsNothing,
      );
    });
  });

  group('Phase 12: Localization (vi + en) Audit', () {
    test('All localization keys exist in both Vietnamese and English dictionaries', () {
      final viKeys = [
        'app_name', 'save', 'cancel', 'confirm', 'ok', 'close', 'retry', 'error',
        'offline_banner', 'greeting', 'welcome_aerogreen', 'add_device',
        'farm_healthy', 'farm_attention', 'farm_critical', 'online_devices',
        'average_temp', 'average_humidity', 'device_detail', 'sensors',
        'pump_control', 'auto_mode', 'manual_mode', 'pump_running',
        'pump_stopped', 'sending_command', 'stop_pump', 'start_pump',
        'next_spray_in', 'no_schedule_active', 'schedule_continues_offline',
        'not_available_offline', 'account', 'personal_profile', 'change_password',
        'notification_prefs', 'customer_support', 'language', 'temperature_units',
        'theme', 'about_version', 'logout', 'logout_confirm', 'support_tickets',
        'create_ticket', 'all', 'open', 'in_progress', 'resolved', 'no_tickets',
        'send_reply',
      ];

      for (final key in viKeys) {
        final viText = AppL10n.get('vi', key);
        final enText = AppL10n.get('en', key);

        expect(viText, isNotEmpty, reason: 'Key "$key" is missing in Vietnamese');
        expect(enText, isNotEmpty, reason: 'Key "$key" is missing in English');
        expect(viText != enText || key == 'app_name' || key == 'ok', isTrue,
            reason: 'Key "$key" should have distinct translation');
      }
    });

    testWidgets('Context extension dynamically translates based on locale', (tester) async {
      final settings = AppSettingsProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppSettingsProvider>.value(
          value: settings,
          child: CupertinoApp(
            home: Builder(
              builder: (context) => CupertinoPageScaffold(
                child: Center(
                  child: Text(context.tr('welcome_aerogreen')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chào mừng đến Aerogreen'), findsOneWidget);

      await settings.setLocale(const Locale('en'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Aerogreen'), findsOneWidget);
    });
  });

  group('Phase 12: Accessibility and Scaling Audit', () {
    testWidgets('Text scaling at 1.5x does not cause overflow on banner', (tester) async {
      final connectivity = ConnectivityService();
      connectivity.setOfflineForTesting(true);

      await tester.pumpWidget(
        ChangeNotifierProvider<ConnectivityService>.value(
          value: connectivity,
          child: const CupertinoApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: GlobalOfflineBanner(
                child: CupertinoPageScaffold(
                  child: Center(child: Text('Content')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Bạn đang offline. Hiển thị dữ liệu gần nhất.'), findsOneWidget);
    });

    testWidgets('Offline banner includes Semantics label for screen readers', (tester) async {
      final connectivity = ConnectivityService();
      connectivity.setOfflineForTesting(true);

      await tester.pumpWidget(
        ChangeNotifierProvider<ConnectivityService>.value(
          value: connectivity,
          child: const CupertinoApp(
            home: GlobalOfflineBanner(
              child: CupertinoPageScaffold(child: SizedBox()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                'Cảnh báo mất kết nối mạng. Bạn đang offline. Hiển thị dữ liệu gần nhất.',
      );
      expect(semantics, findsOneWidget);
    });
  });
}
