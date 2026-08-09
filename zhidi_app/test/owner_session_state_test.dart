import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/models/house_info.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/owner_address_api_client.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';

void main() {
  test(
    'owner logout clears prior account business data in memory and storage',
    () async {
      final store = MemoryOwnerStore();
      final sessions = MemoryAuthSessionStore();
      final state = await OwnerAppState.memory(
        store: store,
        sessionStore: sessions,
        profileApi: const _OwnerProfileApiStub(),
        bookingApi: _OwnerBookingApiStub([_privacyBooking]),
      );
      await state.completeAuthenticatedLogin(_loginResponse);
      await state.fetchRemoteBookings();
      await state.addSavedQuote(
        SavedQuote(
          id: 'quote-old-account',
          workerName: '旧账号工人',
          tradeName: '木工',
          items: const [
            QuoteLineItem(
              name: '旧账号木工项目',
              categoryName: '人工费用',
              unitPrice: 200,
              unit: '项',
              quantity: 1,
            ),
          ],
          grandTotal: 200,
          savedAt: DateTime.utc(2026, 8, 8),
        ),
      );
      await state.addChatMessage(
        'worker-old-account',
        ChatMessage(
          id: 'chat-old-account',
          workerId: 'worker-old-account',
          workerName: '旧账号工人',
          text: '旧账号聊天预览',
          isMe: false,
          createdAt: DateTime.utc(2026, 8, 8),
        ),
      );
      await state.updateSettings(
        state.settings.copyWith(
          pushNotifications: false,
          projectNotifications: false,
          marketingNotifications: true,
          hidePhone: false,
          darkMode: true,
        ),
      );

      expect(state.appointments, isNotEmpty);
      expect(state.messages, isNotEmpty);
      expect(state.savedQuotes, isNotEmpty);
      expect(state.chatMessages, isNotEmpty);
      expect(state.profile.name, '旧账号业主');

      await state.logout();

      expect(state.isLoggedIn, isFalse);
      expect(await sessions.read(), isNull);
      expect(state.appointments, isEmpty);
      expect(state.messages, isEmpty);
      expect(state.savedQuotes, isEmpty);
      expect(state.chatMessages, isEmpty);
      expect(state.profile.name, isEmpty);
      expect(state.settings.pushNotifications, isTrue);
      expect(state.settings.projectNotifications, isTrue);
      expect(state.settings.marketingNotifications, isFalse);
      expect(state.settings.hidePhone, isTrue);
      expect(state.settings.darkMode, isTrue);

      final persisted =
          jsonDecode(store.getString(OwnerAppState.documentKey)!)
              as Map<String, dynamic>;
      expect(persisted['appointments'], isEmpty);
      expect(persisted['messages'], isEmpty);
      expect(persisted['savedQuotes'], isEmpty);
      expect(persisted['chatMessages'], isEmpty);

      final restored = await OwnerAppState.memory(
        store: store,
        sessionStore: sessions,
        profileApi: const _OwnerProfileApiStub(),
        bookingApi: const _OwnerBookingApiStub([]),
      );
      expect(restored.appointments, isEmpty);
      expect(restored.messages, isEmpty);
      expect(restored.savedQuotes, isEmpty);
      expect(restored.chatMessages, isEmpty);
      expect(restored.profile.name, isEmpty);
      expect(restored.settings.pushNotifications, isTrue);
      expect(restored.settings.projectNotifications, isTrue);
      expect(restored.settings.marketingNotifications, isFalse);
      expect(restored.settings.hidePhone, isTrue);
      expect(restored.settings.darkMode, isTrue);
    },
  );

  test(
    'owner logout rejects in-flight profile address and booking responses',
    () async {
      final store = MemoryOwnerStore();
      final sessions = MemoryAuthSessionStore();
      final profileResult = Completer<RemoteOwnerProfile>();
      final addressResult = Completer<List<RemoteOwnerAddress>>();
      final bookingResult = Completer<List<RemoteOwnerBooking>>();
      final state = await OwnerAppState.memory(
        store: store,
        sessionStore: sessions,
        profileApi: _SequencedOwnerProfileApi(profileResult),
        addressApi: _SequencedOwnerAddressApi(addressResult),
        bookingApi: _ControlledOwnerBookingApi(bookingResult),
      );
      await state.completeAuthenticatedLogin(_loginResponse);
      final profileFetch = state.refreshOwnerProfile();
      final addressFetch = state.refreshOwnerAddresses();
      final bookingFetch = state.fetchRemoteBookings();
      await Future<void>.delayed(Duration.zero);

      await state.logout();
      profileResult.complete(_lateOldProfile);
      addressResult.complete([_lateOldAddress]);
      bookingResult.complete([_privacyBooking]);
      await Future.wait([profileFetch, addressFetch, bookingFetch]);

      expect(state.profile.name, isEmpty);
      expect(state.addresses, isEmpty);
      expect(state.appointments, isEmpty);
      expect(state.messages, isEmpty);

      final restored = await OwnerAppState.memory(
        store: store,
        sessionStore: sessions,
        profileApi: const _OwnerProfileApiStub(),
        bookingApi: const _OwnerBookingApiStub([]),
      );
      expect(restored.profile.name, isEmpty);
      expect(restored.addresses, isEmpty);
      expect(restored.appointments, isEmpty);
      expect(restored.messages, isEmpty);
    },
  );

  test(
    'owner startup without a valid session clears persisted user data',
    () async {
      final store = MemoryOwnerStore();
      final sessions = MemoryAuthSessionStore();
      final state = await OwnerAppState.memory(
        store: store,
        sessionStore: sessions,
        profileApi: const _OwnerProfileApiStub(),
        bookingApi: _OwnerBookingApiStub([_privacyBooking]),
      );
      await state.completeAuthenticatedLogin(_loginResponse);
      await state.fetchRemoteBookings();
      await state.addSavedQuote(_oldSavedQuote);
      await state.addChatMessage('worker-old-account', _oldChatMessage);
      await sessions.clear();

      final restored = await OwnerAppState.memory(
        store: store,
        sessionStore: sessions,
        profileApi: const _OwnerProfileApiStub(),
        bookingApi: const _OwnerBookingApiStub([]),
      );

      expect(restored.isLoggedIn, isFalse);
      expect(restored.profile.name, isEmpty);
      expect(restored.appointments, isEmpty);
      expect(restored.messages, isEmpty);
      expect(restored.savedQuotes, isEmpty);
      expect(restored.chatMessages, isEmpty);
      final persisted =
          jsonDecode(store.getString(OwnerAppState.documentKey)!)
              as Map<String, dynamic>;
      expect(persisted['appointments'], isEmpty);
      expect(persisted['messages'], isEmpty);
    },
  );

  test('owner account switch starts from an empty user domain', () async {
    final store = MemoryOwnerStore();
    final sessions = MemoryAuthSessionStore();
    final state = await OwnerAppState.memory(
      store: store,
      sessionStore: sessions,
      profileApi: const _SwitchingOwnerProfileApi(),
      bookingApi: const _SwitchingOwnerBookingApi(),
    );
    await state.completeAuthenticatedLogin(_loginResponse);
    await state.fetchRemoteBookings();
    await state.addSavedQuote(_oldSavedQuote);
    await state.addChatMessage('worker-old-account', _oldChatMessage);

    await state.completeAuthenticatedLogin(_nextLoginResponse);

    expect(state.profile.name, '新账号业主');
    expect(state.appointments, isEmpty);
    expect(state.messages, isEmpty);
    expect(state.savedQuotes, isEmpty);
    expect(state.chatMessages, isEmpty);
    expect(state.bookedWorkers, isEmpty);
  });

  test('owner logout rejects in-flight authenticated writes', () async {
    final profileResult = Completer<RemoteOwnerProfile>();
    final addressResult = Completer<RemoteOwnerAddress>();
    final bookingResult = Completer<RemoteOwnerBooking>();
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(),
      profileApi: _ControlledOwnerWriteProfileApi(profileResult),
      addressApi: _ControlledOwnerWriteAddressApi(addressResult),
      bookingApi: _ControlledOwnerWriteBookingApi(bookingResult),
    );
    await state.completeAuthenticatedLogin(_loginResponse);
    final profileWrite = state.updateProfile(
      state.profile.copyWith(name: '旧账号延迟资料'),
    );
    final addressWrite = state.addAddress(
      const OwnerAddress(
        id: 'address-write-old-account',
        recipient: '旧账号业主',
        phone: '13900000000',
        province: '四川省',
        city: '成都市',
        district: '武侯区',
        detail: '旧账号新增地址',
      ),
    );
    final bookingWrite = state.bookWorker(
      _oldBookedWorker,
      remoteWorkerUserId: 'worker-old-account',
      houseInfo: _houseInfo,
    );
    await Future<void>.delayed(Duration.zero);

    await state.logout();
    profileResult.complete(_lateOldProfile);
    addressResult.complete(_lateOldAddress);
    bookingResult.complete(_privacyBooking);
    await Future.wait([profileWrite, addressWrite, bookingWrite]);

    expect(state.profile.name, isEmpty);
    expect(state.addresses, isEmpty);
    expect(state.bookedWorkers, isEmpty);
    expect(state.appointments, isEmpty);
    expect(state.messages, isEmpty);
  });
}

