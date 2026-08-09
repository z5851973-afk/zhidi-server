import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/data/price_standards.dart';
import 'package:zhidi_app/pages/price/construction_project_detail_page.dart';
import 'package:zhidi_app/pages/price/price_detail_page.dart';
import 'package:zhidi_app/pages/price/price_list_page.dart';
import 'package:zhidi_app/pages/price/price_transparency_page.dart';
import 'package:zhidi_app/pages/renovation/construction_guarantee_page.dart';
import 'package:zhidi_app/pages/renovation/fund_bank_escrow_page.dart';
import 'package:zhidi_app/pages/renovation/trade_select_page.dart';

void main() {
  testWidgets(
    'payment explanation describes offline manual confirmation only',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FundBankEscrowPage()));
      await tester.pumpAndSettle();

      expect(find.text('线下付款与人工确认'), findsWidgets);
      expect(find.textContaining('付款信息由相关方人工核对'), findsOneWidget);
      _expectNoUnsupportedPaymentClaims();
    },
  );

  testWidgets('construction explanation uses records and manual assistance', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ConstructionGuaranteePage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('服务器资料'), findsWidgets);
    expect(find.text('报价与施工留痕'), findsOneWidget);
    expect(find.text('售后人工协助'), findsOneWidget);
    expect(find.textContaining('多重审核认证'), findsNothing);
    expect(find.textContaining('平台赔付'), findsNothing);
    _expectNoUnsupportedPaymentClaims();
  });

  testWidgets('price transparency labels local prices as reference data', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PriceTransparencyPage()));
    await tester.pumpAndSettle();

    expect(find.text('参考工价说明'), findsOneWidget);
    expect(find.text('服务器资料'), findsOneWidget);
    expect(find.text('报价清单'), findsOneWidget);
    expect(find.textContaining('不代表当前服务端目录'), findsOneWidget);
    expect(find.textContaining('固定工价目录'), findsNothing);
    expect(find.textContaining('服务端固定价格目录'), findsNothing);
    expect(find.textContaining('师傅认证'), findsNothing);
    expect(find.textContaining('线上签约托管'), findsNothing);
    _expectNoUnsupportedPaymentClaims();
  });

  testWidgets(
    'price list omits online counts and opens the real trade directory',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PriceListPage(trade: demolitionTrade)),
      );
      await tester.pumpAndSettle();

      expect(find.text('本地参考工价'), findsOneWidget);
      expect(find.text('查看资料完整师傅'), findsOneWidget);
      expect(find.textContaining('不代表当前服务端目录'), findsOneWidget);
      expect(find.textContaining('平台统一人工参考价'), findsNothing);
      expect(find.textContaining('固定工价目录'), findsNothing);
      expect(find.textContaining('128位师傅在线'), findsNothing);
      expect(find.textContaining('10分钟响应'), findsNothing);
      _expectNoUnsupportedPaymentClaims();

      await tester.tap(find.text('查看资料完整师傅'));
      await tester.pumpAndSettle();
      expect(find.byType(TradeSelectPage), findsOneWidget);
    },
  );

  testWidgets(
    'price detail routes to real worker selection without fake booking',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PriceDetailPage(
            tradeName: '拆除',
            categoryName: '墙体拆除',
            project: PriceProject(name: '12墙拆除', price: '¥38', unit: '/㎡'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('本地参考人工价'), findsOneWidget);
      expect(find.text('查看资料完整师傅'), findsOneWidget);
      expect(find.text('立即预约'), findsNothing);
      expect(find.textContaining('平台固定人工价格'), findsNothing);

      await tester.tap(find.text('查看资料完整师傅'));
      await tester.pumpAndSettle();

      expect(find.byType(TradeSelectPage), findsOneWidget);
      expect(find.textContaining('已预约'), findsNothing);
    },
  );

  testWidgets(
    'project detail routes to real worker selection without fake quote',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ConstructionProjectDetailPage.wallDemolition()),
      );
      await tester.pumpAndSettle();

      expect(find.text('本地示例人工价'), findsOneWidget);
      expect(find.textContaining('本地示例，仅用于了解计价结构'), findsOneWidget);
      expect(find.text('查看资料完整师傅'), findsOneWidget);
      expect(find.text('立即获取报价'), findsNothing);
      expect(find.textContaining('平台统一人工价'), findsNothing);
      expect(find.text('标准工价'), findsNothing);
      expect(find.text('施工流程示意'), findsOneWidget);
      expect(find.text('施工师傅已认证'), findsNothing);

      await tester.tap(find.text('查看资料完整师傅'));
      await tester.pumpAndSettle();

      expect(find.byType(TradeSelectPage), findsOneWidget);
      expect(find.textContaining('已为你生成'), findsNothing);
    },
  );
}

void _expectNoUnsupportedPaymentClaims() {
  for (final claim in const ['银行监管', '平台不碰钱', '银行放款', '自动退款', '自动放款']) {
    expect(find.textContaining(claim), findsNothing, reason: claim);
  }
}
