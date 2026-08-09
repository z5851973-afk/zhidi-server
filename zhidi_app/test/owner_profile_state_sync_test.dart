import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/owner_address_api_client.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';

void main() {
  group('OwnerAppState profile synchronization', () {
    test(
      'valid restored session GET maps and persists every remote field',
      () async {
        final store = MemoryOwnerStore();
        final sessionStore = MemoryAuthSessionStore(validSession());
        final api = FakeOwnerProfileApi(getResult: remoteProfile());
        final state = await OwnerAppState.memory(
          store: store,
          sessionStore: sessionStore,
          profileApi: api,
          bookingApi: _NoopBookingApi(),
        );

        expect(api.getTokens, ['token']);
        expect(state.profile.toJson(), {
          'name': '服务端姓名',
          'city': '上海',
          'phone': '13900000000',
          'avatarUrl': '/uploads/owner-avatar/server.webp',
          'gender': 'FEMALE',
          'decorationType': '旧房翻新',
          'address': '浦东新区',
          'area': 88.5,
        });
        final restored = await OwnerAppState.memory(
          store: store,
          sessionStore: sessionStore,
          profileApi: api,
          bookingApi: _NoopBookingApi(),
        );
        expect(restored.profile.toJson(), state.profile.toJson());
      },
    );

    test('no session and expired session send no GET or PUT', () async {
      final api = FakeOwnerProfileApi(getResult: remoteProfile());
      final withoutSession = await OwnerAppState.memory(profileApi: api);
      await withoutSession.refreshOwnerProfile();
      await withoutSession.updateProfile(
        withoutSession.profile.copyWith(name: '本地编辑'),
      );

      final expiredStore = MemoryAuthSessionStore(
        validSession(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      final expired = await OwnerAppState.memory(
        sessionStore: expiredStore,
        profileApi: api,
      );
      await expired.refreshOwnerProfile();
      await expired.updateProfile(expired.profile.copyWith(name: '过期后本地编辑'));

      expect(api.getTokens, isEmpty);
      expect(api.updates, isEmpty);
      expect(await expiredStore.read(), isNull);
      expect(expired.isLoggedIn, isFalse);
    });

    test('refresh performs GET only and never uploads local data', () async {
      final api = FakeOwnerProfileApi(getResult: remoteProfile());
      final sessionStore = MemoryAuthSessionStore(validSession());
      final state = await OwnerAppState.memory(
        sessionStore: sessionStore,
        profileApi: api,
        bookingApi: _NoopBookingApi(),
      );
      expect(await sessionStore.read(), isNotNull);
      api.getTokens.clear();

      await state.refreshOwnerProfile();

      expect(api.getTokens, hasLength(1));
      expect(api.updates, isEmpty);
    });

    test(
      'onboarding PUT uses server response and failure preserves old profile',
      () async {
        final api = FakeOwnerProfileApi(
          getResult: remoteProfile(),
          updateResult: updatedRemoteProfile(),
        );
        final state = await OwnerAppState.memory(
          sessionStore: MemoryAuthSessionStore(validSession()),
          profileApi: api,
          bookingApi: _NoopBookingApi(),
        );
        await state.completeOnboarding(
          decorationType: '请求类型',
          address: '请求地址',
          area: 66,
        );
        expect(api.updates, hasLength(1));
        expect(api.updates.single.toJson(), {
          'name': '服务端姓名',
          'city': '上海',
          'avatarUrl': '/uploads/owner-avatar/server.webp',
          'gender': 'FEMALE',
          'decorationType': '请求类型',
          'address': '请求地址',
          'area': 66.0,
        });
        expect(state.profile.name, 'PUT 返回姓名');
        expect(state.profile.address, 'PUT 返回地址');

        final before = state.profile.toJson();
        api.updateError = const AuthApiException(
          code: 'SERVER_ERROR',
          message: '失败',
          statusCode: 500,
        );
        await expectLater(
          state.completeOnboarding(
            decorationType: '另一类型',
            address: '另一地址',
            area: 99,
          ),
          throwsA(isA<AuthApiException>()),
        );
        expect(state.profile.toJson(), before);
      },
    );

    test(
      'onboarding cannot report success without a valid server session',
      () async {
        final state = await OwnerAppState.memory(
          profileApi: FakeOwnerProfileApi(getResult: remoteProfile()),
        );

        await expectLater(
          state.completeOnboarding(
            name: '刘先生',
            decorationType: '新房装修',
            address: '麓湖 1 栋 101',
            area: 96,
          ),
          throwsA(
            isA<AuthApiException>().having(
              (error) => error.code,
              'code',
              'NOT_AUTHENTICATED',
            ),
          ),
        );
        expect(state.isLoggedIn, isFalse);
        expect(state.profile.address, isNot('麓湖 1 栋 101'));
      },
    );

    test(
      'onboarding uses the supplied name when remote profile has no name',
      () async {
        final api = FakeOwnerProfileApi(
          getResult: const RemoteOwnerProfile(
            userId: 'user-1',
            phone: '13900000000',
            name: null,
            city: '成都',
            avatarUrl: null,
            gender: null,
            decorationType: null,
            address: null,
            area: null,
            profileComplete: false,
          ),
          updateResult: updatedRemoteProfile(),
        );
        final state = await OwnerAppState.memory(
          sessionStore: MemoryAuthSessionStore(validSession()),
          profileApi: api,
          bookingApi: _NoopBookingApi(),
        );

        await state.completeOnboarding(
          name: '刘先生',
          decorationType: '新房装修',
          address: '麓湖 1 栋 101',
          area: 96,
        );

        expect(api.updates.single.name, '刘先生');
        expect(api.updates.single.decorationType, '新房装修');
      },
    );

    test(
      'edit PUT uses server response and failure preserves old profile',
      () async {
        final api = FakeOwnerProfileApi(getResult: remoteProfile());
        final state = await OwnerAppState.memory(
          sessionStore: MemoryAuthSessionStore(validSession()),
          profileApi: api,
          bookingApi: _NoopBookingApi(),
        );
        await state.updateProfile(state.profile.copyWith(name: '请求姓名'));
        expect(api.updates.single.name, '请求姓名');
        expect(state.profile.name, '服务端姓名');

        final before = state.profile.toJson();
        api.updateError = const AuthApiException(
          code: 'NETWORK_UNAVAILABLE',
          message: '断网',
        );
        await expectLater(
          state.updateProfile(state.profile.copyWith(name: '不应保存')),
          throwsA(isA<AuthApiException>()),
        );
        expect(state.profile.toJson(), before);
      },
    );

    test(
      '401 during PUT clears session, persists logout, and rethrows',
      () async {
        final ownerStore = MemoryOwnerStore();
        final sessionStore = MemoryAuthSessionStore(validSession());
        final api = FakeOwnerProfileApi(getResult: remoteProfile())
          ..updateError = const AuthApiException(
            code: 'UNAUTHORIZED',
            message: '登录失效',
            statusCode: 401,
          );
        final state = await OwnerAppState.memory(
          store: ownerStore,
          sessionStore: sessionStore,
          profileApi: api,
          bookingApi: _NoopBookingApi(),
        );

        await expectLater(
          state.updateProfile(state.profile.copyWith(name: '请求姓名')),
          throwsA(isA<AuthApiException>()),
        );
        expect(await sessionStore.read(), isNull);
        expect(state.isLoggedIn, isFalse);
        final restored = await OwnerAppState.memory(
          store: ownerStore,
          profileApi: api,
        );
        expect(restored.isLoggedIn, isFalse);
      },
    );

    test(
      '401 during GET clears session and leaves authenticated login logged out',
      () async {
        final sessionStore = MemoryAuthSessionStore();
        final api = FakeOwnerProfileApi(getResult: remoteProfile())
          ..getError = const AuthApiException(
            code: 'UNAUTHORIZED',
            message: '登录失效',
            statusCode: 401,
          );
        final state = await OwnerAppState.memory(
          sessionStore: sessionStore,
          profileApi: api,
        );

        await state.completeAuthenticatedLogin(loginResponse());

        expect(await sessionStore.read(), isNull);
        expect(state.isLoggedIn, isFalse);
      },
    );

    test(
      'non-auth GET failure after login keeps saved login and local phone',
      () async {
        final sessionStore = MemoryAuthSessionStore();
        final api = FakeOwnerProfileApi(getResult: remoteProfile())
          ..getError = const AuthApiException(
            code: 'NETWORK_UNAVAILABLE',
            message: '断网',
          );
        final state = await OwnerAppState.memory(
          sessionStore: sessionStore,
          profileApi: api,
        );

        await state.completeAuthenticatedLogin(loginResponse());

        expect(await sessionStore.read(), isNotNull);
        expect(state.isLoggedIn, isTrue);
        expect(state.profile.phone, '13812345678');
      },
    );

    test('unexpected GET failure after login propagates', () async {
      final sessionStore = MemoryAuthSessionStore();
      final api = FakeOwnerProfileApi(getResult: remoteProfile())
        ..getError = StateError('意外错误');
      final state = await OwnerAppState.memory(
        sessionStore: sessionStore,
        profileApi: api,
      );

      await expectLater(
        state.completeAuthenticatedLogin(loginResponse()),
        throwsA(isA<StateError>()),
      );

      expect(await sessionStore.read(), isNotNull);
      expect(state.isLoggedIn, isTrue);
      expect(state.profile.phone, '13812345678');
    });

    test(
      'restored login replaces stale local addresses with the server list',
      () async {
        final empty = await OwnerAppState.memory();
        final store = MemoryOwnerStore();
        await store.setString(
          OwnerAppState.documentKey,
          jsonEncode({
            ...empty.toJson(),
            'addresses': [
              const OwnerAddress(
                id: 'stale-local-id',
                recipient: '旧联系人',
                phone: '13800138000',
                province: '旧省',
                city: '旧城市',
                district: '旧区',
                detail: '旧地址',
                isDefault: true,
              ).toJson(),
            ],
          }),
        );
        final addressApi = FakeOwnerAddressApi(
          listResult: [remoteAddress(id: 'server-id', isDefault: true)],
        );

        final state = await OwnerAppState.memory(
          store: store,
          sessionStore: MemoryAuthSessionStore(validSession()),
          profileApi: FakeOwnerProfileApi(getResult: remoteProfile()),
          addressApi: addressApi,
          bookingApi: _NoopBookingApi(),
        );

        expect(addressApi.listTokens, ['token']);
        expect(state.addresses, hasLength(1));
        expect(state.addresses.single.id, 'server-id');
        expect(state.addresses.single.province, '四川省');
        expect(state.addresses.single.isDefault, isTrue);
      },
    );

    test(
      'address writes only apply server responses and 401 logs out',
      () async {
        final sessionStore = MemoryAuthSessionStore(validSession());
        final addressApi = FakeOwnerAddressApi(listResult: const []);
        final state = await OwnerAppState.memory(
          sessionStore: sessionStore,
          profileApi: FakeOwnerProfileApi(getResult: remoteProfile()),
          addressApi: addressApi,
          bookingApi: _NoopBookingApi(),
        );
        addressApi.createResult = remoteAddress(
          id: 'server-created-id',
          isDefault: true,
        );

        await state.addAddress(
          const OwnerAddress(
            id: 'temporary-local-id',
            recipient: '林先生',
            phone: '13800138201',
            province: '四川省',
            city: '成都市',
            district: '武侯区',
            detail: '科华路 1 号',
          ),
        );

        expect(addressApi.creates, hasLength(1));
        expect(state.addresses.single.id, 'server-created-id');
        addressApi.deleteError = const AuthApiException(
          code: 'UNAUTHORIZED',
          message: '登录失效',
          statusCode: 401,
        );

        await expectLater(
          state.deleteAddress('server-created-id'),
          throwsA(isA<AuthApiException>()),
        );
        expect(state.addresses, isEmpty);
        expect(await sessionStore.read(), isNull);
        expect(state.isLoggedIn, isFalse);
      },
    );
  });
}

final class FakeOwnerProfileApi implements OwnerProfileApi {
  FakeOwnerProfileApi({
    required this.getResult,
    RemoteOwnerProfile? updateResult,
  }) : updateResult = updateResult ?? getResult;

  final RemoteOwnerProfile getResult;
  final RemoteOwnerProfile updateResult;
  Object? getError;
  Object? updateError;
  final List<String> getTokens = [];
  final List<OwnerProfileUpdate> updates = [];

  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) async {
    getTokens.add(accessToken);
    if (getError case final error?) throw error;
    return getResult;
  }

  @override
  Future<RemoteOwnerProfile> updateCurrent(
    String accessToken,
    OwnerProfileUpdate request,
  ) async {
    updates.add(request);
    if (updateError case final error?) throw error;
    return updateResult;
  }
}

final class _NoopBookingApi implements OwnerBookingApi {
  @override
  Future<List<RemoteOwnerBooking>> listOwnerBookings(
    String accessToken,
  ) async => const [];

  @override
  Future<RemoteOwnerBooking> createBooking(
    String accessToken,
    OwnerBookingCreateRequest request,
  ) => throw UnsupportedError('not used by profile tests');

  @override
  Future<RemoteOwnerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) => throw UnsupportedError('not used by profile tests');
}