const _loginResponse = OwnerLoginResponse(
  accessToken: 'owner-jwt',
  tokenType: 'Bearer',
  expiresInSeconds: 3600,
  user: AuthUser(
    id: 'owner-old-account',
    phone: '13900000000',
    status: 'ACTIVE',
    roles: ['OWNER'],
  ),
);

const _nextLoginResponse = OwnerLoginResponse(
  accessToken: 'owner-next-jwt',
  tokenType: 'Bearer',
  expiresInSeconds: 3600,
  user: AuthUser(
    id: 'owner-next-account',
    phone: '13900000001',
    status: 'ACTIVE',
    roles: ['OWNER'],
  ),
);

final _oldSavedQuote = SavedQuote(
  id: 'quote-old-account',
  workerName: '旧账号工人',
  tradeName: '木工',
  items: const [],
  grandTotal: 200,
  savedAt: DateTime.utc(2026, 8, 8),
);

final _oldChatMessage = ChatMessage(
  id: 'chat-old-account',
  workerId: 'worker-old-account',
  workerName: '旧账号工人',
  text: '旧账号聊天预览',
  isMe: false,
  createdAt: DateTime.utc(2026, 8, 8),
);

const _oldBookedWorker = BookedWorker(
  id: 'worker-old-account',
  name: '旧账号工人',
  trade: 'carpentry',
  phaseName: '木工阶段',
  phaseIndex: 4,
  rating: 5,
  completedOrders: 10,
  years: 8,
  avatarEmoji: '木',
  skills: ['木工'],
);

