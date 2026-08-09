import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/models/house_info.dart';
import 'package:zhidi_app/pages/renovation/house_info_page.dart';

void main() {
  testWidgets('requires valid area before submitting default layout', (
    tester,
  ) async {
    final submitted = <HouseInfo>[];
    await tester.pumpWidget(
      MaterialApp(
        home: HouseInfoPage(
          tradeLabel: '油漆师傅',
          address: '四川省成都市武侯区科华路 1 号',
          onSubmit: (info) async => submitted.add(info),
        ),
      ),
    );

    await tester.tap(find.text('确认并选择师傅'));
    await tester.pump();
    expect(find.text('请输入 1–9999㎡ 的建筑面积'), findsOneWidget);
    expect(submitted, isEmpty);

    await tester.enterText(find.byKey(const Key('house-area-field')), '98.5');
    await tester.tap(find.text('确认并选择师傅'));
    await tester.pumpAndSettle();

    expect(submitted, [
      const HouseInfo(
        areaSqm: 98.5,
        bedroomCount: 3,
        livingRoomCount: 2,
        kitchenCount: 1,
        bathroomCount: 2,
      ),
    ]);
  });

  testWidgets('failed submit keeps values and allows retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HouseInfoPage(
          tradeLabel: '油漆师傅',
          address: '四川省成都市武侯区科华路 1 号',
          onSubmit: (_) async {
            calls++;
            if (calls == 1) throw Exception('offline');
          },
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('house-area-field')), '98.5');

    await tester.tap(find.text('确认并选择师傅'));
    await tester.pumpAndSettle();
    expect(find.text('创建需求失败，请重试'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('house-area-field')))
          .controller
          ?.text,
      '98.5',
    );

    await tester.tap(find.text('确认并选择师傅'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('double tap starts only one submission', (tester) async {
    final gate = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HouseInfoPage(
          tradeLabel: '油漆师傅',
          address: '四川省成都市武侯区科华路 1 号',
          onSubmit: (_) {
            calls++;
            return gate.future;
          },
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('house-area-field')), '98.5');

    await tester.tap(find.byKey(const Key('house-info-submit')));
    await tester.tap(find.byKey(const Key('house-info-submit')));
    await tester.pump();

    expect(calls, 1);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('submission blocks back navigation and every house input', (
    tester,
  ) async {
    final gate = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: HouseInfoPage(
          tradeLabel: '油漆师傅',
          address: '四川省成都市武侯区科华路 1 号',
          onSubmit: (_) => gate.future,
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('house-area-field')), '98.5');

    await tester.tap(find.byKey(const Key('house-info-submit')));
    await tester.pump();

    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('house-area-field')))
          .enabled,
      isFalse,
    );
    for (final room in ['bedroom', 'living-room', 'kitchen', 'bathroom']) {
      expect(
        tester
            .widget<IconButton>(find.byKey(Key('house-$room-decrement')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(Key('house-$room-increment')))
            .onPressed,
        isNull,
      );
    }

    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);
  });

  testWidgets('typed submission failure exposes the login prompt', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HouseInfoPage(
          tradeLabel: '油漆师傅',
          address: '四川省成都市武侯区科华路 1 号',
          onSubmit: (_) async {
            throw const HouseInfoSubmissionException('登录已过期，请重新登录');
          },
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('house-area-field')), '98.5');

    await tester.tap(find.byKey(const Key('house-info-submit')));
    await tester.pumpAndSettle();

    expect(find.text('登录已过期，请重新登录'), findsOneWidget);
    expect(find.text('创建需求失败，请重试'), findsNothing);
  });
}
