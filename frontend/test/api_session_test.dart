import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iotagri_app/services/api_service.dart';

class TestStorage extends FlutterSecureStorage {
  final Map<String, String> values = {
    'access_token': 'fixture-old',
    'refresh_token': 'fixture-refresh',
  };
  bool failWrite = false;
  @override
  Future<String?> read({
    required String key,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async => values[key];
  @override
  Future<void> write({
    required String key,
    required String? value,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async {
    if (failWrite) throw StateError('fixture storage unavailable');
    if (value != null) values[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async {
    values.remove(key);
  }
}

void main() {
  tearDown(() => ApiService.onSessionExpired = null);
  test(
    'provisioning uses device route and returns server setup contract',
    () async {
      final api = ApiService(
        storage: TestStorage(),
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/devices/fixture-device/provisioning-code',
          );
          return http.Response(
            '{"code":"FIXTURECODE12","expiresAt":"2030-01-01T00:15:00Z"}',
            200,
          );
        }),
      );
      final result = await api.createProvisioningCode('fixture-device');
      expect(result['code'], 'FIXTURECODE12');
      expect(result['expiresAt'], '2030-01-01T00:15:00Z');
    },
  );
  test('provisioning HTTP error is propagated without token refresh', () async {
    var calls = 0;
    final api = ApiService(
      storage: TestStorage(),
      client: MockClient((_) async {
        calls++;
        return http.Response('fixture unavailable', 503);
      }),
    );
    await expectLater(
      api.createProvisioningCode('fixture-device'),
      throwsException,
    );
    expect(calls, 1);
  });
  test(
    'HTTP refresh rotates stored values and retries original request once',
    () async {
      final storage = TestStorage();
      final requests = <http.Request>[];
      final api = ApiService(
        storage: storage,
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/refresh')) {
            return http.Response(
              jsonEncode({
                'accessToken': 'fixture-new',
                'refreshToken': 'fixture-rotated',
              }),
              200,
            );
          }
          return request.headers['Authorization'] == 'Bearer fixture-new'
              ? http.Response('[]', 200)
              : http.Response('', 401);
        }),
      );
      expect(await api.getDevices(), isEmpty);
      expect(requests.length, 3);
      expect(storage.values['refresh_token'], 'fixture-rotated');
    },
  );
  test('concurrent unauthorized requests share one pending refresh', () async {
    final gate = Completer<http.Response>();
    final began = Completer<void>();
    var refreshCount = 0;
    final api = ApiService(
      storage: TestStorage(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/refresh')) {
          refreshCount++;
          if (!began.isCompleted) began.complete();
          return gate.future;
        }
        return request.headers['Authorization'] == 'Bearer fixture-new'
            ? http.Response('[]', 200)
            : http.Response('', 401);
      }),
    );
    final first = api.getDevices();
    final second = api.getDevices();
    await began.future;
    gate.complete(
      http.Response(
        '{"accessToken":"fixture-new","refreshToken":"fixture-rotated"}',
        200,
      ),
    );
    await Future.wait([first, second]);
    expect(refreshCount, 1);
  });
  test('rejected refresh clears storage and reports expired session', () async {
    final storage = TestStorage();
    var expired = 0;
    ApiService.onSessionExpired = () => expired++;
    final api = ApiService(
      storage: storage,
      client: MockClient((_) async => http.Response('', 401)),
    );
    await expectLater(api.getDevices(), throwsException);
    expect(storage.values, isEmpty);
    expect(expired, 1);
  });
  test(
    'second unauthorized response stops retry rather than refreshing again',
    () async {
      var calls = 0;
      final api = ApiService(
        storage: TestStorage(),
        client: MockClient((request) async {
          calls++;
          return request.url.path.endsWith('/refresh')
              ? http.Response(
                  '{"accessToken":"fixture-new","refreshToken":"fixture-rotated"}',
                  200,
                )
              : http.Response('', 401);
        }),
      );
      await expectLater(api.getDevices(), throwsException);
      expect(calls, 3);
    },
  );
  test(
    'transient refresh failure retains session and does not retry request',
    () async {
      final storage = TestStorage();
      var calls = 0;
      final api = ApiService(
        storage: storage,
        client: MockClient((request) async {
          calls++;
          return http.Response(
            '',
            request.url.path.endsWith('/refresh') ? 503 : 401,
          );
        }),
      );
      await expectLater(api.getDevices(), throwsA(isA<http.ClientException>()));
      expect(calls, 2);
      expect(storage.values['access_token'], 'fixture-old');
    },
  );
  test(
    'login uses injected HTTP transport and surfaces storage failure',
    () async {
      final storage = TestStorage()..failWrite = true;
      final api = ApiService(
        storage: storage,
        client: MockClient(
          (_) async => http.Response(
            '{"accessToken":"fixture-new","refreshToken":"fixture-rotated"}',
            200,
          ),
        ),
      );
      await expectLater(
        api.login('fixture@example.invalid', 'fixture-credential'),
        throwsStateError,
      );
    },
  );
}