const _houseInfo = HouseInfo(
  areaSqm: 88,
  bedroomCount: 3,
  livingRoomCount: 2,
  kitchenCount: 1,
  bathroomCount: 2,
);

final _privacyBooking = RemoteOwnerBooking(
  id: 'booking-old-account',
  ownerUserId: 'owner-old-account',
  serviceRequestId: 'request-old-account',
  workerUserId: 'worker-old-account',
  workerName: '旧账号工人',
  trade: 'carpentry',
  serviceCity: '成都',
  serviceAddress: '旧账号地址',
  remark: '旧账号预约',
  status: 'PENDING',
  createdAt: DateTime.utc(2026, 8, 8),
  updatedAt: DateTime.utc(2026, 8, 8),
);

const _lateOldProfile = RemoteOwnerProfile(
  userId: 'owner-old-account',
  phone: '13900000000',
  name: '延迟返回的旧账号业主',
  city: '成都',
  decorationType: null,
  address: null,
  area: null,
  profileComplete: true,
);

final _lateOldAddress = RemoteOwnerAddress(
  id: 'address-old-account',
  recipient: '旧账号业主',
  phone: '13900000000',
  province: '四川省',
  city: '成都市',
  district: '武侯区',
  detail: '旧账号地址',
  isDefault: true,
  createdAt: DateTime.utc(2026, 8, 8),
  updatedAt: DateTime.utc(2026, 8, 8),
);

final class _OwnerProfileApiStub implements OwnerProfileApi {
  const _OwnerProfileApiStub();

  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) async =>
      const RemoteOwnerProfile(
        userId: 'owner-old-account',
        phone: '13900000000',
        name: '旧账号业主',
        city: '成都',
        decorationType: null,
        address: null,
        area: null,
        profileComplete: true,
      );

  @override
  Future<RemoteOwnerProfile> updateCurrent(
    String accessToken,
    OwnerProfileUpdate request,
  ) => throw UnimplementedError();
}

final class _OwnerBookingApiStub implements OwnerBookingApi {
  const _OwnerBookingApiStub(this.bookings);

  final List<RemoteOwnerBooking> bookings;

  @override
  Future<List<RemoteOwnerBooking>> listOwnerBookings(
    String accessToken,
  ) async => bookings;

  @override
  Future<RemoteOwnerBooking> createBooking(
    String accessToken,
    OwnerBookingCreateRequest request,
  ) => throw UnimplementedError();

  @override
  Future<RemoteOwnerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) => throw UnimplementedError();
}

final class _SequencedOwnerProfileApi implements OwnerProfileApi {
  _SequencedOwnerProfileApi(this.lateResult);

