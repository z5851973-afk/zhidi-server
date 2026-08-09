import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/business_event_api_client.dart';

void main() {
  const token = 'access-token';
  final baseUrl = Uri.parse('https://api.example.test/root/');

  test('list sends cursor query and parses the complete event page', () async {
    late http.Request captured;
    final client = BusinessEventApiClient(
      baseUrl: baseUrl,
      httpClient: MockClient((request) async {
        captured = request;
        return okEnvelope({
          'items': [eventJson(sequenceNo: 8)],
          'nextCursor': 8,
        });
      }),
    );

    final page = await client.list(token, after: 7, size: 25);

    expect(captured.method, 'GET');
    expect(
      captured.url,
      Uri.parse(
        'https://api.example.test/api/v1/notifications?after=7&size=25',
      ),
    );
    expect(captured.headers['authorization'], 'Bearer $token');
    expect(captured.headers['accept'], 'application/json');
    expect(page.nextCursor, 8);
    expect(page.items, hasLength(1));
    final event = page.items.single;
    expect(event.eventId, 'event-8');
    expect(event.sequenceNo, 8);
    expect(event.actorUserId, 'actor-1');
    expect(event.eventType, 'DAILY_REPORT_SUBMITTED');
    expect(event.aggregateType, 'DAILY_REPORT');
    expect(event.aggregateId, 'report-1');
    expect(event.bookingId, 'booking-1');
    expect(event.serviceRequestId, 'request-1');
    expect(event.payload, {'reportDate': '2026-08-08', 'revision': 2});
    expect(event.occurredAt, DateTime.utc(2026, 8, 8, 9, 10, 11));
    expect(event.readAt, isNull);
  });

  test('markRead uses encoded event route and parses readAt', () async {
    late http.Request captured;
    final client = BusinessEventApiClient(
      baseUrl: baseUrl,
      httpClient: MockClient((request) async {
        captured = request;
        return okEnvelope(
          eventJson(
            eventId: 'event/8',
            sequenceNo: 8,
            readAt: '2026-08-08T09:12:13+08:00',
          ),
        );
      }),
    );

    final event = await client.markRead(token, 'event/8');

    expect(captured.method, 'PUT');
    expect(captured.url.path, '/api/v1/notifications/event%2F8/read');
    expect(captured.url.query, isEmpty);
    expect(captured.headers['authorization'], 'Bearer $token');
    expect(captured.body, isEmpty);
    expect(event.eventId, 'event/8');
    expect(event.readAt, DateTime.utc(2026, 8, 8, 1, 12, 13));
  });

  test('public models can be constructed directly for state fakes', () {
    final event = RemoteBusinessEvent.fromJson(eventJson(sequenceNo: 3));
    final page = BusinessEventPage(items: [event], nextCursor: 3);

    expect(page.items.single.sequenceNo, 3);
    expect(page.nextCursor, 3);
  });

  test('list rejects sizes outside 1 through 100 before sending', () async {
    var requestCount = 0;
    final client = BusinessEventApiClient(
      httpClient: MockClient((_) async {
        requestCount += 1;
        return okEnvelope({'items': [], 'nextCursor': 4});
      }),
    );

    await expectLater(
      client.list(token, after: 4, size: 0),
      throwsArgumentError,
    );
    await expectLater(
      client.list(token, after: 4, size: 101),
      throwsArgumentError,
    );
    expect(requestCount, 0);
  });

  test('list rejects events at or behind the requested cursor', () async {
    final client = pageClient(
      after: 5,
      items: [eventJson(sequenceNo: 5)],
      nextCursor: 5,
    );

    await expectInvalidResponse(client.list(token, after: 5));
  });

  test(
    'list rejects event sequences that are not strictly ascending',
    () async {
      for (final sequences in [
        [6, 6],
        [7, 6],
      ]) {
        final client = pageClient(
          after: 5,
          items: sequences
              .map((sequence) => eventJson(sequenceNo: sequence))
              .toList(),
          nextCursor: sequences.last,
        );

        await expectInvalidResponse(client.list(token, after: 5));
      }
    },
  );

  test(
    'list rejects a nonempty page cursor not equal to the last event',
    () async {
      final client = pageClient(
        after: 5,
        items: [eventJson(sequenceNo: 6)],
        nextCursor: 7,
      );

      await expectInvalidResponse(client.list(token, after: 5));
    },
  );

  test('list rejects an empty page cursor that moves past after', () async {
    final client = pageClient(after: 5, items: const [], nextCursor: 6);

    await expectInvalidResponse(client.list(token, after: 5));
  });

  test('list accepts both size bounds and an unchanged empty cursor', () async {
    final sizes = <int>[];
    final client = BusinessEventApiClient(
      httpClient: MockClient((request) async {
        sizes.add(int.parse(request.url.queryParameters['size']!));
        final after = int.parse(request.url.queryParameters['after']!);
        return okEnvelope({'items': [], 'nextCursor': after});
      }),
    );

    expect((await client.list(token, after: 0, size: 1)).nextCursor, 0);
    expect((await client.list(token, after: 9, size: 100)).nextCursor, 9);
    expect(sizes, [1, 100]);
  });

  test('preserves backend error code message and status', () async {
    final client = BusinessEventApiClient(
      httpClient: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({'code': 'NOT_FOUND', 'message': '通知不存在', 'data': null}),
          ),
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(
      client.markRead(token, 'missing-event'),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.code, 'code', 'NOT_FOUND')
            .having((error) => error.message, 'message', '通知不存在')
            .having((error) => error.statusCode, 'statusCode', 404),
      ),
    );
  });

  test('maps timeout and client failures to typed network errors', () async {
    final timeoutClient = BusinessEventApiClient(
      requestTimeout: Duration.zero,
      httpClient: MockClient(
        (_) => Future<http.Response>.delayed(
          const Duration(seconds: 1),
          () => okEnvelope({'items': [], 'nextCursor': 0}),
        ),
      ),
    );
    await expectLater(
      timeoutClient.list(token, after: 0),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.code,
          'code',
          'NETWORK_TIMEOUT',
        ),
      ),
    );

    final unavailableClient = BusinessEventApiClient(
      httpClient: MockClient(
        (_) async => throw http.ClientException('connection closed'),
      ),
    );
    await expectLater(
      unavailableClient.list(token, after: 0),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.code,
          'code',
          'NETWORK_UNAVAILABLE',
        ),
      ),
    );
  });

  test('maps malformed successful responses to INVALID_RESPONSE', () async {
    final responses = [
      http.Response('{', 200),
      okEnvelope({'items': 'not-a-list', 'nextCursor': 5}),
      okEnvelope({
        'items': [eventJson(sequenceNo: 6, occurredAt: 'not-a-date')],
        'nextCursor': 6,
      }),
    ];

    for (final response in responses) {
      final client = BusinessEventApiClient(
        httpClient: MockClient((_) async => response),
      );
      await expectInvalidResponse(client.list(token, after: 5));
    }
  });
}

