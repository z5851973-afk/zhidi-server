import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/pages/worker/worker_case_edit_page.dart';
import 'package:zhidi_app/pages/worker/worker_profile_page.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/worker_case_api_client.dart';

void main() {
  testWidgets('worker profile exposes real case management entry', (
    tester,
  ) async {
    final state = await _completeWorkerState();
    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(home: WorkerProfilePage(caseApi: _CaseApi())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('施工案例管理'), findsOneWidget);
    expect(find.text('添加案例'), findsOneWidget);
  });

  testWidgets('worker selects an image and creates a server case', (
    tester,
  ) async {
    final state = await _completeWorkerState();
    final api = _CaseApi();
    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerProfilePage(
            caseApi: api,
            caseImagePicker: () async => const [
              PickedCaseImage(filename: '现场.jpg', bytes: [0xff, 0xd8, 0xff, 1]),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('添加案例'));
    await tester.tap(find.text('添加案例'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('case-title')), '旧房水电改造');
    await tester.enterText(
      find.byKey(const Key('case-description')),
      '完成全屋水电重新布线与验收',
    );
    await tester.enterText(find.byKey(const Key('case-city')), '成都');
    await tester.enterText(find.byKey(const Key('case-year')), '2026');
    await tester.tap(find.byKey(const Key('case-pick-images')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('case-save')));
    await tester.tap(find.byKey(const Key('case-save')));
    await tester.pumpAndSettle();

    expect(api.uploadedFilename, '现场.jpg');
    expect(api.created?.title, '旧房水电改造');
    expect(api.created?.imageUrls, [
      'https://api.example.test/uploads/cases/generated.jpg',
    ]);
    expect(find.text('旧房水电改造'), findsOneWidget);
  });
}

Future<WorkerAppState> _completeWorkerState() async {
  final state = await WorkerAppState.memory();
  await state.loginOnline(
    const OwnerLoginResponse(
      accessToken: 'worker-jwt',
      tokenType: 'Bearer',
      expiresInSeconds: 3600,
      user: AuthUser(
        id: 'worker-1',
        phone: '13800138102',
        status: 'ACTIVE',
        roles: ['WORKER'],
      ),
    ),
    remoteProfile: const RemoteWorkerProfile(
      userId: 'worker-1',
      phone: '13800138102',
      name: '张师傅',
      serviceCity: '成都',
      primaryTrade: 'plumbing',
      experienceYears: 8,
      dailyRate: 500,
      bio: '擅长旧房水电改造',
      profileComplete: true,
    ),
  );
  return state;
}

final class _CaseApi implements WorkerCaseApi {
  final List<RemoteWorkerCase> cases = [];
  String? uploadedFilename;
  WorkerCaseDraft? created;

  @override
  Future<RemoteWorkerCase> createCase(
    String accessToken,
    WorkerCaseDraft draft,
  ) async {
    created = draft;
    final value = RemoteWorkerCase(
      id: 'case-1',
      workerUserId: 'worker-1',
      title: draft.title,
      description: draft.description,
      serviceCity: draft.serviceCity,
      completionYear: draft.completionYear,
      imageUrls: draft.imageUrls,
      createdAt: DateTime.utc(2026, 7, 16),
      updatedAt: DateTime.utc(2026, 7, 16),
    );
    cases.add(value);
    return value;
  }

  @override
  Future<void> deleteCase(String accessToken, String caseId) async {
    cases.removeWhere((value) => value.id == caseId);
  }

  @override
  Future<List<RemoteWorkerCase>> listMyCases(String accessToken) async =>
      List.unmodifiable(cases);

  @override
  Future<List<RemoteWorkerCase>> listPublicCases(String workerUserId) async =>
      List.unmodifiable(cases);

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
  }) async {
    uploadedFilename = filename;
    return 'https://api.example.test/uploads/cases/generated.jpg';
  }
}
