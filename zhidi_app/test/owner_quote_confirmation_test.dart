import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/pages/home/owner_quote_compare_page.dart';

void main() {
  testWidgets('quote selection requires acknowledgement and two-second hold',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                builder: (_) => const QuoteSelectionConfirmationDialog(
                  workerName: '张师傅',
                  totalPrice: 12800,
                ),
              );
            },
            child: const Text('选择报价'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('选择报价'));
    await tester.pumpAndSettle();
    expect(find.textContaining('¥12800.00'), findsOneWidget);

    final button = find.byKey(const Key('quote-hold-confirm'));
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    var gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 1500));
    await gesture.up();
    await tester.pump();
    expect(result, isNull);
    expect(find.text('确认选人'), findsOneWidget);

    gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    await gesture.up();
  });
}
