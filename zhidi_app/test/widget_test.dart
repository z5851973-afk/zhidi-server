import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/main.dart';

void main() {
  testWidgets('owner shell exposes four tabs and opens the profile tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(ZhidiApp(state: OwnerAppState.memory()));

    expect(find.text('首页'), findsWidgets);
    expect(find.text('我的家'), findsOneWidget);
    expect(find.text('消息'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.text('王先生'), findsOneWidget);
  });
}
