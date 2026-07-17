import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/data/price_standards.dart';
import 'package:zhidi_app/pages/price/price_item_list_page.dart';
import 'package:zhidi_app/pages/price/tile_laying_detail_page.dart';

void main() {
  testWidgets(
    'tile laying detail page shows standard pricing and opens masonry workers',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TileLayingDetailPage()));
      await tester.pumpAndSettle();

      expect(find.text('地砖铺贴'), findsNWidgets(2));
      expect(find.text('专业施工标准 · 平台统一人工价'), findsOneWidget);
      expect(find.text('¥55/㎡ 起'), findsOneWidget);
      expect(find.text('透明报价'), findsOneWidget);
      expect(find.text('平台标准'), findsOneWidget);
      expect(find.text('验收保障'), findsOneWidget);

      expect(find.text('选择铺贴规格'), findsOneWidget);
      expect(find.text('普通地砖'), findsOneWidget);
      expect(find.text('800×800以内'), findsOneWidget);
      expect(find.text('大规格瓷砖'), findsOneWidget);
      expect(find.text('800×800以上'), findsOneWidget);
      expect(find.text('小规格砖'), findsOneWidget);
      expect(find.text('300×300以内'), findsOneWidget);
      expect(find.text('¥55/㎡'), findsOneWidget);
      expect(find.text('¥75/㎡'), findsOneWidget);
      expect(find.text('¥80/㎡'), findsOneWidget);

      await tester.ensureVisible(find.text('为什么是这个价格？'));
      await tester.pumpAndSettle();

      expect(find.text('施工包含'), findsOneWidget);
      expect(find.text('基层处理'), findsOneWidget);
      expect(find.text('水平调整'), findsOneWidget);
      expect(find.text('铺贴施工'), findsOneWidget);
      expect(find.text('空鼓检查'), findsOneWidget);
      expect(find.text('不包含'), findsOneWidget);
      expect(find.text('瓷砖材料'), findsOneWidget);
      expect(find.text('美缝'), findsOneWidget);
      expect(find.text('特殊造型施工'), findsOneWidget);
      expect(find.text('为什么是这个价格？'), findsOneWidget);
      expect(find.textContaining('成都区域统一人工标准'), findsOneWidget);
      expect(find.text('施工难度'), findsOneWidget);
      expect(find.text('瓷砖规格'), findsOneWidget);
      expect(find.text('工艺要求'), findsOneWidget);
      expect(find.text('查看可接单泥瓦师傅'), findsOneWidget);

      await tester.tap(find.text('查看可接单泥瓦师傅'));
      await tester.pumpAndSettle();

      expect(find.text('泥瓦师傅列表'), findsOneWidget);
    },
  );

  testWidgets('masonry tile item opens tile laying standard detail page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PriceItemListPage(
          tradeName: '泥瓦',
          category: masonryTrade.categories.first,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('800×800地砖'));
    await tester.pumpAndSettle();

    expect(find.text('专业施工标准 · 平台统一人工价'), findsOneWidget);
    expect(find.text('查看可接单泥瓦师傅'), findsOneWidget);
  });
}
