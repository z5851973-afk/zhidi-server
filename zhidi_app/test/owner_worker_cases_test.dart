import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/models/renovation.dart';
import 'package:zhidi_app/pages/renovation/worker_detail_page.dart';
import 'package:zhidi_app/services/worker_case_api_client.dart';
import 'package:zhidi_app/services/worker_directory_api_client.dart';

void main() {
  testWidgets('owner detail renders server cases for a remote worker', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(store: MemoryOwnerStore());
    final api = _PublicCaseApi();
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerDetailPage(
            workerName: '张师傅',
            trade: Trade.plumbing,
            caseApi: api,
            remoteProfile: const RemoteWorkerDirectoryProfile(
              userId: 'worker-1',
              name: '张师傅',
              serviceCity: '成都',
              primaryTrade: 'plumbing',
              experienceYears: 8,
              dailyRate: 500,
              bio: '擅长旧房水电改造',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('旧房水电改造'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );

    expect(api.requestedWorkerId, 'worker-1');
    expect(find.text('旧房水电改造'), findsOneWidget);
    expect(find.textContaining('全屋重新布线'), findsOneWidget);
    expect(find.textContaining('共1组'), findsOneWidget);
    final image = tester.widget<Image>(
      find.byKey(const Key('worker-case-image-case-1')),
    );
    expect(
      (image.image as NetworkImage).url,
      'https://api.example.test/uploads/cases/real.jpg',
    );
  });

  testWidgets('remote worker without cases shows explicit empty state', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(store: MemoryOwnerStore());
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerDetailPage(
            workerName: '空案例师傅',
            trade: Trade.plumbing,
            caseApi: _PublicCaseApi(empty: true),
            remoteProfile: const RemoteWorkerDirectoryProfile(
              userId: 'worker-empty',
              name: '空案例师傅',
              serviceCity: '成都',
              primaryTrade: 'plumbing',
              experienceYears: 2,
              dailyRate: 300,
              bio: '新入驻工人',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('暂无施工案例'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );

    expect(find.text('暂无施工案例'), findsOneWidget);
    expect(find.byKey(const Key('worker-case-mock-gallery')), findsNothing);
  });
}

final class _PublicCaseApi implements WorkerCaseApi {
  _PublicCaseApi({this.empty = false});

  final bool empty;
  String? requestedWorkerId;

  @override
  Future<List<RemoteWorkerCase>> listPublicCases(String workerUserId) async {
    requestedWorkerId = workerUserId;
    if (empty) return const [];
    return [
      RemoteWorkerCase(
        id: 'case-1',
        workerUserId: workerUserId,
        title: '旧房水电改造',
        description: '完成全屋重新布线与验收',
        serviceCity: '成都',
        completionYear: 2026,
        imageUrls: const ['https://api.example.test/uploads/cases/real.jpg'],
        createdAt: DateTime.utc(2026, 7, 16),
        updatedAt: DateTime.utc(2026, 7, 16),
      ),
    ];
  }

  @override
  Future<RemoteWorkerCase> createCase(
    String accessToken,
    WorkerCaseDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<void> deleteCase(String accessToken, String caseId) =>
      throw UnimplementedError();

  @override
  Future<List<RemoteWorkerCase>> listMyCases(String accessToken) =>
      throw UnimplementedError();

  @override
  Future<RemoteWorkerCase> updateCase(
    String accessToken,
    String caseId,
    WorkerCaseDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<String> uploadImage(
    String accessToken, {
    required String filename,
    required List<int> bytes,
  }) => throw UnimplementedError();
}
