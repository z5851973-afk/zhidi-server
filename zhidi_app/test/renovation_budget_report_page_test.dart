import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/pages/renovation/renovation_budget_report_page.dart';

void main() {
  testWidgets(
    'renovation budget report shows mock budget and opens masonry price page',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RenovationBudgetReportPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('知底装修预算报告'), findsOneWidget);
      expect(find.text('89㎡'), findsOneWidget);
      expect(find.text('毛坯房'), findsOneWidget);
      expect(find.text('简约装修'), findsOneWidget);
      expect(find.text('人工+辅料预估'), findsOneWidget);
      expect(find.text('平台工价'), findsOneWidget);
      expect(find.text('人工辅料'), findsOneWidget);
      expect(find.text('现场核量'), findsOneWidget);
      expect(find.text('预计装修费用'), findsOneWidget);
      expect(find.text('¥58,260'), findsOneWidget);
      expect(find.text('预计人工+辅料费用'), findsOneWidget);
      expect(find.text('预计误差约±10%'), findsOneWidget);
      expect(find.text('费用拆分'), findsOneWidget);
      expect(find.text('拆除工程'), findsOneWidget);
      expect(find.text('墙体拆除、地面拆除、厨卫拆除'), findsOneWidget);
      expect(find.text('水电工程'), findsOneWidget);
      expect(find.text('水路改造、电路改造、基础安装'), findsOneWidget);
      expect(find.text('泥瓦工程'), findsOneWidget);
      expect(find.text('贴砖、找平、砌墙抹灰'), findsOneWidget);
      expect(find.text('木工工程'), findsOneWidget);
      expect(find.text('吊顶、基层制作等'), findsOneWidget);
      expect(find.text('油工工程'), findsOneWidget);
      expect(find.text('基层处理、墙面施工'), findsOneWidget);
      expect(find.text('查看施工工价'), findsOneWidget);

      await tester.ensureVisible(find.text('泥瓦工程'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('泥瓦工程'));
      await tester.pumpAndSettle();

      expect(find.text('泥瓦工价标准'), findsOneWidget);

      Navigator.of(tester.element(find.text('泥瓦工价标准'))).pop();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('预算包含'));
      await tester.pumpAndSettle();

      expect(find.text('预算包含'), findsOneWidget);
      expect(find.text('灯具'), findsOneWidget);
      expect(find.text('为什么是这个价格？'), findsOneWidget);
      expect(find.text('成都区域统一人工标准'), findsOneWidget);
      expect(find.text('知底保障'), findsOneWidget);
      expect(find.text('平台统一人工价格'), findsOneWidget);
    },
  );
}
