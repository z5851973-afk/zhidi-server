import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/models/renovation.dart';
import 'package:zhidi_app/pages/home/worker/worker_list_page.dart';
import 'package:zhidi_app/services/worker_directory_api_client.dart';

void main() {
  testWidgets('worker list shows matching Spring Boot workers first', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerListPage(
          trade: Trade.masonry,
          workerDirectoryApi: _FakeWorkerDirectoryApi([
            const RemoteWorkerDirectoryProfile(
              userId: 'worker-user-remote',
              name: '服务端周师傅',
              serviceCity: '杭州',
              primaryTrade: '泥工',
              experienceYears: 11,
              dailyRate: 680,
              bio: '服务端返回的瓷砖铺贴师傅',
            ),
            const RemoteWorkerDirectoryProfile(
              userId: 'worker-user-other-trade',
              name: '服务端何师傅',
              serviceCity: '杭州',
              primaryTrade: '拆除',
              experienceYears: 9,
              dailyRate: 520,
              bio: '不应该出现在泥瓦列表',
            ),
          ]),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('服务端周师傅'), findsOneWidget);
    expect(find.text('服务端何师傅'), findsNothing);
    expect(find.textContaining('11年经验'), findsOneWidget);
    expect(find.text('服务端返回的瓷砖铺贴师傅'), findsOneWidget);
  });

  testWidgets('worker list keeps mock workers when Spring Boot workers fail', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerListPage(
          trade: Trade.demolition,
          workerDirectoryApi: _ThrowingWorkerDirectoryApi(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('张国强'), findsOneWidget);
    expect(find.textContaining('12年经验'), findsOneWidget);
  });
}

final class _FakeWorkerDirectoryApi implements WorkerDirectoryApi {
  const _FakeWorkerDirectoryApi(this.workers);

  final List<RemoteWorkerDirectoryProfile> workers;

  @override
  Future<List<RemoteWorkerDirectoryProfile>> listWorkers() async => workers;

  @override
  Future<RemoteWorkerDirectoryProfile> getWorker(String userId) async =>
      workers.firstWhere((worker) => worker.userId == userId);
}

final class _ThrowingWorkerDirectoryApi implements WorkerDirectoryApi {
  @override
  Future<List<RemoteWorkerDirectoryProfile>> listWorkers() async {
    throw const AuthApiExceptionForTest();
  }

  @override
  Future<RemoteWorkerDirectoryProfile> getWorker(String userId) async {
    throw const AuthApiExceptionForTest();
  }
}

final class AuthApiExceptionForTest implements Exception {
  const AuthApiExceptionForTest();
}
