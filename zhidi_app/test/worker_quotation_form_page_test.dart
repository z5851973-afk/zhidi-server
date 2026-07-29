import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/pages/worker/quotation_form_page.dart';
import 'package:zhidi_app/services/service_catalog_api_client.dart';

void main() {
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
}

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
    ];
  }
}
