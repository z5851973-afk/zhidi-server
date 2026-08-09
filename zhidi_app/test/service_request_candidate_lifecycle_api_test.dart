import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/services/service_request_api_client.dart';

void main() {
  final baseUrl = Uri.parse('https://api.example.test');

  Map<String, dynamic> responseData({
    String id = 'request-1',
    List<Map<String, dynamic>> candidates = const [],
  }) => {
    'id': id,
    'ownerUserId': 'owner-1',
    'trade': '水电',
    'serviceCity': '成都',
    'serviceAddress': '测试地址',
    'remark': null,
    'status': 'OPEN',
    'candidates': candidates,
    'createdAt': '2026-08-08T00:00:00Z',
    'updatedAt': '2026-08-08T00:00:00Z',
    'activeCandidateCount': candidates.length,
    'availableCandidateSlots': 3 - candidates.length,
    'canAddCandidates': candidates.length < 3,
  };

  http.Response ok(Map<String, dynamic> data) => http.Response(
    jsonEncode({'code': 'OK', 'message': 'success', 'data': data}),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  test('remove candidate posts to request-scoped endpoint', () async {
    late http.Request captured;
    final api = ServiceRequestApiClient(
      baseUrl: baseUrl,
      httpClient: MockClient((request) async {
        captured = request;
        return ok(responseData());
      }),
    );

    final result = await api.removeCandidate('token', 'request-1', 'booking-1');

    expect(captured.method, 'POST');
    expect(
      captured.url.path,
      '/api/v1/owners/me/service-requests/request-1/candidates/booking-1/remove',
    );
    expect(result.availableCandidateSlots, 3);
  });

  test('replace candidate uses one atomic request', () async {
    var calls = 0;
    late http.Request captured;
    final api = ServiceRequestApiClient(
      baseUrl: baseUrl,
      httpClient: MockClient((request) async {
        calls++;
        captured = request;
        return ok(responseData());
      }),
    );

    await api.replaceCandidate('token', 'request-1', 'booking-1', 'worker-2');

    expect(calls, 1);
    expect(
      captured.url.path,
      '/api/v1/owners/me/service-requests/request-1/candidates/booking-1/replace',
    );
    expect(jsonDecode(captured.body), {'workerUserId': 'worker-2'});
  });

  test('reopen returns the newly cloned request', () async {
    final api = ServiceRequestApiClient(
      baseUrl: baseUrl,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/owners/me/service-requests/request-old/reopen',
        );
        return ok(responseData(id: 'request-new'));
      }),
    );

    final result = await api.reopenRequest('token', 'request-old');

    expect(result.id, 'request-new');
  });

  test('cancel request posts to the exact request endpoint', () async {
    late http.Request captured;
    final api = ServiceRequestApiClient(
      baseUrl: baseUrl,
      httpClient: MockClient((request) async {
        captured = request;
        return ok(responseData());
      }),
    );

    await api.cancelRequest('token', 'request-1');

    expect(captured.method, 'POST');
    expect(
      captured.url.path,
      '/api/v1/owners/me/service-requests/request-1/cancel',
    );
  });

  test('candidate keeps scheduled and actual visit times separate', () {
    final candidate = RemoteCandidateBooking.fromJson({
      'id': 'booking-1',
      'serviceRequestId': 'request-1',
      'ownerUserId': 'owner-1',
      'ownerName': '王先生',
      'ownerPhone': '13800138000',
      'workerUserId': 'worker-1',
      'workerName': '周师傅',
      'trade': '水电',
      'serviceCity': '成都',
      'serviceAddress': '测试地址',
      'remark': null,
      'status': 'ON_SITE',
      'proposedTime': '2026-08-09T01:00:00Z',
      'scheduledVisitAt': '2026-08-09T01:30:00Z',
      'onSiteAt': '2026-08-09T01:45:00Z',
      'actualOnSiteAt': '2026-08-09T02:00:00Z',
      'createdAt': '2026-08-09T00:00:00Z',
      'updatedAt': '2026-08-09T02:00:00Z',
    });

    expect(candidate.scheduledVisitAt, DateTime.utc(2026, 8, 9, 1, 30));
    expect(candidate.actualOnSiteAt, DateTime.utc(2026, 8, 9, 2));
  });

  test('candidate falls back to legacy proposed and on-site fields', () {
    final candidate = RemoteCandidateBooking.fromJson({
      'id': 'booking-legacy',
      'serviceRequestId': 'request-1',
      'ownerUserId': 'owner-1',
      'ownerName': '王先生',
      'ownerPhone': '13800138000',
      'workerUserId': 'worker-1',
      'workerName': '周师傅',
      'trade': '水电',
      'serviceCity': '成都',
      'serviceAddress': '测试地址',
      'remark': null,
      'status': 'ON_SITE',
      'proposedTime': '2026-08-09T01:30:00Z',
      'onSiteAt': '2026-08-09T02:00:00Z',
      'createdAt': '2026-08-09T00:00:00Z',
      'updatedAt': '2026-08-09T02:00:00Z',
    });

    expect(candidate.scheduledVisitAt, DateTime.utc(2026, 8, 9, 1, 30));
    expect(candidate.actualOnSiteAt, DateTime.utc(2026, 8, 9, 2));
  });

  test('candidate proposal stays unconfirmed until owner accepts it', () {
    final candidate = RemoteCandidateBooking.fromJson({
      'id': 'booking-proposed',
      'serviceRequestId': 'request-1',
      'ownerUserId': 'owner-1',
      'ownerName': '王先生',
      'ownerPhone': '13800138000',
      'workerUserId': 'worker-1',
      'workerName': '周师傅',
      'trade': '水电',
      'serviceCity': '成都',
      'serviceAddress': '测试地址',
      'remark': null,
      'status': 'VISIT_PROPOSED',
      'proposedTime': '2026-08-09T01:30:00Z',
      'createdAt': '2026-08-09T00:00:00Z',
      'updatedAt': '2026-08-09T00:10:00Z',
    });

    expect(candidate.proposedTime, DateTime.utc(2026, 8, 9, 1, 30));
    expect(candidate.scheduledVisitAt, isNull);
  });
}
