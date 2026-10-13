@TestOn('browser')
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotagri_app/cupertino/devices/add_device_screen.dart';

void main() {
  testWidgets('web setup avoids dart:io and only offers claim code', (
    tester,
  ) async {
    await tester.pumpWidget(const CupertinoApp(home: AddDeviceScreen()));

    await tester.tap(find.text('Tiếp tục'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Nhập mã cấp thiết bị'), findsOneWidget);
    expect(find.text('Tìm thiết bị gần'), findsNothing);
  });
}
