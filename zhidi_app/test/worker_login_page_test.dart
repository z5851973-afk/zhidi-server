import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/pages/worker/worker_login_page.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';

void main() {
  testWidgets('worker login does not upload local profile during login', (
    tester,
  ) async {
    final state = await WorkerAppState.memory(
      sessionStore: MemoryAuthSessionStore(),
    );
    final api = _HangingProfileSyncApi();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(home: WorkerLoginPage(api: api)),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), '19884199653');
    await tester.enterText(find.byType(TextField).at(1), '989427');
    await tester.tap(find.text('登录'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();

    expect(api.loginCalls, [('19884199653', '989427')]);
    expect(api.profileSyncStarted, isFalse);
    expect(state.isLoggedIn, isTrue);
    expect(state.accessToken, 'jwt-worker');
  });

  testWidgets('worker login maps invalid SMS code to Chinese message', (
    tester,
  ) async {
    final state = await WorkerAppState.memory(
      sessionStore: MemoryAuthSessionStore(),
    );
    final api = _FailingWorkerLoginApi(
      const AuthApiException(
        code: 'SMS_CODE_INVALID',
        message: 'verification code is invalid',
        statusCode: 400,
      ),
    );

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(home: WorkerLoginPage(api: api)),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), '19884199653');
    await tester.enterText(find.byType(TextField).at(1), '989427');
    await tester.tap(find.text('登录'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();

    expect(find.text('验证码不正确，请重新输入'), findsOneWidget);
    expect(find.text('verification code is invalid'), findsNothing);
  });

  testWidgets('worker login uses remote profile instead of stale local name', (
    tester,
  ) async {
    final state = await WorkerAppState.memory(
      sessionStore: MemoryAuthSessionStore(),
    );
    await state.updateProfileName('Bill');
    final api = _RemoteProfileWorkerLoginApi();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(home: WorkerLoginPage(api: api)),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), '19817313015');
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.tap(find.text('登录'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();

    expect(state.isLoggedIn, isTrue);
    expect(state.profile.name, '模拟器闭环工人');
    expect(api.profileSyncStarted, isFalse);
  });
}

final class _HangingProfileSyncApi implements OwnerAuthApi {
  final List<(String, String)> loginCalls = [];
  bool profileSyncStarted = false;

  @override
  Future<RemoteWorkerProfile> getWorkerProfile(String token) async {
    return const RemoteWorkerProfile(phone: '19884199653');
  }

  @override
  Future<SmsCodeResponse> requestSmsCode(String phone) async {
    return const SmsCodeResponse(
      simulatedCode: '989427',
      expiresInSeconds: 300,
      retryAfterSeconds: 60,
    );
  }

  @override
  Future<OwnerLoginResponse> loginOwner(String phone, String code) {
    throw UnimplementedError();
  }

  @override
  Future<OwnerLoginResponse> loginWorker(String phone, String code) async {
    loginCalls.add((phone, code));
    return const OwnerLoginResponse(
      accessToken: 'jwt-worker',
      tokenType: 'Bearer',
      expiresInSeconds: 2_592_000,
      user: AuthUser(
        id: '01904f24-3f5b-7000-8000-000000000002',
        phone: '19884199653',
        status: 'ACTIVE',
        roles: ['WORKER'],
      ),
    );
  }

  @override
  Future<void> updateWorkerProfile(String token, Map<String, dynamic> body) {
    profileSyncStarted = true;
    return Completer<void>().future;
  }
}

final class _FailingWorkerLoginApi implements OwnerAuthApi {
  const _FailingWorkerLoginApi(this.error);

  final AuthApiException error;

  @override
  Future<SmsCodeResponse> requestSmsCode(String phone) {
    throw UnimplementedError();
  }

  @override
  Future<OwnerLoginResponse> loginOwner(String phone, String code) {
    throw UnimplementedError();
  }

  @override
  Future<OwnerLoginResponse> loginWorker(String phone, String code) async {
    throw error;
  }

  @override
  Future<RemoteWorkerProfile> getWorkerProfile(String token) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateWorkerProfile(String token, Map<String, dynamic> body) {
    throw UnimplementedError();
  }
}

final class _RemoteProfileWorkerLoginApi implements OwnerAuthApi {
  bool profileSyncStarted = false;

  @override
  Future<SmsCodeResponse> requestSmsCode(String phone) {
    throw UnimplementedError();
  }

  @override
  Future<OwnerLoginResponse> loginOwner(String phone, String code) {
    throw UnimplementedError();
  }

  @override
  Future<OwnerLoginResponse> loginWorker(String phone, String code) async {
    return const OwnerLoginResponse(
      accessToken: 'jwt-worker',
      tokenType: 'Bearer',
      expiresInSeconds: 2_592_000,
      user: AuthUser(
        id: 'a5240406-ba20-499a-8ba8-6a4528195d05',
        phone: '19817313015',
        status: 'ACTIVE',
        roles: ['WORKER'],
      ),
    );
  }

  @override
  Future<RemoteWorkerProfile> getWorkerProfile(String token) async {
    return const RemoteWorkerProfile(
      userId: 'a5240406-ba20-499a-8ba8-6a4528195d05',
      phone: '19817313015',
      name: '模拟器闭环工人',
      primaryTrade: 'plumbing',
      experienceYears: 6,
      bio: '真实服务器资料',
    );
  }

  @override
  Future<void> updateWorkerProfile(String token, Map<String, dynamic> body) {
    profileSyncStarted = true;
    return Future<void>.value();
  }
}
