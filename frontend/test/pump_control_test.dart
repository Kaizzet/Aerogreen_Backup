import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotagri_app/cupertino/devices/cupertino_device_detail_screen.dart';
import 'package:iotagri_app/models/device.dart';
import 'package:iotagri_app/services/api_service.dart';

class _Api extends ApiService {
  bool online = true;
  double water = 80;
  final Completer<Map<String, dynamic>> result = Completer();
  final List<int?> durations = [];
  @override
  Future<Map<String, dynamic>> getDevice(String id) async => {
    'id': id,
    'name': 'Fixture tower',
    'isOnline': online,
    'createdAt': '2030-01-01',
  };
  @override
  Future<List<dynamic>> getDeviceReadings(String id, {int? limit}) async => [
    {
      'id': 'reading',
      'deviceId': id,
      'waterLevel': water,
      'recordedAt': '2030-01-01T00:00:00Z',
    },
  ];
  @override
  Future<Map<String, dynamic>> getPumpCommands(
    String id, {
    int page = 1,
    int pageSize = 20,
    int? rangeHours,
  }) async => {'items': []};
  @override
  Future<List<dynamic>> getPumpSchedules(String id) async => [];
  @override
  Future<Map<String, dynamic>> getAlerts(
    String id, {
    String status = 'active',
    int page = 1,
    int pageSize = 50,
  }) async => {'items': []};
  @override
  Future<Map<String, dynamic>> getAlertSettings(String id) async => {
    'lowWaterLevelPercent': 30,
  };
  @override
  Future<Map<String, dynamic>> sendPumpCommand(
    String id,
    String commandId,
    bool isOn,
    int? durationSeconds,
  ) {
    expect(id, 'fixture-device');
    expect(commandId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(isOn, isTrue);
    durations.add(durationSeconds);
    return result.future;
  }
}

Future<void> _open(WidgetTester tester, _Api api) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    CupertinoApp(
      home: CupertinoDeviceDetailScreen(
        device: Device(
          id: 'fixture-device',
          name: 'Fixture tower',
          isOnline: api.online,
          createdAt: '2030-01-01',
        ),
        apiService: api,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _manual(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Thủ công'));
  await tester.tap(find.text('Thủ công'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Chuyển'));
  await tester.pumpAndSettle();
}

void main() {
  for (final online in [true, false]) {
    for (final sending in [true, false]) {
      testWidgets('card gates commands online=$online sending=$sending', (
        tester,
      ) async {
        var calls = 0;
        await tester.pumpWidget(
          CupertinoApp(
            home: CupertinoPageScaffold(
              child: PumpControlCard(
                isOnline: online,
                isRunning: false,
                isSending: sending,
                pumpMode: PumpMode.manual,
                onManualToggle: () => calls++,
              ),
            ),
          ),
        );
        final button = find.byType(CupertinoButton).last;
        await tester.tap(button);
        expect(calls, online && !sending ? 1 : 0);
      });
    }
  }
  testWidgets('running card formats countdown and invokes stop', (
    tester,
  ) async {
    var stopped = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: PumpControlCard(
            isOnline: true,
            isRunning: true,
            isSending: false,
            remainingSeconds: 65,
            onStop: () => stopped++,
          ),
        ),
      ),
    );
    expect(find.textContaining('01:05'), findsOneWidget);
    await tester.tap(find.text('Dừng'));
    expect(stopped, 1);
  });
  for (final choice in {
    '30 giây': 30,
    '1 phút': 60,
    '5 phút': 300,
    '10 phút': 600,
  }.entries) {
    testWidgets(
      'manual duration ${choice.value} sends once and blocks pending commands',
      (tester) async {
        final api = _Api();
        await _open(tester, api);
        await _manual(tester);
        await tester.tap(find.text('BẬT BƠM'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(choice.key));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(api.durations, [choice.value]);
        expect(find.text('Đang gửi lệnh…'), findsWidgets);
        api.result.complete({});
        await tester.pump();
        await tester.pumpWidget(const CupertinoApp(home: SizedBox()));
      },
    );
  }
  testWidgets('low water prevents request and explains safety block', (
    tester,
  ) async {
    final api = _Api()..water = 10;
    await _open(tester, api);
    await _manual(tester);
    await tester.tap(find.text('BẬT BƠM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 giây'));
    await tester.pumpAndSettle();
    expect(api.durations, isEmpty);
    expect(
      find.text('Không thể bật bơm khi mực nước đang thấp.'),
      findsOneWidget,
    );
  });
  testWidgets('API error is displayed and sending flag is released', (
    tester,
  ) async {
    final api = _Api();
    await _open(tester, api);
    await _manual(tester);
    await tester.tap(find.text('BẬT BƠM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 giây'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    api.result.completeError(TimeoutException('fixture'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không thể gửi lệnh:'), findsOneWidget);
    expect(api.durations, [30]);
  });
}
