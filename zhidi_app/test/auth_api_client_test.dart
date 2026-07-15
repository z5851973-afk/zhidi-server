import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:zhidi_app/services/auth_api_client.dart';

void main() {
  test('parses SMS and login envelopes', () async {
    final client = AuthApiClient(
      baseUrl: Uri.parse('http://localhost:8080'),
      httpClient: _QueueClient([
        http.Response(_smsEnvelope(simulatedCode: '256438'), 200),
        http.Response(_loginEnvelope(accessToken: 'jwt'), 200),
      ]),
    );

    final sms = await client.requestSmsCode('16600000002');
    final login = await client.loginOwner('16600000002', '256438');

    expect(sms.simulatedCode, '256438');
    expect(sms.expiresInSeconds, 300);
    expect(login.accessToken, 'jwt');
    expect(login.user.roles, contains('OWNER'));
  });

  test('keeps backend error code and HTTP status', () async {
    final client = AuthApiClient(
      httpClient: _QueueClient([
        http.Response(
          '{"code":"SMS_RATE_LIMITED","message":"稍后重试","data":null}',
          429,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ]),
    );

    await expectLater(
      client.requestSmsCode('16600000002'),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.code, 'code', 'SMS_RATE_LIMITED')
            .having((error) => error.statusCode, 'statusCode', 429),
      ),
    );
  });

  test('reports a typed error for a non-JSON response', () async {
    final client = AuthApiClient(
      httpClient: _QueueClient([
        http.Response('<html>bad gateway</html>', 502),
      ]),
    );

    await expectLater(
      client.requestSmsCode('16600000002'),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_RESPONSE',
        ),
      ),
    );
  });

  test('reports malformed OK data as an invalid response', () async {
    final client = AuthApiClient(
      httpClient: _QueueClient([
        http.Response(
          '{"code":"OK","message":"success","data":{"accessToken":7}}',
          200,
        ),
      ]),
    );

    await expectLater(
      client.loginOwner('16600000002', '256438'),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.code, 'code', 'INVALID_RESPONSE')
            .having((error) => error.statusCode, 'statusCode', 200),
      ),
    );
  });

  test('reports request timeouts without leaking request data', () async {
    final client = AuthApiClient(
      httpClient: _NeverCompletesClient(),
      requestTimeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      client.loginOwner('16600000002', '256438'),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.code,
          'code',
          'NETWORK_TIMEOUT',
        ),
      ),
    );
  });

  test('reports connection failures as typed errors', () async {
    final client = AuthApiClient(httpClient: _SocketFailureClient());

    await expectLater(
      client.requestSmsCode('16600000002'),
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

final class _QueueClient extends http.BaseClient {
  _QueueClient(Iterable<http.Response> responses)
    : _responses = Queue.of(responses);

  final Queue<http.Response> _responses;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = _responses.removeFirst();
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

final class _NeverCompletesClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Completer<http.StreamedResponse>().future;
}

final class _SocketFailureClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Future.error(const SocketException('connection refused'));
}

String _smsEnvelope({required String simulatedCode}) =>
    '{"code":"OK","message":"success","data":{'
    '"simulatedCode":"$simulatedCode","expiresInSeconds":300,'
    '"retryAfterSeconds":60},"traceId":"trace-sms"}';

String _loginEnvelope({required String accessToken}) =>
    '{"code":"OK","message":"success","data":{'
    '"accessToken":"$accessToken","tokenType":"Bearer",'
    '"expiresInSeconds":2592000,"user":{'
    '"id":"01904f24-3f5b-7000-8000-000000000001",'
    '"phone":"16600000002","status":"ACTIVE","roles":["OWNER"]'
    '}},"traceId":"trace-login"}';