  final Completer<RemoteOwnerProfile> lateResult;
  int _getCount = 0;

  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) async {
    _getCount += 1;
    if (_getCount == 1) {
      return const _OwnerProfileApiStub().getCurrent(accessToken);
    }
    return lateResult.future;
  }

  @override
  Future<RemoteOwnerProfile> updateCurrent(
    String accessToken,
    OwnerProfileUpdate request,
  ) => throw UnimplementedError();
}

final class _SequencedOwnerAddressApi implements OwnerAddressApi {
  _SequencedOwnerAddressApi(this.lateResult);

  final Completer<List<RemoteOwnerAddress>> lateResult;
  int _listCount = 0;

  @override
  Future<List<RemoteOwnerAddress>> list(String accessToken) async {
    _listCount += 1;
    if (_listCount == 1) return const [];
    return lateResult.future;
  }

  @override
  Future<RemoteOwnerAddress> create(
    String accessToken,
    OwnerAddressDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<RemoteOwnerAddress> update(
    String accessToken,
    String addressId,
    OwnerAddressDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<RemoteOwnerAddress> setDefault(String accessToken, String addressId) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String accessToken, String addressId) =>
      throw UnimplementedError();
}

final class _ControlledOwnerBookingApi implements OwnerBookingApi {
  _ControlledOwnerBookingApi(this.result);

  final Completer<List<RemoteOwnerBooking>> result;

  @override
  Future<List<RemoteOwnerBooking>> listOwnerBookings(String accessToken) =>
      result.future;

  @override
  Future<RemoteOwnerBooking> createBooking(
    String accessToken,
    OwnerBookingCreateRequest request,
  ) => throw UnimplementedError();

  @override
  Future<RemoteOwnerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) => throw UnimplementedError();
}

final class _SwitchingOwnerProfileApi implements OwnerProfileApi {
  const _SwitchingOwnerProfileApi();

  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) async =>
      accessToken == _nextLoginResponse.accessToken
      ? const RemoteOwnerProfile(
          userId: 'owner-next-account',
          phone: '13900000001',
          name: '新账号业主',
          city: '成都',
          decorationType: null,
          address: null,
          area: null,
          profileComplete: true,
        )
      : const _OwnerProfileApiStub().getCurrent(accessToken);

  @override
  Future<RemoteOwnerProfile> updateCurrent(
    String accessToken,
    OwnerProfileUpdate request,
  ) => throw UnimplementedError();
}

final class _SwitchingOwnerBookingApi implements OwnerBookingApi {
  const _SwitchingOwnerBookingApi();

  @override
  Future<List<RemoteOwnerBooking>> listOwnerBookings(
    String accessToken,
  ) async => accessToken == _nextLoginResponse.accessToken
      ? const []
      : [_privacyBooking];

  @override
  Future<RemoteOwnerBooking> createBooking(
    String accessToken,
    OwnerBookingCreateRequest request,
  ) => throw UnimplementedError();

  @override
  Future<RemoteOwnerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) => throw UnimplementedError();
}

final class _ControlledOwnerWriteProfileApi implements OwnerProfileApi {
  _ControlledOwnerWriteProfileApi(this.updateResult);

  final Completer<RemoteOwnerProfile> updateResult;

  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) =>
      const _OwnerProfileApiStub().getCurrent(accessToken);

  @override
  Future<RemoteOwnerProfile> updateCurrent(
    String accessToken,
    OwnerProfileUpdate request,
  ) => updateResult.future;
}

final class _ControlledOwnerWriteAddressApi implements OwnerAddressApi {
  _ControlledOwnerWriteAddressApi(this.createResult);

  final Completer<RemoteOwnerAddress> createResult;

  @override
  Future<List<RemoteOwnerAddress>> list(String accessToken) async => [
    _lateOldAddress,
  ];

  @override
  Future<RemoteOwnerAddress> create(
    String accessToken,
    OwnerAddressDraft draft,
  ) => createResult.future;

  @override
  Future<RemoteOwnerAddress> update(
    String accessToken,
    String addressId,
    OwnerAddressDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<RemoteOwnerAddress> setDefault(String accessToken, String addressId) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String accessToken, String addressId) =>
      throw UnimplementedError();
}

final class _ControlledOwnerWriteBookingApi implements OwnerBookingApi {
  _ControlledOwnerWriteBookingApi(this.createResult);

  final Completer<RemoteOwnerBooking> createResult;

  @override
  Future<List<RemoteOwnerBooking>> listOwnerBookings(
    String accessToken,
  ) async => const [];

  @override
  Future<RemoteOwnerBooking> createBooking(
    String accessToken,
    OwnerBookingCreateRequest request,
  ) => createResult.future;

  @override
  Future<RemoteOwnerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) => throw UnimplementedError();
}
