import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/auth/onboarding_page.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';

void main() {
  testWidgets('start button enables as soon as required text fields change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = await OwnerAppState.memory();
    await state.updateProfile(state.profile.copyWith(phone: '16600000888'));

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: const MaterialApp(home: OnboardingPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('onboarding-name-field')),
      '测试业主',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-address-field')),
      'TestHome1-1',
    );
    await tester.tap(find.text('新房装修'));
    await tester.enterText(
      find.byKey(const Key('onboarding-area-field')),
      '90',
    );
    await tester.pump();

    final start = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '开始使用'),
    );
    expect(start.onPressed, isNotNull);
  });

  testWidgets('submit waits for remote save and prevents duplicate taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var finished = 0;
    final api = _PendingOwnerProfileApi();
    final state = await OwnerAppState.memory(
      sessionStore: _MemorySessionStore(_validSession()),
      profileApi: api,
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(home: OnboardingPage(onDone: () => finished += 1)),
      ),
    );
    await _fillRequiredFields(tester);

    final buttonFinder = find.widgetWithText(ElevatedButton, '开始使用');
    await tester.ensureVisible(buttonFinder);
    await tester.tap(buttonFinder);
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(api.updates, hasLength(1));
    expect(api.updates.single.name, '刘先生');
    expect(finished, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    api.completeUpdate(_updatedRemoteProfile());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(finished, 1);
  });

  testWidgets('failed remote save stays on onboarding and keeps input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var finished = 0;
    final api = _PendingOwnerProfileApi()
      ..updateError = const AuthApiException(
        code: 'SERVER_ERROR',
        message: '保存失败',
        statusCode: 500,
      );
    final state = await OwnerAppState.memory(
      sessionStore: _MemorySessionStore(_validSession()),
      profileApi: api,
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(home: OnboardingPage(onDone: () => finished += 1)),
      ),
    );
    await _fillRequiredFields(tester);

    final buttonFinder = find.widgetWithText(ElevatedButton, '开始使用');
    await tester.ensureVisible(buttonFinder);
    await tester.tap(buttonFinder);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(api.updates, hasLength(1));
    expect(finished, 0);
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.text('保存失败，请稍后重试'), findsOneWidget);
    expect(find.text('麓湖 1 栋 101'), findsOneWidget);
    expect(find.text('96'), findsOneWidget);
  });
}

Future<void> _fillRequiredFields(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('onboarding-name-field')), '刘先生');
  await tester.enterText(
    find.byKey(const Key('onboarding-address-field')),
    '麓湖 1 栋 101',
  );
  await tester.tap(find.text('新房装修'));
  await tester.enterText(find.byKey(const Key('onboarding-area-field')), '96');
  await tester.pump();
}

final class _MemorySessionStore implements AuthSessionStore {
  _MemorySessionStore(this._session);

  AuthSession? _session;

  @override
  Future<void> clear() async {
    _session = null;
  }

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> save(AuthSession session) async {
    _session = session;
  }
}

final class _PendingOwnerProfileApi implements OwnerProfileApi {
  Object? updateError;
  final List<OwnerProfileUpdate> updates = [];
  Completer<RemoteOwnerProfile>? _pendingUpdate;

  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) async =>
      _remoteProfile();

  @override
  Future<RemoteOwnerProfile> updateCurrent(
    String accessToken,
    OwnerProfileUpdate request,
  ) {
    updates.add(request);
    if (updateError case final error?) return Future.error(error);
    final completer = Completer<RemoteOwnerProfile>();
    _pendingUpdate = completer;
    return completer.future;
  }

  void completeUpdate(RemoteOwnerProfile profile) {
    _pendingUpdate?.complete(profile);
  }
}

AuthSession _validSession() => AuthSession(
  accessToken: 'token',
  tokenType: 'Bearer',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  userId: 'user-1',
  phone: '13812345678',
  roles: const ['OWNER'],
);

RemoteOwnerProfile _remoteProfile() => const RemoteOwnerProfile(
  userId: 'user-1',
  phone: '13812345678',
  name: '王先生',
  city: '成都',
  decorationType: null,
  address: null,
  area: null,
  profileComplete: false,
);

RemoteOwnerProfile _updatedRemoteProfile() => const RemoteOwnerProfile(
  userId: 'user-1',
  phone: '13812345678',
  name: '服务端姓名',
  city: '服务端城市',
  decorationType: '新房装修',
  address: '麓湖 1 栋 101',
  area: 96,
  profileComplete: true,
);
