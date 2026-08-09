import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/models/house_info.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';

void main() {
  final baseUrl = Uri.parse('https://api.example.test/root/');
  const houseInfo = HouseInfo(
    areaSqm: 98.5,
    bedroomCount: 3,
    livingRoomCount: 2,
    kitchenCount: 1,
    bathroomCount: 2,
  );

  test('POST booking sends bearer token and parses booking response', () async {
    late http.Request captured;
    final client = OwnerBookingApiClient(
      baseUrl: baseUrl,
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': {
              'id': 'booking-1',
              'ownerUserId': 'owner-1',
              'workerUserId': 'worker-1',
              'workerName': '周师傅',
              'trade': '泥工',
              'serviceCity': '杭州',
              'serviceAddress': null,
              'remark': '来自安卓业主端',
              'areaSqm': 98.5,
              'bedroomCount': 3,
              'livingRoomCount': 2,
              'kitchenCount': 1,
              'bathroomCount': 2,
              'serviceRequestId': 'sr-test-1',
              'cancelledBy': null,
              'cancelReason': null,
              'cancelledAt': null,
              'status': 'PENDING',
              'proposedTime': '2026-08-09T01:00:00Z',
              'scheduledVisitAt': '2026-08-09T01:30:00Z',
              'onSiteAt': '2026-08-09T01:45:00Z',
              'actualOnSiteAt': '2026-08-09T02:00:00Z',
              'createdAt': '2026-07-15T10:00:00Z',
              'updatedAt': '2026-07-15T10:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final booking = await client.createBooking(
      'jwt-token',
      const OwnerBookingCreateRequest(
        workerUserId: 'worker-1',
        houseInfo: houseInfo,
        trade: '泥工',
        serviceCity: '杭州',
        remark: '来自安卓业主端',
      ),
    );

    expect(captured.method, 'POST');
    expect(captured.url, Uri.parse('https://api.example.test/api/v1/bookings'));
    expect(captured.headers['accept'], 'application/json');
    expect(captured.headers['authorization'], 'Bearer jwt-token');
    expect(captured.headers['content-type'], 'application/json');
    expect(jsonDecode(captured.body), {
      'workerUserId': 'worker-1',
      'trade': '泥工',
      'serviceCity': '杭州',
      'serviceAddress': null,
      'areaSqm': 98.5,
      'bedroomCount': 3,
      'livingRoomCount': 2,
      'kitchenCount': 1,
      'bathroomCount': 2,
      'remark': '来自安卓业主端',
    });
    expect(booking.id, 'booking-1');
    expect(booking.workerName, '周师傅');
    expect(booking.status, 'PENDING');
    expect(booking.scheduledVisitAt, DateTime.utc(2026, 8, 9, 1, 30));
    expect(booking.actualOnSiteAt, DateTime.utc(2026, 8, 9, 2));
    expect(booking.houseInfo, houseInfo);
  });

  test('legacy visit fields remain compatible for one release', () {
    final booking = RemoteOwnerBooking.fromJson({
      'id': 'booking-legacy',
      'ownerUserId': 'owner-1',
      'serviceRequestId': 'request-legacy',
      'workerUserId': 'worker-1',
      'workerName': '周师傅',
      'trade': '泥工',
      'serviceCity': '杭州',
      'serviceAddress': null,
      'remark': null,
      'status': 'ON_SITE',
      'cancelledBy': null,
      'cancelReason': null,
      'cancelledAt': null,
      'proposedTime': '2026-08-09T01:30:00Z',
      'onSiteAt': '2026-08-09T02:00:00Z',
      'createdAt': '2026-08-09T00:00:00Z',
      'updatedAt': '2026-08-09T02:00:00Z',
    });

    expect(booking.scheduledVisitAt, DateTime.utc(2026, 8, 9, 1, 30));
    expect(booking.actualOnSiteAt, DateTime.utc(2026, 8, 9, 2));
  });

  test('pending proposal is not treated as an agreed visit time', () {
    final booking = RemoteOwnerBooking.fromJson({
      'id': 'booking-proposed',
      'ownerUserId': 'owner-1',
      'serviceRequestId': 'request-1',
      'workerUserId': 'worker-1',
      'workerName': '周师傅',
      'trade': '泥工',
      'serviceCity': '杭州',
      'serviceAddress': null,
      'remark': null,
      'status': 'VISIT_PROPOSED',
      'cancelledBy': null,
      'cancelReason': null,
      'cancelledAt': null,
      'proposedTime': '2026-08-09T01:30:00Z',
      'scheduledVisitAt': null,
      'onSiteAt': null,
      'actualOnSiteAt': null,
      'createdAt': '2026-08-09T00:00:00Z',
      'updatedAt': '2026-08-09T00:10:00Z',
    });

    expect(booking.proposedTime, DateTime.utc(2026, 8, 9, 1, 30));
    expect(booking.scheduledVisitAt, isNull);
    expect(booking.actualOnSiteAt, isNull);
  });

  test('preserves backend error when booking fails', () async {
    final client = OwnerBookingApiClient(
      baseUrl: baseUrl,
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
      client.createBooking(
        'jwt-token',
        const OwnerBookingCreateRequest(
          workerUserId: 'missing-worker',
          houseInfo: houseInfo,
        ),
      ),
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
}
