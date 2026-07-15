import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/models/renovation.dart';
import 'package:zhidi_app/pages/renovation/worker_detail_page.dart';
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
}
