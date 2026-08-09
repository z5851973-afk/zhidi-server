import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/owner_address_api_client.dart';

void main() {
  const token = 'owner-token';
  const draft = OwnerAddressDraft(
    recipient: '林先生',
    phone: '13800138201',
    province: '四川省',
    city: '成都市',
    district: '武侯区',
    detail: '科华路 1 号',
    isDefault: true,
  );
  final baseUrl = Uri.parse('https://api.example.test/root/');

  test(
    'list sends bearer token and parses the server address contract',
    () async {
      late http.Request captured;
      final client = OwnerAddressApiClient(
        baseUrl: baseUrl,
        httpClient: MockClient((request) async {
          captured = request;
          return okEnvelope([addressJson()]);
        }),
      );

      final addresses = await client.list(token);

      expect(captured.method, 'GET');
      expect(
        captured.url,
        Uri.parse('https://api.example.test/api/v1/owners/me/addresses'),
      );
      expect(captured.headers['authorization'], 'Bearer $token');
      expect(addresses.single.id, 'address-1');
      expect(addresses.single.province, '四川省');
      expect(addresses.single.isDefault, isTrue);
      expect(addresses.single.createdAt, DateTime.utc(2026, 8, 2, 8));
    },
  );

  test(
    'create update default and delete use the exact routes and bodies',
    () async {
      final requests = <http.Request>[];
      final client = OwnerAddressApiClient(
        baseUrl: baseUrl,
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'DELETE') return okEnvelope(null);
          return okEnvelope(addressJson());
        }),
      );

      await client.create(token, draft);
      await client.update(token, 'address/1', draft);
      await client.setDefault(token, 'address/1');
      await client.delete(token, 'address/1');

      expect(requests.map((request) => request.method), [
        'POST',
        'PUT',
        'PUT',
        'DELETE',
      ]);
      expect(requests.map((request) => request.url.path), [
        '/api/v1/owners/me/addresses',
        '/api/v1/owners/me/addresses/address%2F1',
        '/api/v1/owners/me/addresses/address%2F1/default',
        '/api/v1/owners/me/addresses/address%2F1',
      ]);
      expect(jsonDecode(requests[0].body), draft.toJson());
      expect(jsonDecode(requests[1].body), draft.toJson());
      expect(requests[2].body, isEmpty);
      expect(requests[3].body, isEmpty);
      for (final request in requests) {
        expect(request.headers['authorization'], 'Bearer $token');
      }
    },
  );

  test('preserves backend Chinese error and status', () async {
    final client = OwnerAddressApiClient(
      httpClient: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'VALIDATION_ERROR',
              'message': '手机号格式不正确',
              'data': null,
            }),
          ),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(
      client.create(token, draft),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.code, 'code', 'VALIDATION_ERROR')
            .having((error) => error.message, 'message', '手机号格式不正确')
            .having((error) => error.statusCode, 'statusCode', 400),
      ),
    );
  });

  test('maps timeout and malformed successful data to typed errors', () async {
    final timeoutClient = OwnerAddressApiClient(
      requestTimeout: Duration.zero,
      httpClient: MockClient(
        (_) => Future<http.Response>.delayed(
          const Duration(seconds: 1),
          () => okEnvelope([]),
        ),
      ),
    );
    await expectLater(
      timeoutClient.list(token),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.code,
          'code',
          'NETWORK_TIMEOUT',
        ),
      ),
    );

    final malformedClient = OwnerAddressApiClient(
      httpClient: MockClient((_) async => okEnvelope({'unexpected': true})),
    );
    await expectLater(
      malformedClient.list(token),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_RESPONSE',
        ),
      ),
    );
  });
}

http.Response okEnvelope(Object? data) => http.Response(
  jsonEncode({'code': 'OK', 'message': 'success', 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> addressJson() => {
  'id': 'address-1',
  'recipient': '林先生',
  'phone': '13800138201',
  'province': '四川省',
  'city': '成都市',
  'district': '武侯区',
  'detail': '科华路 1 号',
  'isDefault': true,
  'createdAt': '2026-08-02T08:00:00Z',
  'updatedAt': '2026-08-02T09:00:00Z',
};
