import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/models/renovation.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';

void main() {
  test(
    'worker online login stores secure session and logout clears it',
    () async {
      final sessions = MemoryAuthSessionStore();
      final state = await WorkerAppState.memory(sessionStore: sessions);
      const response = OwnerLoginResponse(
        accessToken: 'worker-jwt',
        tokenType: 'Bearer',
        expiresInSeconds: 3600,
        user: AuthUser(
          id: 'worker-id',
          phone: '13800138102',
          status: 'ACTIVE',
          roles: ['WORKER'],
        ),
      );

      await state.loginOnline(response);

      expect(state.isLoggedIn, isTrue);
      expect((await sessions.read())?.accessToken, 'worker-jwt');
      expect(state.toJson(), isNot(contains('accessToken')));

      await state.logout();

      expect(state.isLoggedIn, isFalse);
      expect(await sessions.read(), isNull);
    },
  );

  test(
    'worker profile is persisted remotely before local state changes',
    () async {
      final sessions = MemoryAuthSessionStore();
      final state = await WorkerAppState.memory(sessionStore: sessions);
      final api = _RecordingWorkerProfileApi();
      await state.loginOnline(_loginResponse);
      final next = state.profile.copyWith(
        name: '张师傅',
        serviceCity: '成都',
        trade: Trade.plumbing,
        tradeSelected: true,
        experienceYears: 8,
        dailyRate: 500,
        bio: '擅长旧房水电改造',
      );

      await state.updateProfile(next, api: api);

      expect(api.updatedBody, {
        'name': '张师傅',
        'serviceCity': '成都',
        'primaryTrade': Trade.plumbing.name,
        'experienceYears': 8,
        'dailyRate': 500.0,
        'bio': '擅长旧房水电改造',
      });
      expect(state.profile.isProfileComplete, isTrue);
      expect(state.profile.name, '张师傅');
    },
  );

  test('failed remote profile save leaves local profile unchanged', () async {
    final state = await WorkerAppState.memory();
    await state.loginOnline(_loginResponse);
    final before = state.profile;

    await expectLater(
      state.updateProfile(
        before.copyWith(name: '不应保存'),
        api: _RecordingWorkerProfileApi(failUpdate: true),
      ),
      throwsA(isA<AuthApiException>()),
    );

    expect(state.profile.name, before.name);
  });
}

const _loginResponse = OwnerLoginResponse(
  accessToken: 'worker-jwt',
  tokenType: 'Bearer',
  expiresInSeconds: 3600,
  user: AuthUser(
    id: 'worker-id',
    phone: '13800138102',
    status: 'ACTIVE',
    roles: ['WORKER'],
  ),
);

final class _RecordingWorkerProfileApi implements OwnerAuthApi {
  _RecordingWorkerProfileApi({this.failUpdate = false});

  final bool failUpdate;
  Map<String, dynamic>? updatedBody;

  @override
  Future<void> updateWorkerProfile(
    String token,
    Map<String, dynamic> body,
  ) async {
    if (failUpdate) {
      throw const AuthApiException(code: 'UPDATE_FAILED', message: '更新资料失败');
    }
    updatedBody = Map<String, dynamic>.from(body);
  }

  @override
  Future<RemoteWorkerProfile> getWorkerProfile(String token) async =>
      const RemoteWorkerProfile(
        phone: '13800138102',
        name: '张师傅',
        serviceCity: '成都',
        primaryTrade: 'plumber',
        experienceYears: 8,
        dailyRate: 500,
        bio: '擅长旧房水电改造',
        profileComplete: true,
      );

  @override
  Future<OwnerLoginResponse> loginOwner(String phone, String code) =>
      throw UnimplementedError();

  @override
  Future<OwnerLoginResponse> loginWorker(String phone, String code) =>
      throw UnimplementedError();

  @override
  Future<SmsCodeResponse> requestSmsCode(String phone) =>
      throw UnimplementedError();
}