final class FakeOwnerAddressApi implements OwnerAddressApi {
  FakeOwnerAddressApi({required this.listResult});

  final List<RemoteOwnerAddress> listResult;
  RemoteOwnerAddress? createResult;
  Object? deleteError;
  final List<String> listTokens = [];
  final List<OwnerAddressDraft> creates = [];

  @override
  Future<List<RemoteOwnerAddress>> list(String accessToken) async {
    listTokens.add(accessToken);
    return listResult;
  }

  @override
  Future<RemoteOwnerAddress> create(
    String accessToken,
    OwnerAddressDraft draft,
  ) async {
    creates.add(draft);
    return createResult ?? listResult.first;
  }

  @override
  Future<RemoteOwnerAddress> update(
    String accessToken,
    String addressId,
    OwnerAddressDraft draft,
  ) => throw UnsupportedError('not used');

  @override
  Future<RemoteOwnerAddress> setDefault(String accessToken, String addressId) =>
      throw UnsupportedError('not used');

  @override
  Future<void> delete(String accessToken, String addressId) async {
    if (deleteError case final error?) throw error;
  }
}

AuthSession validSession({DateTime? expiresAt}) => AuthSession(
  accessToken: 'token',
  tokenType: 'Bearer',
  expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
  userId: 'user-1',
  phone: '13812345678',
  roles: const ['OWNER'],
);