BusinessEventApiClient pageClient({
  required int after,
  required List<Map<String, dynamic>> items,
  required int nextCursor,
}) {
  return BusinessEventApiClient(
    httpClient: MockClient(
      (_) async => okEnvelope({'items': items, 'nextCursor': nextCursor}),
    ),
  );
}

Future<void> expectInvalidResponse(Future<Object?> future) {
  return expectLater(
    future,
    throwsA(
      isA<AuthApiException>().having(
        (error) => error.code,
        'code',
        'INVALID_RESPONSE',
      ),
    ),
  );
}

http.Response okEnvelope(Object? data) => http.Response.bytes(
  utf8.encode(jsonEncode({'code': 'OK', 'message': 'success', 'data': data})),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> eventJson({
  String? eventId,
  required int sequenceNo,
  Object? actorUserId = 'actor-1',
  Object? payload = const {'reportDate': '2026-08-08', 'revision': 2},
  String occurredAt = '2026-08-08T09:10:11Z',
  Object? readAt,
}) => {
  'eventId': eventId ?? 'event-$sequenceNo',
  'sequenceNo': sequenceNo,
  'actorUserId': actorUserId,
  'eventType': 'DAILY_REPORT_SUBMITTED',
  'aggregateType': 'DAILY_REPORT',
  'aggregateId': 'report-1',
  'bookingId': 'booking-1',
  'serviceRequestId': 'request-1',
  'payload': payload,
  'occurredAt': occurredAt,
  'readAt': readAt,
};
