import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/worker_booking_api_client.dart';

void main() {
  final baseUrl = Uri.parse('https://api.example.test/root/');

  const sampleBookingJson = {
    'id': 'booking-1',
    'ownerUserId': 'owner-1',
    'ownerName': '林业主',
    'ownerPhone': '13800138101',
    'workerUserId': 'worker-1',
    'workerName': '周师傅',
    'trade': '泥工',
    'serviceCity': '杭州',
    'serviceAddress': '西湖区文三路 100 号',
    'remark': '来自安卓业主端',
    'status': 'PENDING',
    'createdAt': '2026-07-15T10:00:00Z',
    'updatedAt': '2026-07-15T10:00:00Z',
  };

  group('RemoteWorkerBooking.fromJson', () {
    test('parses all fields and converts timestamps to UTC', () {
      final booking = RemoteWorkerBooking.fromJson(sampleBookingJson);
      expect(booking.id, 'booking-1');
      expect(booking.ownerUserId, 'owner-1');
      expect(booking.ownerName, '林业主');
      expect(booking.ownerPhone, '13800138101');
      expect(booking.workerUserId, 'worker-1');
      expect(booking.workerName, '周师傅');
      expect(booking.trade, '泥工');
      expect(booking.serviceCity, '杭州');
      expect(booking.serviceAddress, '西湖区文三路 100 号');
      expect(booking.remark, '来自安卓业主端');
      expect(booking.status, 'PENDING');
      expect(booking.createdAt, DateTime.utc(2026, 7, 15, 10, 0, 0));
      expect(booking.updatedAt, DateTime.utc(2026, 7, 15, 10, 0, 0));
    });

    test('parses nullable serviceAddress and remark as null', () {
      final json = Map<String, dynamic>.from(sampleBookingJson)
        ..['serviceAddress'] = null
        ..['remark'] = null;
      final booking = RemoteWorkerBooking.fromJson(json);
      expect(booking.serviceAddress, isNull);
      expect(booking.remark, isNull);
    });
  });

  group('WorkerBookingApiClient.listWorkerBookings', () {
    test('sends bearer token and parses booking list', () async {
      late http.Request captured;
      final client = WorkerBookingApiClient(
        baseUrl: baseUrl,
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [sampleBookingJson],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final bookings = await client.listWorkerBookings('jwt-token');

      expect(captured.method, 'GET');
      expect(
        captured.url,
        Uri.parse('https://api.example.test/api/v1/workers/me/bookings'),
      );
      expect(captured.headers['authorization'], 'Bearer jwt-token');
      expect(bookings, hasLength(1));
      expect(bookings.first.id, 'booking-1');
      expect(bookings.first.status, 'PENDING');
    });

    test('throws AuthApiException on 401', () async {
      final client = WorkerBookingApiClient(
        baseUrl: baseUrl,
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': 'UNAUTHORIZED',
              'message': '未登录或登录已过期',
              'data': null,
            }),
            401,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await expectLater(
        client.listWorkerBookings('bad-token'),
        throwsA(
          isA<AuthApiException>()
              .having((e) => e.code, 'code', 'UNAUTHORIZED')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });

  group('WorkerBookingApiClient.acceptBooking', () {
    test('POSTs to accept endpoint and parses returned booking', () async {
      late http.Request captured;
      final client = WorkerBookingApiClient(
        baseUrl: baseUrl,
        httpClient: MockClient((request) async {
          captured = request;
          final accepted = Map<String, dynamic>.from(sampleBookingJson)
            ..['status'] = 'ACCEPTED';
          return http.Response(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': accepted,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final booking = await client.acceptBooking('jwt-token', 'booking-1');

      expect(captured.method, 'POST');
      expect(
        captured.url,
        Uri.parse(
          'https://api.example.test/api/v1/workers/me/bookings/booking-1/accept',
        ),
      );
      expect(captured.headers['authorization'], 'Bearer jwt-token');
      expect(booking.id, 'booking-1');
      expect(booking.status, 'ACCEPTED');
    });
  });

  group('WorkerBookingApiClient.rejectBooking', () {
    test('POSTs to reject endpoint and parses returned booking', () async {
      late http.Request captured;
      final client = WorkerBookingApiClient(
        baseUrl: baseUrl,
        httpClient: MockClient((request) async {
          captured = request;
          final rejected = Map<String, dynamic>.from(sampleBookingJson)
            ..['status'] = 'REJECTED';
          return http.Response(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': rejected,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final booking = await client.rejectBooking('jwt-token', 'booking-1');

      expect(captured.method, 'POST');
      expect(
        captured.url,
        Uri.parse(
          'https://api.example.test/api/v1/workers/me/bookings/booking-1/reject',
        ),
      );
      expect(captured.headers['authorization'], 'Bearer jwt-token');
      expect(booking.id, 'booking-1');
      expect(booking.status, 'REJECTED');
    });
  });

  group('network failures', () {
    test('throws NETWORK_UNAVAILABLE when client throws', () async {
      final client = WorkerBookingApiClient(
        baseUrl: baseUrl,
        httpClient: MockClient((_) async => throw http.ClientException('boom')),
      );

      await expectLater(
        client.listWorkerBookings('jwt-token'),
        throwsA(
          isA<AuthApiException>()
              .having((e) => e.code, 'code', 'NETWORK_UNAVAILABLE'),
        ),
      );
    });
  });
}
