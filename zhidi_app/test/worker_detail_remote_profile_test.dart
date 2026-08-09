import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/models/renovation.dart';
import 'package:zhidi_app/pages/profile/favorites_page.dart';
import 'package:zhidi_app/pages/renovation/worker_detail_page.dart';
import 'package:zhidi_app/services/worker_case_api_client.dart';
import 'package:zhidi_app/services/worker_directory_api_client.dart';

void main() {
  testWidgets('worker detail displays Spring Boot worker profile fields', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(store: MemoryOwnerStore());

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: const MaterialApp(
          home: WorkerDetailPage(
            workerName: '服务端周师傅',
            trade: Trade.masonry,
            caseApi: _EmptyWorkerCaseApi(),
            remoteProfile: RemoteWorkerDirectoryProfile(
              userId: 'worker-user-remote',
              name: '服务端周师傅',
              serviceCity: '杭州',
              primaryTrade: '泥工',
              experienceYears: 11,
              dailyRate: 680,
              bio: '服务端返回的瓷砖铺贴师傅',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('服务端周师傅'), findsOneWidget);
    expect(find.textContaining('泥工师傅'), findsAtLeastNWidgets(1));
    expect(find.text('11'), findsOneWidget);
    expect(find.text('年经验'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();

    expect(find.textContaining('杭州'), findsAtLeastNWidgets(1));
    expect(find.textContaining('680'), findsAtLeastNWidgets(1));
    expect(find.textContaining('服务端返回的瓷砖铺贴师傅'), findsOneWidget);
  });

  testWidgets(
    'remote worker detail only shows server facts before cooperation',
    (tester) async {
      final state = await OwnerAppState.memory(store: MemoryOwnerStore());

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: const MaterialApp(
            home: WorkerDetailPage(
              workerName: '服务端周师傅',
              caseApi: _EmptyWorkerCaseApi(),
              remoteProfile: RemoteWorkerDirectoryProfile(
                userId: 'worker-user-remote',
                name: '服务端周师傅',
                serviceCity: '杭州',
                primaryTrade: '泥工',
                experienceYears: 11,
                dailyRate: 680,
                bio: '服务端返回的瓷砖铺贴师傅',
                caseCount: 2,
                hiredCount: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('平台咨询暂未开放'), findsOneWidget);
      expect(find.text('客服'), findsNothing);
      expect(find.text('在线'), findsNothing);
      expect(find.textContaining('已有326人'), findsNothing);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('施工案例'), findsWidgets);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('被选中'), findsOneWidget);
      expect(find.text('评价'), findsNothing);
      expect(find.text('好评率'), findsNothing);
      expect(find.text('擅长领域'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('施工标准'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('贴砖'), findsNothing);
      expect(find.textContaining('砌墙'), findsNothing);
      expect(find.textContaining('地面找平'), findsNothing);
    },
  );

  testWidgets('empty favorites still marks worker favorites unavailable', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(store: MemoryOwnerStore());

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: const MaterialApp(home: FavoritesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('师傅收藏暂未开放'), findsOneWidget);
    expect(find.text('暂无报价收藏'), findsOneWidget);
    expect(find.text('去发现师傅'), findsNothing);
  });

  testWidgets('legacy worker favorites never open hard-coded detail', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(store: MemoryOwnerStore());
    await state.toggleFavorite(
      const FavoriteWorker(
        id: 'legacy-worker',
        name: '本地李师傅',
        trade: '拆除师傅',
        city: '成都',
      ),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: const MaterialApp(home: FavoritesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('师傅收藏暂未开放'), findsOneWidget);
    expect(find.text('本地李师傅'), findsNothing);
    expect(find.text('立即预约'), findsNothing);
  });
}

final class _EmptyWorkerCaseApi implements WorkerCaseApi {
  const _EmptyWorkerCaseApi();

  @override
  Future<List<RemoteWorkerCase>> listPublicCases(String workerUserId) async =>
      const [];

  @override
  Future<List<RemoteWorkerCase>> listMyCases(String accessToken) =>
      throw UnimplementedError();

  @override
  Future<RemoteWorkerCase> createCase(
    String accessToken,
    WorkerCaseDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<RemoteWorkerCase> updateCase(
    String accessToken,
    String caseId,
    WorkerCaseDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<void> deleteCase(String accessToken, String caseId) =>
      throw UnimplementedError();

  @override
  Future<String> uploadImage(
    String accessToken, {
    required String filename,
    required List<int> bytes,
  }) => throw UnimplementedError();
}
