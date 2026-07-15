import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';

void main() {
  const token = 'secret-owner-token';
  final baseUrl = Uri.parse('https://api.example.test/root/');

  test(
    'GET sends exact path and bearer token and parses decimals and nulls',
    () async {
      late http.Request captured;
      final client = OwnerProfileApiClient(
        baseUrl: baseUrl,
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': {
                'userId': 'user-1',
                'phone': '13800138000',
                'name': null,
                'city': '上海',
                'decorationType': null,
                'address': null,
                'area': 89.5,
                'profileComplete': false,
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final profile = await client.getCurrent(token);

      expect(captured.method, 'GET');
      expect(
        captured.url,
        Uri.parse('https://api.example.test/api/v1/owners/me'),
      );
      expect(captured.headers['authorization'], 'Bearer $token');
      expect(captured.headers['accept'], 'application/json');
      expect(profile.userId, 'user-1');
      expect(profile.phone, '13800138000');
      expect(profile.name, isNull);
      expect(profile.city, '上海');
      expect(profile.decorationType, isNull);
      expect(profile.address, isNull);
      expect(profile.area, 89.5);
      expect(profile.profileComplete, isFalse);
    },
  );

  test('PUT sends exactly five editable fields and parses response', () async {
    late http.Request captured;
    final client = OwnerProfileApiClient(
      baseUrl: baseUrl,
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': {
              'userId': 'user-1',
              'phone': '13800138000',
              'name': '李女士',
              'city': '杭州',
              'decorationType': '新房装修',
              'address': '西湖区',
              'area': 120,
              'profileComplete': true,
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final profile = await client.updateCurrent(
      token,
      const OwnerProfileUpdate(
        name: '李女士',
        city: '杭州',
        decorationType: '新房装修',
        address: '西湖区',
        area: 120.0,
      ),
    );

    expect(captured.method, 'PUT');
    expect(
      captured.url,
      Uri.parse('https://api.example.test/api/v1/owners/me'),
    );
    expect(captured.headers['authorization'], 'Bearer $token');
    expect(captured.headers['accept'], 'application/json');
    expect(captured.headers['content-type'], 'application/json');
    expect(jsonDecode(captured.body), {
      'name': '李女士',
      'city': '杭州',
      'decorationType': '新房装修',
      'address': '西湖区',
      'area': 120.0,
    });
    expect(profile.name, '李女士');
    expect(profile.area, 120.0);
    expect(profile.profileComplete, isTrue);
  });

  test('preserves backend 401 code message and status', () async {
    final client = OwnerProfileApiClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 'TOKEN_EXPIRED',
            'message': '登录已过期',
            'data': null,
          }),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(
      client.getCurrent(token),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.code, 'code', 'TOKEN_EXPIRED')
            .having((error) => error.message, 'message', '登录已过期')
            .having((error) => error.statusCode, 'statusCode', 401),
      ),
    );
  });

  test('maps timeout to existing typed error code', () async {
    final client = OwnerProfileApiClient(
      requestTimeout: Duration.zero,
      httpClient: MockClient(
        (_) => Future<http.Response>.delayed(
          const Duration(seconds: 1),
          () => http.Response('{}', 200),
        ),
      ),
    );

    await expectLater(
      client.getCurrent(token),
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
    final client = OwnerProfileApiClient(
      httpClient: MockClient(
        (_) async => throw const SocketException('offline'),
      ),
    );

    await expectLater(
      client.getCurrent(token),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.code,
          'code',
          'NETWORK_UNAVAILABLE',
        ),
      ),
    );
  });

  test('maps malformed OK envelope data to INVALID_RESPONSE', () async {
    final client = OwnerProfileApiClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({'code': 'OK', 'message': 'success', 'data': []}),
          200,
        ),
      ),
    );

    await expectLater(
      client.getCurrent(token),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.code, 'code', 'INVALID_RESPONSE')
            .having((error) => error.statusCode, 'statusCode', 200),
      ),
    );
  });

  for (final missingField in ['name', 'area']) {
    test(
      'maps OK data missing nullable $missingField to INVALID_RESPONSE',
      () async {
        final data = <String, dynamic>{
          'userId': 'user-1',
          'phone': '13800138000',
          'name': null,
          'city': '上海',
          'decorationType': null,
          'address': null,
          'area': null,
          'profileComplete': false,
        }..remove(missingField);
        final responseBody = jsonEncode({
          'code': 'OK',
          'message': 'success',
          'data': data,
        });
        final client = OwnerProfileApiClient(
          httpClient: MockClient(
            (_) async => http.Response(
              responseBody,
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        );

        await expectLater(
          client.getCurrent(token),
          throwsA(
            isA<AuthApiException>()
                .having((error) => error.code, 'code', 'INVALID_RESPONSE')
                .having((error) => error.statusCode, 'statusCode', 200),
          ),
        );
      },
    );
  }

  test('exception string does not expose token or request body', () async {
    const privateName = 'private-owner-name';
    final client = OwnerProfileApiClient(
      httpClient: MockClient((_) async => http.Response('not-json', 200)),
    );

    try {
      await client.updateCurrent(
        token,
        const OwnerProfileUpdate(
          name: privateName,
          city: '北京',
          decorationType: null,
          address: null,
          area: null,
        ),
      );
      fail('expected AuthApiException');
    } on AuthApiException catch (error) {
      expect(error.toString(), isNot(contains(token)));
      expect(error.toString(), isNot(contains(privateName)));
    }
  });
}
