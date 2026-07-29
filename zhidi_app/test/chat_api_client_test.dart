import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/chat_api_client.dart';

void main() {
  test('parses message history returned as the server list envelope', () async {
    final api = ChatApiClient(
      baseUrl: Uri.parse('http://api.example.test'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/chat/rooms/room-1/messages');
        return http.Response(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': [
              {
                'id': 'message-1',
                'roomId': 'room-1',
                'senderUserId': 'worker-1',
                'senderRole': 'WORKER',
                'type': 'TEXT',
                'content': '明天九点见',
                'imageUrl': null,
                'readAt': null,
                'createdAt': '2026-07-22T04:00:00Z',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final messages = await api.getMessages('jwt', 'room-1');

    expect(messages, hasLength(1));
    expect(messages.single.content, '明天九点见');
  });

  test('preserves unauthorized error when creating chat room with expired token',
      () async {
    final api = ChatApiClient(
      baseUrl: Uri.parse('http://api.example.test'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/chat/rooms/by-booking/booking-1');
        return http.Response(
          jsonEncode({
            'code': 'UNAUTHORIZED',
            'message': '登录已过期，请重新登录',
            'data': null,
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      api.getOrCreateRoom('stale-token', 'booking-1'),
      throwsA(
        isA<AuthApiException>()
            .having((e) => e.code, 'code', 'UNAUTHORIZED')
            .having((e) => e.message, 'message', '登录已过期，请重新登录')
            .having((e) => e.statusCode, 'statusCode', 401),
      ),
    );
  });
}
