import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iotagri_app/data/models/user.dart';
import 'package:iotagri_app/data/repositories/auth_repository.dart';
import 'package:iotagri_app/providers/auth_controller.dart';
import 'package:iotagri_app/router.dart';
import 'package:iotagri_app/app.dart';

const _user = User(
  id: 'fixture-user',
  fullName: 'Fixture',
  email: 'fixture@example.invalid',
  role: 'user',
  plan: 'Free',
);

class _Repository extends AuthRepository {
  User? current;
  bool failRestore = false;
  bool failLogout = false;
  int loginCalls = 0;
  Completer<User>? pending;
  @override
  Future<User?> getCurrentUser() async {
    if (failRestore) throw StateError('fixture storage failure');
    return current;
  }

  @override
  Future<User> login({required String email, required String password}) async {
    loginCalls++;
    return pending?.future ?? Future.value(_user);
  }

  @override
  Future<void> logout() async {
    if (failLogout) throw StateError('fixture storage failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  test('controller publishes pending then authenticated state', () async {
    final repo = _Repository()..pending = Completer<User>();
    final controller = AuthController(repo);
    addTearDown(controller.dispose);
    await Future<void>.value();
    final login = controller.login(
      email: 'fixture@example.invalid',
      password: 'fixture',
    );
    expect(controller.state.isLoading, isTrue);
    repo.pending!.complete(_user);
    await login;
    expect(controller.state.user, _user);
    expect(controller.state.isLoading, isFalse);
  });
  test(
    'restore/storage and logout errors become state without unhandled futures',
    () async {
      final repo = _Repository()..failRestore = true;
      final controller = AuthController(repo);
      addTearDown(controller.dispose);
      await Future<void>.value();
      expect(controller.state.error, contains('storage failure'));
      await controller.login(email: 'fixture', password: 'fixture');
      repo.failLogout = true;
      await controller.logout();
      expect(controller.state.user, _user);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.error, contains('storage failure'));
      repo.failLogout = false;
      await controller.logout();
      expect(controller.state.user, isNull);
    },
  );
  testWidgets('default auth widget validates before invoking repository', (
    tester,
  ) async {
    // Supply local test font bytes as assets; prohibit runtime font downloads.
    GoogleFonts.config.allowRuntimeFetching = false;
    final fontBytes = File(
      '../.runtime/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
    ).readAsBytesSync();
    final codec = const StandardMessageCodec();
    final assets = <String, Object>{
      for (final name in [
        'DMSerifDisplay-Regular.ttf',
        'PlusJakartaSans-Regular.ttf',
        'PlusJakartaSans-Medium.ttf',
        'PlusJakartaSans-SemiBold.ttf',
        'PlusJakartaSans-Bold.ttf',
      ])
        name: [
          {'asset': name},
        ],
    };
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (message) async {
        final key = const StringCodec().decodeMessage(message);
        if (key == 'AssetManifest.bin') return codec.encodeMessage(assets);
        return ByteData.sublistView(fontBytes);
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      ),
    );
    final repo = _Repository();
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const AerogreenApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AerogreenApp)),
    );
    final router = container.read(goRouterProvider);
    router.go('/control');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/auth');
    await tester.tap(find.text('Đăng nhập').last);
    await tester.pump();
    expect(find.text('Email không hợp lệ'), findsOneWidget);
    expect(find.text('Mật khẩu ít nhất 8 ký tự'), findsOneWidget);
    expect(repo.loginCalls, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
