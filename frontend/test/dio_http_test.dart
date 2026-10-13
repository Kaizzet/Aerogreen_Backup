import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotagri_app/repositories/dio_client.dart';
import 'package:iotagri_app/repositories/impl/dio_pump_repository_impl.dart';
import 'api_session_test.dart' show TestStorage;

class _Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) respond;
  _Adapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody _body(Object data, int status) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  test(
    'pump repository sends production payload and maps acknowledged result',
    () async {
      final dio = Dio();
      dio.httpClientAdapter = _Adapter((request) async {
        expect(request.path, '/api/devices/fixture-device/pump/commands');
        expect(request.data, {
          'commandId': 'fixture-command',
          'on': true,
          'durationSeconds': 60,
        });
        return _body({
          'id': 'fixture-command',
          'isOn': true,
          'durationSeconds': 60,
          'status': 1,
        }, 201);
      });
      final repo = DioPumpRepositoryImpl(
        dioClient: DioClient(dioInstance: dio, storage: TestStorage()),
      );
      final command = await repo.sendPumpCommand(
        'fixture-device',
        'fixture-command',
        true,
        60,
      );
      expect(command.status, 'Acknowledged');
      expect(command.durationSeconds, 60);
      dio.close();
    },
  );
  test('HTTP server failure remains a DioException', () async {
    final dio = Dio()
      ..httpClientAdapter = _Adapter(
        (_) async => _body({'error': 'fixture'}, 503),
      );
    final repo = DioPumpRepositoryImpl(
      dioClient: DioClient(dioInstance: dio, storage: TestStorage()),
    );
    await expectLater(
      repo.sendPumpCommand('fixture-device', 'fixture-command', true, 60),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          503,
        ),
      ),
    );
    dio.close();
  });
  for (final refreshStatus in [200, 401]) {
    test(
      'Dio refresh $refreshStatus terminates and retries at most once',
      () async {
        final storage = TestStorage();
        var originals = 0;
        var refreshes = 0;
        final dio = Dio();
        dio.httpClientAdapter = _Adapter((request) async {
          if (request.path.endsWith('/refresh')) {
            refreshes++;
            return _body({
              'accessToken': 'fixture-new',
              'refreshToken': 'fixture-rotated',
            }, refreshStatus);
          }
          originals++;
          return _body({}, 401);
        });
        final client = DioClient(dioInstance: dio, storage: storage);
        await expectLater(
          client.dio.get('/fixture'),
          throwsA(isA<DioException>()),
        );
        expect(refreshes, 1);
        expect(originals, refreshStatus == 200 ? 2 : 1);
        expect(storage.values, isEmpty);
        dio.close();
      },
    );
  }
  test('Dio successful refresh resolves original response', () async {
    final storage = TestStorage();
    final dio = Dio();
    dio.httpClientAdapter = _Adapter(
      (request) async => request.path.endsWith('/refresh')
          ? _body({
              'accessToken': 'fixture-new',
              'refreshToken': 'fixture-rotated',
            }, 200)
          : _body(
              {'items': []},
              request.headers['Authorization'] == 'Bearer fixture-new'
                  ? 200
                  : 401,
            ),
    );
    final client = DioClient(dioInstance: dio, storage: storage);
    expect((await client.dio.get('/fixture')).statusCode, 200);
    expect(storage.values['refresh_token'], 'fixture-rotated');
    dio.close();
  });
}
