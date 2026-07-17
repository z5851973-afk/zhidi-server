import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/worker/worker_list_page.dart';
import 'package:zhidi_app/pages/renovation/worker_detail_page.dart';
import 'package:zhidi_app/models/renovation.dart';
import 'package:zhidi_app/services/worker_directory_api_client.dart';

void main() {
  testWidgets('demolition worker list selects worker and opens remote detail', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(store: MemoryOwnerStore());

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerListPage(
            trade: Trade.demolition,
            workerDirectoryApi: _WorkerDirectory(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('拆除师傅列表'), findsOneWidget);
    expect(find.text('全部工种'), findsNothing);
    expect(find.text('何师傅'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('何师傅').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看何师傅资料'));
    await tester.pumpAndSettle();

    expect(find.byType(WorkerDetailPage), findsOneWidget);
  });
}

final class _WorkerDirectory implements WorkerDirectoryApi {
  static const worker = RemoteWorkerDirectoryProfile(
    userId: 'worker-he',
    name: '何师傅',
    serviceCity: '成都',
    primaryTrade: '拆除',
    experienceYears: 9,
    dailyRate: 600,
    bio: '测试拆除工人',
  );

  @override
  Future<List<RemoteWorkerDirectoryProfile>> listWorkers() async => [worker];

  @override
  Future<RemoteWorkerDirectoryProfile> getWorker(String userId) async => worker;
}
