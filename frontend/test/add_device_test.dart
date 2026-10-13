import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotagri_app/cupertino/devices/add_device_screen.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const CupertinoApp(home: AddDeviceScreen()));
  await tester.tap(find.text('Tiếp tục'));
  await tester.pump();
}

Future<void> _wifi(WidgetTester tester) async {
  await tester.tap(find.text('Quét mã QR'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('prepare advances and back restores preparation', (tester) async {
    await _open(tester);
    expect(find.text('Quét mã QR'), findsOneWidget);
    await tester.tap(find.text('Quay lại'));
    await tester.pump();
    expect(find.text('Chuẩn bị thêm thiết bị'), findsOneWidget);
  });
  testWidgets('QR blocks repeated scan and advances to Wi-Fi', (tester) async {
    await _open(tester);
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
    await _open(tester);
    await tester.tap(find.text('Tìm thiết bị gần'));
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('ESP32-ABC123'));
    await tester.pump();
    expect(find.text('Wi-Fi Home'), findsOneWidget);
  });
  testWidgets('Wi-Fi validates before starting connection', (tester) async {
    await _open(tester);
    await _wifi(tester);
    await tester.tap(find.widgetWithText(CupertinoButton, 'Kết nối'));
    await tester.pump();
    expect(find.text('Vui lòng chọn mạng Wi-Fi'), findsOneWidget);
    await tester.tap(find.text('Wi-Fi Home'));
    await tester.tap(find.widgetWithText(CupertinoButton, 'Kết nối'));
    await tester.pump();
    expect(find.text('Vui lòng nhập mật khẩu Wi-Fi'), findsOneWidget);
  });
  testWidgets(
    'connection timeout exposes reset instructions and permits retry',
    (tester) async {
      await _open(tester);
      await _wifi(tester);
      await tester.tap(find.text('Wi-Fi Home'));
      await tester.enterText(find.byType(CupertinoTextField), 'fixture-wifi');
      await tester.tap(find.widgetWithText(CupertinoButton, 'Kết nối'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 60));
      expect(
        find.text('Timeout. Vui lòng reset thiết bị và thử lại.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Thử lại'));
      await tester.pump();
      expect(find.text('Wi-Fi Home'), findsOneWidget);
    },
  );
  testWidgets(
    'regression: valid Wi-Fi must progress through existing simulation to naming',
    (tester) async {
      await _open(tester);
      await _wifi(tester);
      await tester.tap(find.text('Wi-Fi Home'));
      await tester.enterText(find.byType(CupertinoTextField), 'fixture-wifi');
      await tester.tap(find.widgetWithText(CupertinoButton, 'Kết nối'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      // This fails on the original code: the action does not start its existing simulation.
      // No save/API request is made here.
      expect(find.text('Đặt tên thiết bị'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
