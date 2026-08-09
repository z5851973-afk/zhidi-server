import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/data/price_standards.dart';
import 'package:zhidi_app/pages/price/construction_project_detail_page.dart';
import 'package:zhidi_app/pages/price/price_item_list_page.dart';
import 'package:zhidi_app/pages/price/price_list_page.dart';

void main() {
  testWidgets(
    'wall demolition detail explains price standard process and trust',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ConstructionProjectDetailPage.wallDemolition()),
      );
      await tester.pumpAndSettle();

      expect(find.text('墙体拆除'), findsWidgets);
      expect(find.text('装修第一步，拆对才能装好'), findsOneWidget);
      expect(find.text('示例工价'), findsOneWidget);
      expect(find.text('本地示例人工价'), findsOneWidget);
      expect(find.text('示例计价'), findsOneWidget);
      expect(find.textContaining('本地示例，仅用于了解计价结构'), findsOneWidget);
      expect(find.textContaining('平台统一人工价'), findsNothing);
      expect(find.text('标准工价'), findsNothing);
      expect(find.text('工艺说明'), findsOneWidget);
      expect(find.text('验收留痕'), findsWidgets);
      expect(find.text('12墙拆除'), findsOneWidget);
      expect(find.text('24墙拆除'), findsOneWidget);
      expect(find.text('37墙拆除'), findsOneWidget);
      expect(find.text('人工拆除'), findsOneWidget);
      expect(find.text('垃圾外运'), findsOneWidget);
      expect(find.text('为什么是这个价格'), findsOneWidget);

      await tester.ensureVisible(find.text('知底施工标准'));
      await tester.pumpAndSettle();

      expect(find.text('知底施工标准'), findsOneWidget);
      expect(find.text('01'), findsOneWidget);
      expect(find.text('定位'), findsOneWidget);
      expect(find.text('02'), findsOneWidget);
      expect(find.text('切割'), findsOneWidget);
      expect(find.text('03'), findsOneWidget);
      expect(find.text('拆除'), findsOneWidget);
      expect(find.text('04'), findsOneWidget);
      expect(find.text('清理'), findsOneWidget);

      await tester.ensureVisible(find.text('施工流程示意'));
      await tester.pumpAndSettle();

      expect(find.text('施工流程示意'), findsOneWidget);
      expect(find.text('施工前'), findsOneWidget);
      expect(find.text('施工过程'), findsOneWidget);
      expect(find.text('施工完成'), findsOneWidget);
      expect(find.text('成都·金牛区'), findsNothing);
      expect(find.text('施工师傅已认证'), findsNothing);

      await tester.ensureVisible(find.text('服务与记录'));
      await tester.pumpAndSettle();

      expect(find.text('认证施工师傅'), findsNothing);
      expect(find.text('银双云'), findsNothing);
      expect(find.text('工龄 8 年'), findsNothing);
      expect(find.text('已完成 128 单'), findsNothing);
      expect(find.text('评分 4.9'), findsNothing);
      expect(find.text('服务与记录'), findsOneWidget);
      expect(find.text('施工照片留档'), findsOneWidget);
      expect(find.text('报价清单'), findsOneWidget);
      expect(find.text('售后人工协助'), findsOneWidget);
      expect(find.text('查看资料完整师傅'), findsOneWidget);
      expect(find.text('立即获取报价'), findsNothing);
    },
  );

  testWidgets(
    'demolition wall category opens construction project detail page',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PriceListPage(trade: demolitionTrade)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('墙体拆除'));
      await tester.pumpAndSettle();

      expect(find.text('装修第一步，拆对才能装好'), findsOneWidget);
      expect(find.text('本地示例人工价'), findsOneWidget);
      expect(find.text('知底施工标准'), findsOneWidget);
    },
  );

  testWidgets(
    'demolition wall price item also opens construction project detail page',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PriceItemListPage(
            tradeName: '拆除',
            category: PriceCategory(
              name: '墙体拆除',
              icon: Icons.domain,
              description: '拆除各类墙体',
              projects: [PriceProject(name: '12墙拆除', price: '¥45', unit: '/㎡')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('12墙拆除'));
      await tester.pumpAndSettle();

      expect(find.text('装修第一步，拆对才能装好'), findsOneWidget);
      expect(find.text('本地示例人工价'), findsOneWidget);
      expect(find.text('知底施工标准'), findsOneWidget);
    },
  );
}
