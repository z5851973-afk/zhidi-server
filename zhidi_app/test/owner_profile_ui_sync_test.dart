import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/auth/onboarding_page.dart';
import 'package:zhidi_app/pages/profile/edit_profile_page.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';

void main() {
  testWidgets('onboarding waits for remote save before finishing', (
    tester,
  ) async {
    usePhoneViewport(tester);
    var finished = 0;
    final api = PendingOwnerProfileApi();
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(validSession()),
      profileApi: api,
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(home: OnboardingPage(onDone: () => finished += 1)),
      ),
    );

    await fillOnboarding(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, '开始使用'));
    await tester.pump();

    expect(finished, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    api.completeUpdate(updatedRemoteProfile());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(finished, 1);
    expect(api.updates, hasLength(1));
    expect(api.updates.single.name, '刘先生');
  });

  testWidgets('onboarding failure keeps input and shows retry message', (
    tester,
  ) async {
    usePhoneViewport(tester);
    var finished = 0;
    final api = PendingOwnerProfileApi()
      ..updateError = const AuthApiException(
        code: 'SERVER_ERROR',
        message: '保存失败',
        statusCode: 500,
      );
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(validSession()),
      profileApi: api,
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(home: OnboardingPage(onDone: () => finished += 1)),
      ),
    );

    await fillOnboarding(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, '开始使用'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(finished, 0);
    expect(find.text('保存失败，请稍后重试'), findsOneWidget);
    expect(find.text('麓湖 1 栋 101'), findsOneWidget);
    expect(find.text('96'), findsOneWidget);
  });

  testWidgets('edit profile pops only after remote save response', (
    tester,
  ) async {
    final api = PendingOwnerProfileApi();
    final observer = RecordingNavigatorObserver();
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(validSession()),
      profileApi: api,
    );

    await pumpEditProfile(tester, state, observer);
    await tester.tap(find.text('打开编辑'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('profile-name-field')), '请求姓名');
    await tester.enterText(find.byKey(const Key('profile-city-field')), '杭州');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pump();

    expect(observer.popCount, 0);
    expect(find.text('保存中…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    api.completeUpdate(updatedRemoteProfile());
    await tester.pumpAndSettle();

    expect(observer.popCount, 1);
    expect(api.updates.single.name, '请求姓名');
    expect(api.updates.single.city, '杭州');
  });

  testWidgets('edit profile failure stays on page and keeps edits', (
    tester,
  ) async {
    final api = PendingOwnerProfileApi()
      ..updateError = const AuthApiException(
        code: 'NETWORK_UNAVAILABLE',
        message: '断网',
      );
    final observer = RecordingNavigatorObserver();
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(validSession()),
      profileApi: api,
    );

    await pumpEditProfile(tester, state, observer);
    await tester.tap(find.text('打开编辑'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('profile-name-field')), '保留姓名');
    await tester.enterText(find.byKey(const Key('profile-city-field')), '保留城市');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(observer.popCount, 0);
    expect(find.byType(EditProfilePage), findsOneWidget);
    expect(find.text('保存失败，请稍后重试'), findsOneWidget);
    expect(find.text('保留姓名'), findsOneWidget);
    expect(find.text('保留城市'), findsOneWidget);
  });
}

void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> fillOnboarding(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('onboarding-name-field')), '刘先生');
  await tester.enterText(
    find.byKey(const Key('onboarding-address-field')),
    '麓湖 1 栋 101',
  );
  await tester.tap(find.text('新房装修'));
  await tester.enterText(find.byKey(const Key('onboarding-area-field')), '96');
  await tester.pump();
}

Future<void> pumpEditProfile(
  WidgetTester tester,
  OwnerAppState state,
  NavigatorObserver observer,
) {
  return tester.pumpWidget(
    OwnerAppScope(
      state: state,
      child: MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const EditProfilePage(),
                ),
              );
            },
            child: const Text('打开编辑'),
          ),
        ),
      ),
    ),
  );
}

final class RecordingNavigatorObserver extends NavigatorObserver {
  var popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount += 1;
    super.didPop(route, previousRoute);
  }
}

final class PendingOwnerProfileApi implements OwnerProfileApi {
  Object? updateError;
  final List<OwnerProfileUpdate> updates = [];
  Completer<RemoteOwnerProfile>? _pendingUpdate;

  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) async =>
      remoteProfile();

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

AuthSession validSession() => AuthSession(
  accessToken: 'token',
  tokenType: 'Bearer',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  userId: 'user-1',
  phone: '13812345678',
  roles: const ['OWNER'],
);

RemoteOwnerProfile remoteProfile() => const RemoteOwnerProfile(
  userId: 'user-1',
  phone: '13812345678',
  name: '王先生',
  city: '成都',
  decorationType: null,
  address: null,
  area: null,
  profileComplete: false,
);

RemoteOwnerProfile updatedRemoteProfile() => const RemoteOwnerProfile(
  userId: 'user-1',
  phone: '13812345678',
  name: '服务端姓名',
  city: '服务端城市',
  decorationType: '服务端装修',
  address: '服务端地址',
  area: 88,
  profileComplete: true,
);
