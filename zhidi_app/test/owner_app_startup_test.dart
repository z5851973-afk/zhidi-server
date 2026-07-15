import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/main.dart';
import 'package:zhidi_app/services/auth_session_store.dart';

void main() {
  test('restores owner login from a valid secure session', () async {
    final sessions = MemoryAuthSessionStore(
      AuthSession(
        accessToken: 'jwt',
        tokenType: 'Bearer',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        userId: '01904f24-3f5b-7000-8000-000000000001',
        phone: '16600000002',
        roles: const ['OWNER'],
      ),
    );

    final state = await OwnerAppState.memory(sessionStore: sessions);

    expect(state.isLoggedIn, isTrue);
    expect(state.profile.phone, '16600000002');
  });

  testWidgets('logged out owner can browse home immediately', (tester) async {
    final state = await OwnerAppState.memory();

    await tester.pumpWidget(ZhidiApp(ownerState: state));
    await tester.pumpAndSettle();

    expect(find.text('登录'), findsNothing);
    expect(find.text('立即找师傅'), findsOneWidget);
  });

  testWidgets(
    'logged out owner sees no protected tab badges and must login to open them',
    (tester) async {
      final state = await OwnerAppState.memory();

      await tester.pumpWidget(ZhidiApp(ownerState: state));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('bottom-tab-2-badge-2')), findsNothing);
      expect(find.byKey(const ValueKey('bottom-tab-3-badge-2')), findsNothing);

      await tester.tap(find.text('消息'));
      await tester.pumpAndSettle();

      expect(find.text('登录'), findsWidgets);
      expect(find.text('登录后查看我的家、管理装修进度'), findsOneWidget);
    },
  );

  testWidgets('logged in owner with incomplete profile starts onboarding', (
    tester,
  ) async {
    final sessions = MemoryAuthSessionStore(
      AuthSession(
        accessToken: 'jwt',
        tokenType: 'Bearer',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        userId: '01904f24-3f5b-7000-8000-000000000001',
        phone: '16600000002',
        roles: const ['OWNER'],
      ),
    );
    final state = await OwnerAppState.memory(sessionStore: sessions);

    await tester.pumpWidget(ZhidiApp(ownerState: state));
    await tester.pumpAndSettle();

    expect(find.text('完善您的资料'), findsOneWidget);
    expect(find.text('帮助我们为您匹配最合适的装修方案'), findsOneWidget);
  });
}
