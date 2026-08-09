import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/auth/onboarding_page.dart';
import 'package:zhidi_app/pages/home/home_page.dart';
import 'package:zhidi_app/pages/profile/edit_profile_page.dart';
import 'package:zhidi_app/pages/profile/profile_page.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';
import 'package:zhidi_app/services/service_request_api_client.dart';

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
    expect(find.text('刘先生'), findsOneWidget);
    expect(find.text('成都'), findsOneWidget);
  });

  testWidgets(
    'profile shows phone verification instead of fake real-name status',
    (tester) async {
      usePhoneViewport(tester);
      final state = await OwnerAppState.memory();
      await state.updateProfile(
        state.profile.copyWith(
          name: '王女士',
          city: '成都',
          phone: '13812345678',
          avatarUrl: '/uploads/owner-avatar/test.png',
        ),
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: const MaterialApp(home: Scaffold(body: ProfilePage())),
        ),
      );
      await tester.pump();

      expect(find.text('手机号已验证'), findsOneWidget);
      expect(find.text('已实名认证'), findsNothing);
    },
  );

  testWidgets('profile and onboarding stay usable at 320px with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await OwnerAppState.memory();
    await state.updateProfile(
      state.profile.copyWith(
        name: '名字较长的测试业主',
        city: '成都市高新区',
        phone: '13812345678',
      ),
    );

    Widget scaled(Widget child) => MediaQuery(
      data: const MediaQueryData(
        size: Size(320, 780),
        textScaler: TextScaler.linear(1.4),
      ),
      child: child,
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(home: scaled(const Scaffold(body: ProfilePage()))),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(home: scaled(const OnboardingPage())),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile address entry shows the server-backed address count', (
    tester,
  ) async {
    final empty = await OwnerAppState.memory();
    final state = OwnerAppState.fromJson({
      ...empty.toJson(),
      'addresses': [
        const OwnerAddress(
          id: 'address-1',
          recipient: '林先生',
          phone: '13800138201',
          province: '四川省',
          city: '成都市',
          district: '武侯区',
          detail: '科华路 1 号',
          isDefault: true,
        ).toJson(),
      ],
    });

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: const MaterialApp(home: Scaffold(body: ProfilePage())),
      ),
    );

    expect(find.text('1 个常用地址'), findsOneWidget);
  });

  testWidgets('profile project count uses the remote service request feed', (
    tester,
  ) async {
    final empty = await OwnerAppState.memory();
    final createdAt = DateTime.utc(2026, 8, 8).toIso8601String();
    final state = OwnerAppState.fromJson({
      ...empty.toJson(),
      'remoteServiceRequestIds': ['request-1', 'request-without-candidate'],
      'appointments': [
        {
          'id': 'rm-booking-1',
          'bookingId': 'booking-1',
          'serviceRequestId': 'request-1',
          'workerName': '甲师傅',
          'customerName': '业主',
          'phone': '13800000000',
          'address': '成都',
          'area': '',
          'description': '',
          'visitTime': '',
          'status': '待接单',
          'createdAt': createdAt,
        },
        {
          'id': 'rm-booking-2',
          'bookingId': 'booking-2',
          'serviceRequestId': 'request-1',
          'workerName': '乙师傅',
          'customerName': '业主',
          'phone': '13800000000',
          'address': '成都',
          'area': '',
          'description': '',
          'visitTime': '',
          'status': '待接单',
          'createdAt': createdAt,
        },
      ],
    });

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: ProfilePage(
              projectsPageBuilder: (_) => const Scaffold(body: Text('服务端项目列表')),
            ),
          ),
        ),
      ),
    );

    expect(find.text('2 个项目'), findsOneWidget);
    expect(find.text('0 个项目'), findsNothing);

    await tester.tap(find.text('2 个项目'));
    await tester.pumpAndSettle();
    expect(find.text('服务端项目列表'), findsOneWidget);
  });

  testWidgets('profile actively refreshes the server project count on entry', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(validSession()),
      profileApi: PendingOwnerProfileApi(),
    );
    final api = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [
                {
                  'id': 'fresh-request',
                  'ownerUserId': 'user-1',
                  'trade': 'plumbing',
                  'serviceCity': '成都',
                  'serviceAddress': '测试小区',
                  'remark': null,
                  'status': 'OPEN',
                  'candidates': [],
                  'createdAt': '2026-08-08T08:00:00Z',
                  'updatedAt': '2026-08-08T08:00:00Z',
                },
              ],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: ProfilePage(
              projectRefresh: () =>
                  state.fetchRemoteServiceRequests(serviceRequestApi: api),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 个项目'), findsOneWidget);
  });

  testWidgets('profile refreshes each time the real home tab becomes visible', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(validSession()),
      profileApi: PendingOwnerProfileApi(),
      bookingApi: const _EmptyOwnerBookingApi(),
    );
    var refreshCalls = 0;

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: HomePage(
            profilePageBuilder: (refreshEpoch) => ProfilePage(
              refreshEpoch: refreshEpoch,
              projectRefresh: () async => refreshCalls += 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initialCalls = refreshCalls;

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(refreshCalls, initialCalls + 1);

    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(refreshCalls, initialCalls + 2);
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
    await tester.tap(find.byKey(const Key('profile-gender-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('女').last);
    await tester.pumpAndSettle();
    observer.popCount = 0;
    await tapProfileSave(tester);
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
    expect(api.updates.single.gender, 'FEMALE');
  });

  testWidgets('edit uploads owner avatar and phone cannot be edited', (
    tester,
  ) async {
    final api = PendingOwnerProfileApi();
    final observer = RecordingNavigatorObserver();
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(validSession()),
      profileApi: api,
    );

    await pumpEditProfile(
      tester,
      state,
      observer,
      avatarUploader: (accessToken) async {
        expect(accessToken, 'token');
        return '/uploads/owner-avatar/2026/08/02/avatar.png';
      },
    );
    await tester.tap(find.text('打开编辑'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('profile-phone-field')),
              matching: find.byType(EditableText),
            ),
          )
          .readOnly,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('profile-avatar-button')));
    await tester.pumpAndSettle();
    await tapProfileSave(tester);
    await tester.pump();

    expect(
      api.updates.single.avatarUrl,
      '/uploads/owner-avatar/2026/08/02/avatar.png',
    );
    api.completeUpdate(updatedRemoteProfile());
    await tester.pumpAndSettle();
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
    await tapProfileSave(tester);
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
  await tester.enterText(find.byKey(const Key('onboarding-city-field')), '成都');
  await tester.pump();
}

Future<void> tapProfileSave(WidgetTester tester) async {
  final saveButton = find.widgetWithText(FilledButton, '保存');
  await tester.drag(find.byType(ListView), const Offset(0, -320));
  await tester.pumpAndSettle();
  await tester.tap(saveButton);
}

Future<void> pumpEditProfile(
  WidgetTester tester,
  OwnerAppState state,
  NavigatorObserver observer, {
  Future<String?> Function(String accessToken)? avatarUploader,
}) {
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
                  builder: (_) =>
                      EditProfilePage(avatarUploader: avatarUploader),
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

final class _EmptyOwnerBookingApi implements OwnerBookingApi {
  const _EmptyOwnerBookingApi();

  @override
  Future<List<RemoteOwnerBooking>> listOwnerBookings(
    String accessToken,
  ) async => const [];

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
  avatarUrl: null,
  gender: null,
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
  avatarUrl: '/uploads/owner-avatar/updated.png',
  gender: 'FEMALE',
  decorationType: '服务端装修',
  address: '服务端地址',
  area: 88,
  profileComplete: true,
);
