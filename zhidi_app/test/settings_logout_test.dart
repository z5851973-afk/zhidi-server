import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/main.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';

void main() {
  testWidgets(
    'owner can log out from settings and protected tabs require login',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final sessions = MemoryAuthSessionStore();
      final state = await OwnerAppState.memory(
        sessionStore: sessions,
        profileApi: _ProfileApiStub(),
      );
      await state.completeAuthenticatedLogin(_ownerLoginResponse());
      await state.completeOnboarding(
        decorationType: '新房装修',
        address: 'TestHome1-1',
        area: 90,
      );

      await tester.pumpWidget(ZhidiApp(ownerState: state));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认退出'));
      await tester.pumpAndSettle();

      expect(state.isLoggedIn, isFalse);
      expect(await sessions.read(), isNull);
      expect(find.text('立即找师傅'), findsOneWidget);

      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();

      expect(find.text('登录'), findsWidgets);
      expect(find.text('登录后查看我的家、管理装修进度'), findsOneWidget);
    },
  );
}

OwnerLoginResponse _ownerLoginResponse() => const OwnerLoginResponse(
  accessToken: 'jwt',
  tokenType: 'Bearer',
  expiresInSeconds: 2_592_000,
  user: AuthUser(
    id: '01904f24-3f5b-7000-8000-000000000001',
    phone: '16600000888',
    status: 'ACTIVE',
    roles: ['OWNER'],
  ),
);

final class _ProfileApiStub implements OwnerProfileApi {
  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) async =>
      _remoteProfile();

  @override
  Future<RemoteOwnerProfile> updateCurrent(
    String accessToken,
    OwnerProfileUpdate request,
  ) async => _remoteProfile(
    decorationType: request.decorationType,
    address: request.address,
    area: request.area,
  );
}

RemoteOwnerProfile _remoteProfile({
  String? decorationType,
  String? address,
  double? area,
}) => RemoteOwnerProfile(
  userId: '01904f24-3f5b-7000-8000-000000000001',
  phone: '16600000888',
  name: '王先生',
  city: '成都',
  decorationType: decorationType,
  address: address,
  area: area,
  profileComplete: decorationType != null && address != null && area != null,
);