OwnerLoginResponse loginResponse() => const OwnerLoginResponse(
  accessToken: 'new-token',
  tokenType: 'Bearer',
  expiresInSeconds: 3600,
  user: AuthUser(
    id: 'user-1',
    phone: '13812345678',
    status: 'ACTIVE',
    roles: ['OWNER'],
  ),
);

RemoteOwnerProfile remoteProfile() => const RemoteOwnerProfile(
  userId: 'user-1',
  phone: '13900000000',
  name: '服务端姓名',
  city: '上海',
  avatarUrl: '/uploads/owner-avatar/server.webp',
  gender: 'FEMALE',
  decorationType: '旧房翻新',
  address: '浦东新区',
  area: 88.5,
  profileComplete: true,
);

RemoteOwnerProfile updatedRemoteProfile() => const RemoteOwnerProfile(
  userId: 'user-1',
  phone: '13700000000',
  name: 'PUT 返回姓名',
  city: '杭州',
  avatarUrl: '/uploads/owner-avatar/updated.webp',
  gender: 'UNDISCLOSED',
  decorationType: '服务端类型',
  address: 'PUT 返回地址',
  area: 77.5,
  profileComplete: true,
);

RemoteOwnerAddress remoteAddress({
  required String id,
  bool isDefault = false,
}) => RemoteOwnerAddress(
  id: id,
  recipient: '林先生',
  phone: '13800138201',
  province: '四川省',
  city: '成都市',
  district: '武侯区',
  detail: '科华路 1 号',
  isDefault: isDefault,
  createdAt: DateTime.utc(2026, 8, 2, 8),
  updatedAt: DateTime.utc(2026, 8, 2, 9),
);
