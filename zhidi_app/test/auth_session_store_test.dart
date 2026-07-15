import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';

void main() {
  test('saves a session before login and clears it on logout', () async {
    final sessions = MemoryAuthSessionStore();
    final state = await OwnerAppState.memory(
      sessionStore: sessions,
      profileApi: _ProfileApiStub(),
    );

    await state.completeAuthenticatedLogin(_ownerLoginResponse());

    expect(state.isLoggedIn, isTrue);
    expect(state.profile.phone, '16600000002');
    expect((await sessions.read())?.accessToken, 'jwt');

    await state.logout();

    expect(state.isLoggedIn, isFalse);
    expect(await sessions.read(), isNull);
  });

  test('does not mark the owner logged in when secure storage fails', () async {
    final state = await OwnerAppState.memory(
      sessionStore: _FailingSaveSessionStore(),
    );

    await expectLater(
      state.completeAuthenticatedLogin(_ownerLoginResponse()),
      throwsStateError,
    );

    expect(state.isLoggedIn, isFalse);
  });

  test('auth sessions round-trip without dropping identity fields', () {
    final session = AuthSession.fromLogin(
      _ownerLoginResponse(),
      issuedAt: DateTime.utc(2026, 7, 14),
    );

    final restored = AuthSession.fromJson(session.toJson());

    expect(restored.accessToken, 'jwt');
    expect(restored.userId, '01904f24-3f5b-7000-8000-000000000001');
    expect(restored.phone, '16600000002');
    expect(restored.roles, ['OWNER']);
    expect(restored.expiresAt, DateTime.utc(2026, 8, 13));
  });
}

OwnerLoginResponse _ownerLoginResponse() => const OwnerLoginResponse(
  accessToken: 'jwt',
  tokenType: 'Bearer',
  expiresInSeconds: 2_592_000,
  user: AuthUser(
    id: '01904f24-3f5b-7000-8000-000000000001',
    phone: '16600000002',
    status: 'ACTIVE',
    roles: ['OWNER'],
  ),
);

final class _FailingSaveSessionStore implements AuthSessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<void> save(AuthSession session) =>
      Future.error(StateError('Keychain unavailable'));
}

final class _ProfileApiStub implements OwnerProfileApi {
  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) async =>
      const RemoteOwnerProfile(
        userId: '01904f24-3f5b-7000-8000-000000000001',
        phone: '16600000002',
        name: '王先生',
        city: '成都',
        decorationType: null,
        address: null,
        area: null,
        profileComplete: false,
      );

  @override
  Future<RemoteOwnerProfile> updateCurrent(
    String accessToken,
    OwnerProfileUpdate request,
  ) => throw UnimplementedError();
}
