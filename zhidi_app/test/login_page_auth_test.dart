import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/auth/login_page.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';

void main() {
  testWidgets('fills development code and logs in through the backend', (
    tester,
  ) async {
    final api = _FakeOwnerAuthApi();
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(),
    );
    var loginDone = false;
    await _pumpLogin(
      tester,
      state: state,
      api: api,
      onLoginDone: () => loginDone = true,
    );

    await tester.enterText(find.byKey(const Key('login-phone')), '16600000002');
    await tester.tap(find.byKey(const Key('login-send-code')));
    await tester.pump();

    expect(find.text('开发验证码已自动填入'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('login-code')))
          .controller
          ?.text,
      '256438',
    );

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(api.loginCalls, [('16600000002', '256438')]);
    expect(state.isLoggedIn, isTrue);
    expect(loginDone, isTrue);
  });

  testWidgets('send failure does not start the countdown', (tester) async {
    final api = _FakeOwnerAuthApi(
      requestError: const AuthApiException(
        code: 'SMS_RATE_LIMITED',
        message: 'too many requests',
        statusCode: 429,
      ),
    );
    final state = await OwnerAppState.memory();
    await _pumpLogin(tester, state: state, api: api);
    await tester.enterText(find.byKey(const Key('login-phone')), '16600000002');

    await tester.tap(find.byKey(const Key('login-send-code')));
    await tester.pump();

    expect(find.text('验证码发送太频繁，请稍后再试'), findsOneWidget);
    expect(find.text('获取验证码'), findsOneWidget);
  });

  testWidgets('invalid code keeps the owner logged out', (tester) async {
    final api = _FakeOwnerAuthApi(
      loginError: const AuthApiException(
        code: 'SMS_CODE_INVALID',
        message: 'invalid code',
        statusCode: 400,
      ),
    );
    final state = await OwnerAppState.memory();
    var loginDone = false;
    await _pumpLogin(
      tester,
      state: state,
      api: api,
      onLoginDone: () => loginDone = true,
    );
    await tester.enterText(find.byKey(const Key('login-phone')), '16600000002');
    await tester.enterText(find.byKey(const Key('login-code')), '000000');

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();

    expect(find.text('验证码不正确，请重新输入'), findsOneWidget);
    expect(state.isLoggedIn, isFalse);
    expect(loginDone, isFalse);
  });

  testWidgets('repeated taps send only one SMS request', (tester) async {
    final pending = Completer<SmsCodeResponse>();
    final api = _FakeOwnerAuthApi(pendingRequest: pending);
    final state = await OwnerAppState.memory();
    await _pumpLogin(tester, state: state, api: api);
    await tester.enterText(find.byKey(const Key('login-phone')), '16600000002');

    await tester.tap(find.byKey(const Key('login-send-code')));
    await tester.tap(find.byKey(const Key('login-send-code')));
    await tester.pump();

    expect(api.requestCalls, ['16600000002']);

    pending.complete(
      const SmsCodeResponse(
        simulatedCode: '256438',
        expiresInSeconds: 300,
        retryAfterSeconds: 60,
      ),
    );
    await tester.pump();
  });
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  required OwnerAppState state,
  required OwnerAuthApi api,
  VoidCallback? onLoginDone,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    OwnerAppScope(
      state: state,
      child: MaterialApp(
        home: LoginPage(api: api, onLoginDone: onLoginDone),
      ),
    ),
  );
}

final class _FakeOwnerAuthApi implements OwnerAuthApi {
  _FakeOwnerAuthApi({this.requestError, this.loginError, this.pendingRequest});

  final AuthApiException? requestError;
  final AuthApiException? loginError;
  final Completer<SmsCodeResponse>? pendingRequest;
  final List<String> requestCalls = [];
  final List<(String, String)> loginCalls = [];

  @override
  Future<SmsCodeResponse> requestSmsCode(String phone) async {
    requestCalls.add(phone);
    if (requestError case final error?) throw error;
    if (pendingRequest case final pending?) return pending.future;
    return const SmsCodeResponse(
      simulatedCode: '256438',
      expiresInSeconds: 300,
      retryAfterSeconds: 60,
    );
  }

  @override
  Future<OwnerLoginResponse> loginOwner(String phone, String code) async {
    loginCalls.add((phone, code));
    if (loginError case final error?) throw error;
    return const OwnerLoginResponse(
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
  }

  @override
  Future<OwnerLoginResponse> loginWorker(String phone, String code) async {
    return const OwnerLoginResponse(
      accessToken: 'jwt-worker',
      tokenType: 'Bearer',
      expiresInSeconds: 2_592_000,
      user: AuthUser(
        id: '01904f24-3f5b-7000-8000-000000000002',
        phone: '16600000003',
        status: 'ACTIVE',
        roles: ['WORKER'],
      ),
    );
  }

  @override
  Future<RemoteWorkerProfile> getWorkerProfile(String token) async {
    return const RemoteWorkerProfile(phone: '16600000003');
  }

  @override
  Future<void> updateWorkerProfile(String token, Map<String, dynamic> body) async {}
}
