import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/models/house_info.dart';
import 'package:zhidi_app/pages/worker/quotation_form_page.dart';
import 'package:zhidi_app/services/service_catalog_api_client.dart';

void main() {
  testWidgets('quotation form shows house summary and on-site reminder', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: QuotationFormPage(
            order: WorkerOrder(
              id: 'booking-house',
              ownerName: '业主',
              ownerPhone: '13800000000',
              ownerAddress: '成都 1 栋 101',
              area: '',
              houseInfo: const HouseInfo(
                areaSqm: 98.5,
                bedroomCount: 3,
                livingRoomCount: 2,
                kitchenCount: 1,
                bathroomCount: 2,
              ),
              requirement: '木工师傅',
              description: '柜体安装',
              trade: '木工',
              status: WorkerOrderStatus.onSite,
            ),
            catalogApi: _FakeCatalogApi(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('98.5㎡ · 3室2厅1厨2卫'), findsOneWidget);
    expect(find.text('请按现场实际情况报价'), findsOneWidget);
  });
  testWidgets('quotation form shows remote catalog items after first build', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: QuotationFormPage(
            order: WorkerOrder(
              id: 'booking-1',
              ownerName: '业主',
              ownerPhone: '13800000000',
              ownerAddress: '成都 1 栋 101',
              area: '80㎡',
              requirement: '木工师傅',
              description: '柜体安装',
              trade: '木工',
              status: WorkerOrderStatus.onSite,
            ),
            catalogApi: _FakeCatalogApi(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('门套安装'), findsOneWidget);
    expect(find.text('¥200/套'), findsOneWidget);
    expect(find.text('请勾选报价项目'), findsOneWidget);
  });

  testWidgets('quotation form separates labor and material with direct input', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: QuotationFormPage(
            order: WorkerOrder(
              id: 'booking-1',
              ownerName: '业主',
              ownerPhone: '13800000000',
              ownerAddress: '成都 1 栋 101',
              area: '80㎡',
              requirement: '木工师傅',
              description: '柜体安装',
              trade: '木工',
              status: WorkerOrderStatus.onSite,
            ),
            catalogApi: _FakeCatalogApi(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('人工费用'), findsOneWidget);
    expect(find.text('材料费用'), findsOneWidget);
    expect(find.text('板材材料'), findsOneWidget);

    await tester.tap(find.text('门套安装'));
    await tester.pump();
    final input = find.byKey(const ValueKey('quote-qty-门套安装'));
    expect(input, findsOneWidget);
    await tester.enterText(input, '3');
    await tester.pump();

    expect(find.text('提交报价单（¥600）'), findsOneWidget);
  });

  testWidgets(
    'quantity input stays open and blank after deleting the last digit',
    (tester) async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: QuotationFormPage(
              order: WorkerOrder(
                id: 'booking-1',
                ownerName: '业主',
                ownerPhone: '13800000000',
                ownerAddress: '成都 1 栋 101',
                area: '80㎡',
                requirement: '木工师傅',
                description: '柜体安装',
                trade: '木工',
                status: WorkerOrderStatus.onSite,
              ),
              catalogApi: _FakeCatalogApi(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('门套安装'));
      await tester.pump();
      final input = find.byKey(const ValueKey('quote-qty-门套安装'));

      await tester.enterText(input, '');
      await tester.pump();

      expect(input, findsOneWidget);
      expect(tester.widget<TextFormField>(input).controller?.text, '');
      expect(find.text('合计 ¥0'), findsOneWidget);
      expect(find.text('请勾选报价项目'), findsOneWidget);

      await tester.enterText(input, '5');
      await tester.pump();

      expect(tester.widget<TextFormField>(input).controller?.text, '5');
      expect(find.text('提交报价单（¥1000）'), findsOneWidget);
    },
  );

  testWidgets('reusing the page for another order resets and reloads catalog', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final currentOrder = ValueNotifier<WorkerOrder>(
      _order(id: 'booking-a', trade: '木工', ownerName: 'A 业主'),
    );
    addTearDown(currentOrder.dispose);
    final catalogApi = _SwitchingCatalogApi();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: ValueListenableBuilder<WorkerOrder>(
            valueListenable: currentOrder,
            builder: (context, order, child) =>
                QuotationFormPage(order: order, catalogApi: catalogApi),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('门套安装'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('quote-qty-门套安装')), '50');
    await tester.pump();
    expect(find.text('提交报价单（¥10000）'), findsOneWidget);

    currentOrder.value = _order(
      id: 'booking-b',
      trade: '水电',
      ownerName: 'B 业主',
    );
    await tester.pumpAndSettle();

    expect(find.text('合计 ¥0'), findsOneWidget);
    expect(find.text('请勾选报价项目'), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-qty-门套安装')), findsNothing);
    expect(find.text('水管检修'), findsOneWidget);
    expect(catalogApi.requestedTrades, ['木工', '水电']);
  });
}

WorkerOrder _order({
  required String id,
  required String trade,
  required String ownerName,
}) => WorkerOrder(
  id: id,
  ownerName: ownerName,
  ownerPhone: '13800000000',
  ownerAddress: '成都 1 栋 101',
  area: '80㎡',
  requirement: '$trade师傅',
  description: '上门施工',
  trade: trade,
  status: WorkerOrderStatus.onSite,
);

final class _FakeCatalogApi implements ServiceCatalogApi {
  @override
  Future<List<CatalogItem>> getCatalog(
    String accessToken,
    String category,
  ) async {
    expect(accessToken, 'worker-jwt');
    expect(category, '木工');
    return const [
      CatalogItem(
        id: 'catalog-1',
        category: 'CARPENTRY',
        name: '门套安装',
        unit: '套',
        unitPrice: 200,
      ),
      CatalogItem(
        id: 'catalog-2',
        category: 'CARPENTRY',
        name: '板材材料',
        unit: '张',
        unitPrice: 180,
        isMaterial: true,
      ),
    ];
  }
}

final class _SwitchingCatalogApi implements ServiceCatalogApi {
  final List<String> requestedTrades = [];

  @override
  Future<List<CatalogItem>> getCatalog(
    String accessToken,
    String category,
  ) async {
    expect(accessToken, 'worker-jwt');
    requestedTrades.add(category);
    return switch (category) {
      '木工' => const [
        CatalogItem(
          id: 'catalog-carpentry',
          category: 'CARPENTRY',
          name: '门套安装',
          unit: '套',
          unitPrice: 200,
        ),
      ],
      '水电' => const [
        CatalogItem(
          id: 'catalog-plumbing',
          category: 'PLUMBING',
          name: '水管检修',
          unit: '项',
          unitPrice: 80,
        ),
      ],
      _ => const [],
    };
  }
}
