import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/worker_directory_api_client.dart';

void main() {
  final baseUrl = Uri.parse('https://api.example.test/root/');

  test('GET list sends exact path and parses worker directory profiles', () async {
    late http.Request captured;
    final client = WorkerDirectoryApiClient(
      baseUrl: baseUrl,
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': [
              {
                'userId': 'worker-user-1',
                'name': '周建平',
                'serviceCity': '杭州',
                'primaryTrade': '泥工',
                'experienceYears': 12,
                'dailyRate': 680.5,
                'bio': '擅长瓷砖铺贴和厨卫防水',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final workers = await client.listWorkers();

    expect(captured.method, 'GET');
    expect(captured.url, Uri.parse('https://api.example.test/api/v1/workers'));
    expect(captured.headers['accept'], 'application/json');
    expect(captured.headers.containsKey('authorization'), isFalse);
    expect(workers, hasLength(1));
    expect(workers.single.userId, 'worker-user-1');
    expect(workers.single.name, '周建平');
    expect(workers.single.serviceCity, '杭州');
    expect(workers.single.primaryTrade, '泥工');
    expect(workers.single.experienceYears, 12);
    expect(workers.single.dailyRate, 680.5);
    expect(workers.single.bio, '擅长瓷砖铺贴和厨卫防水');
  });

  test('GET detail sends user id path and parses nullable city and bio', () async {
    late http.Request captured;
    final client = WorkerDirectoryApiClient(
      baseUrl: baseUrl,
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': {
              'userId': 'worker-user-2',
              'name': '何师傅',
              'serviceCity': null,
              'primaryTrade': '拆除',
              'experienceYears': 9,
              'dailyRate': 520,
              'bio': null,
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final worker = await client.getWorker('worker-user-2');

    expect(captured.method, 'GET');
    expect(
      captured.url,
      Uri.parse('https://api.example.test/api/v1/workers/worker-user-2'),
    );
    expect(worker.userId, 'worker-user-2');
    expect(worker.serviceCity, isNull);
    expect(worker.bio, isNull);
    expect(worker.dailyRate, 520.0);
  });

  test('preserves backend error code message and HTTP status', () async {
    final client = WorkerDirectoryApiClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 'WORKER_NOT_FOUND',
            'message': 'worker is not available',
            'data': null,
          }),
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(
      client.getWorker('missing-worker'),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.code, 'code', 'WORKER_NOT_FOUND')
            .having(
              (error) => error.message,
              'message',
              'worker is not available',
            )
            .having((error) => error.statusCode, 'statusCode', 404),
      ),
    );
  });

  test('maps malformed OK list data to INVALID_RESPONSE', () async {
    final client = WorkerDirectoryApiClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({'code': 'OK', 'message': 'success', 'data': {}}),
          200,
        ),
      ),
    );

    await expectLater(
      client.listWorkers(),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.code, 'code', 'INVALID_RESPONSE')
            .having((error) => error.statusCode, 'statusCode', 200),
      ),
    );
  });

  test('maps malformed OK profile data to INVALID_RESPONSE', () async {
    final client = WorkerDirectoryApiClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': {
              'userId': 'worker-user-1',
              'name': '周建平',
              'serviceCity': '杭州',
              'primaryTrade': '泥工',
              'experienceYears': '12',
              'dailyRate': 680,
              'bio': null,
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(
      client.getWorker('worker-user-1'),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.code, 'code', 'INVALID_RESPONSE')
            .having((error) => error.statusCode, 'statusCode', 200),
      ),
    );
  });

  test('maps timeout to existing typed error code', () async {
    final client = WorkerDirectoryApiClient(
      requestTimeout: Duration.zero,
      httpClient: MockClient(
        (_) => Future<http.Response>.delayed(
          const Duration(seconds: 1),
          () => http.Response('{}', 200),
        ),
      ),
    );

    await expectLater(
      client.listWorkers(),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.code,
          'code',
          'NETWORK_TIMEOUT',
        ),
      ),
    );
  });

  test('maps connection failure to existing typed error code', () async {
    final client = WorkerDirectoryApiClient(
      httpClient: MockClient(
        (_) async => throw const SocketException('offline'),
      ),
    );

    await expectLater(
      client.listWorkers(),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.code,
          'code',
          'NETWORK_UNAVAILABLE',
        ),
      ),
    );
  });
}
