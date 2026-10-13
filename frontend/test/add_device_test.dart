import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotagri_app/cupertino/devices/add_device_screen.dart';
import 'package:iotagri_app/services/api_service.dart';

class _Api extends ApiService {
  final Completer<Map<String, dynamic>> result = Completer();
  final List<String> names = [];
  @override
  Future<Map<String, dynamic>> createDevice(String name) {
    names.add(name);
    return result.future;
  }
}

Future<void> _open(WidgetTester tester, _Api api) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(CupertinoApp(home: AddDeviceScreen(apiService: api)));
  await tester.tap(find.text('Tiếp tục'));
  await tester.pump();
}

Future<void> _wifi(WidgetTester tester) async {
  await tester.tap(find.text('Quét mã QR'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _name(WidgetTester tester) async {
  await _wifi(tester);
  await tester.tap(find.text('Wi-Fi Home'));
  await tester.enterText(find.byType(CupertinoTextField), 'fixture-wifi');
  await tester.tap(find.widgetWithText(CupertinoButton, 'Kết nối'));
  await tester.pump();
  // Advance the production timers in the widget fake clock, without real delay.
  await tester.pump(const Duration(seconds: 6));
}

void main() {
  testWidgets('prepare advances and back restores preparation', (tester) async {
    await _open(tester, _Api());
    expect(find.text('Quét mã QR'), findsOneWidget);
    await tester.tap(find.text('Quay lại'));
    await tester.pump();
    expect(find.text('Chuẩn bị thêm thiết bị'), findsOneWidget);
  });
  testWidgets('QR blocks repeated scan and advances to Wi-Fi', (tester) async {
    await _open(tester, _Api());
    await tester.tap(find.text('Quét mã QR'));
    await tester.pump();
    final button = tester.widget<CupertinoButton>(
      find
          .ancestor(
            of: find.text('Quét mã QR'),
            matching: find.byType(CupertinoButton),
          )
          .first,
    );
    expect(button.onPressed, isNull);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Wi-Fi Home'), findsOneWidget);
  });
  testWidgets('BLE simulation discovers devices and selection advances', (
    tester,
  ) async {
    await _open(tester, _Api());
    await tester.tap(find.text('Tìm thiết bị gần'));
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('ESP32-ABC123'));
    await tester.pump();
    expect(find.text('Wi-Fi Home'), findsOneWidget);
  });
  testWidgets('Wi-Fi requires network and nonempty credential', (tester) async {
    final api = _Api();
    await _open(tester, api);
    await _wifi(tester);
    await tester.tap(find.widgetWithText(CupertinoButton, 'Kết nối'));
    await tester.pump();
    expect(find.text('Vui lòng chọn mạng Wi-Fi'), findsOneWidget);
    await tester.tap(find.text('Wi-Fi Home'));
    await tester.tap(find.widgetWithText(CupertinoButton, 'Kết nối'));
    await tester.pump();
    expect(find.text('Vui lòng nhập mật khẩu Wi-Fi'), findsOneWidget);
    expect(api.names, isEmpty);
  });
  testWidgets('name required before API request', (tester) async {
    final api = _Api();
    await _open(tester, api);
    await _name(tester);
    await tester.enterText(find.byType(CupertinoTextField).first, '');
    await tester.tap(find.text('Lưu thiết bị'));
    await tester.pump();
    expect(find.text('Vui lòng nhập tên thiết bị'), findsOneWidget);
    expect(api.names, isEmpty);
  });
  testWidgets('save blocks duplicate submission and displays returned device', (
    tester,
  ) async {
    final api = _Api();
    await _open(tester, api);
    await _name(tester);
    await tester.enterText(
      find.byType(CupertinoTextField).first,
      'Fixture tower',
    );
    await tester.tap(find.text('Lưu thiết bị'));
    await tester.pump();
    expect(api.names, ['Fixture tower']);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    api.result.complete({
      'id': 'fixture-device',
      'name': 'Fixture tower',
      'isOnline': true,
      'createdAt': '2030-01-01T00:00:00Z',
    });
    await tester.pump();
    expect(find.text('Fixture tower đã online'), findsOneWidget);
    expect(find.text('Cài lịch phun'), findsOneWidget);
    expect(find.text('Mở thiết bị'), findsOneWidget);
  });
  for (final error in [
    Exception('already claimed'),
    TimeoutException('fixture timeout'),
    Exception('fixture API unavailable'),
  ]) {
    testWidgets(
      'save surfaces ${error.runtimeType}: $error and enables retry',
      (tester) async {
        final api = _Api();
        await _open(tester, api);
        await _name(tester);
        await tester.tap(find.text('Lưu thiết bị'));
        await tester.pump();
        api.result.completeError(error);
        await tester.pump();
        expect(
          find.text(
            error.toString().contains('already claimed')
                ? 'Thiết bị này đã được đăng ký. Liên hệ hỗ trợ.'
                : error.toString(),
          ),
          findsOneWidget,
        );
        final button = tester.widget<CupertinoButton>(
          find
              .ancestor(
                of: find.text('Lưu thiết bị'),
                matching: find.byType(CupertinoButton),
              )
              .first,
        );
        expect(button.onPressed, isNotNull);
        expect(api.names.length, 1);
      },
    );
  }
}
