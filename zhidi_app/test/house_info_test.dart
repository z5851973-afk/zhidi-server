import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/models/house_info.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';
import 'package:zhidi_app/services/service_request_api_client.dart';
import 'package:zhidi_app/services/worker_booking_api_client.dart';

void main() {
  const info = HouseInfo(
    areaSqm: 98.5,
    bedroomCount: 3,
    livingRoomCount: 2,
    kitchenCount: 1,
    bathroomCount: 2,
  );

  test('formats one canonical house summary for both apps', () {
    expect(info.areaLabel, '98.5㎡');
    expect(info.layoutLabel, '3室2厅1厨2卫');
    expect(info.summaryLabel, '98.5㎡ · 3室2厅1厨2卫');
    expect(
      const HouseInfo(
        areaSqm: 98,
        bedroomCount: 1,
        livingRoomCount: 0,
        kitchenCount: 0,
        bathroomCount: 1,
      ).areaLabel,
      '98㎡',
    );
  });

  test('parses only complete valid server house info', () {
    expect(
      HouseInfo.tryFromJson({
        'areaSqm': 98.5,
        'bedroomCount': 3,
        'livingRoomCount': 2,
        'kitchenCount': 1,
        'bathroomCount': 2,
      }),
      info,
    );
    expect(HouseInfo.tryFromJson(const {}), isNull);
    expect(
      HouseInfo.tryFromJson({
        'areaSqm': 98.5,
        'bedroomCount': 3,
        'livingRoomCount': 2,
        'kitchenCount': 1,
      }),
      isNull,
    );
    expect(
      HouseInfo.tryFromJson({
        'areaSqm': 10000,
        'bedroomCount': 3,
        'livingRoomCount': 2,
        'kitchenCount': 1,
        'bathroomCount': 2,
      }),
      isNull,
    );
  });

  test('serializes complete house info without changing remark', () {
    const draft = ServiceRequestDraft(
      trade: 'painting',
      serviceCity: '成都市',
      serviceAddress: '武侯区科华路 1 号',
      houseInfo: info,
      remark: '仅保留用户备注',
    );
    const booking = OwnerBookingCreateRequest(
      workerUserId: 'worker-1',
      houseInfo: info,
      remark: '仅保留用户备注',
    );

    expect(draft.toJson(), containsPair('areaSqm', 98.5));
    expect(draft.toJson(), containsPair('bedroomCount', 3));
    expect(draft.toJson(), containsPair('livingRoomCount', 2));
    expect(draft.toJson(), containsPair('kitchenCount', 1));
    expect(draft.toJson(), containsPair('bathroomCount', 2));
    expect(draft.toJson()['remark'], '仅保留用户备注');
    expect(booking.toJson(), containsPair('areaSqm', 98.5));
    expect(booking.toJson()['remark'], '仅保留用户备注');
  });

  test('all remote contracts expose complete house info or null', () {
    final serviceRequest = RemoteServiceRequest.fromJson({
      'id': 'request-1',
      'ownerUserId': 'owner-1',
      'trade': 'painting',
      'serviceCity': '成都市',
      'status': 'OPEN',
      'candidates': const [],
      'areaSqm': 98.5,
      'bedroomCount': 3,
      'livingRoomCount': 2,
      'kitchenCount': 1,
      'bathroomCount': 2,
      'createdAt': '2026-08-09T00:00:00Z',
      'updatedAt': '2026-08-09T00:00:00Z',
    });
    final ownerBooking = RemoteOwnerBooking.fromJson({
      'id': 'booking-1',
      'ownerUserId': 'owner-1',
      'serviceRequestId': 'request-1',
      'workerUserId': 'worker-1',
      'workerName': '周师傅',
      'trade': 'painting',
      'serviceCity': '成都市',
      'serviceAddress': null,
      'remark': null,
      'status': 'PENDING',
      'cancelledBy': null,
      'cancelReason': null,
      'cancelledAt': null,
      'proposedTime': null,
      'scheduledVisitAt': null,
      'onSiteAt': null,
      'actualOnSiteAt': null,
      'createdAt': '2026-08-09T00:00:00Z',
      'updatedAt': '2026-08-09T00:00:00Z',
    });
    final workerBooking = RemoteWorkerBooking.fromJson({
      'id': 'booking-1',
      'ownerUserId': 'owner-1',
      'ownerName': '林业主',
      'ownerPhone': '13800138101',
      'serviceRequestId': 'request-1',
      'workerUserId': 'worker-1',
      'workerName': '周师傅',
      'trade': 'painting',
      'serviceCity': '成都市',
      'serviceAddress': null,
      'remark': null,
      'status': 'PENDING',
      'areaSqm': 98.5,
      'bedroomCount': 3,
      'livingRoomCount': 2,
      'kitchenCount': 1,
      'bathroomCount': 2,
      'cancelledBy': null,
      'cancelReason': null,
      'cancelledAt': null,
      'arrivalConfirmedByOwner': false,
      'arrivalConfirmedByWorker': false,
      'onSiteAt': null,
      'proposedTime': null,
      'scheduledVisitAt': null,
      'actualOnSiteAt': null,
      'createdAt': '2026-08-09T00:00:00Z',
      'updatedAt': '2026-08-09T00:00:00Z',
    });

    expect(serviceRequest.houseInfo, info);
    expect(ownerBooking.houseInfo, isNull);
    expect(workerBooking.houseInfo, info);
  });
}
