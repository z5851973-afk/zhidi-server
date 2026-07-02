import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/my_home_page.dart';
import 'package:zhidi_app/pages/home/worker/worker_detail_page.dart';

Widget _app(OwnerAppState state) => OwnerAppScope(
  state: state,
  child: const MaterialApp(home: Scaffold(body: MyHomePage())),
);

Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  testWidgets('uses Chengdu project and 2026 schedule from owner state', (
    tester,
  ) async {
    await tester.pumpWidget(_app(OwnerAppState.memory()));

    expect(find.text('麓湖新居翻新'), findsOneWidget);
    expect(find.textContaining('成都'), findsWidgets);
    expect(find.text('2项待处理'), findsOneWidget);
    await _scrollTo(tester, '查看下一步');
    expect(find.textContaining('2026-07-04'), findsOneWidget);
  });

  testWidgets('project operations open focused pages and edit persists', (
    tester,
  ) async {
    final document = OwnerAppState.memory().toJson();
    document['projects'] = [
      ...(document['projects'] as List<dynamic>),
      OwnerProject(
        id: 'project-2',
        name: '锦江花园局部改造',
        city: '成都',
        address: '锦江区静安路 88 号',
        startDate: DateTime(2026, 8, 6),
      ).toJson(),
    ];
    final state = OwnerAppState.fromJson(document);
    await tester.pumpWidget(_app(state));

    await tester.tap(find.text('切换项目'));
    await tester.pumpAndSettle();
    expect(find.text('选择项目'), findsOneWidget);
    await tester.tap(find.text('锦江花园局部改造'));
    await tester.pumpAndSettle();
    expect(state.selectedProjectId, 'project-2');
    expect(find.text('锦江花园局部改造'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('编辑项目'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('project-name-field')),
      '麓湖 2026 新家',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(state.selectedProject!.name, '麓湖 2026 新家');

    for (final entry in <String, String>{
      '项目成员': '项目成员',
      '项目群聊': '麓湖 2026 新家项目群',
      '项目设置': '项目设置',
    }.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('分享家'));
    await tester.pump();
    expect(find.text('项目分享信息已准备'), findsOneWidget);
  });

  testWidgets('reminder completion updates pending count and is recoverable', (
    tester,
  ) async {
    final state = OwnerAppState.memory();
    await tester.pumpWidget(_app(state));

    await tester.tap(find.text('完成').first);
    await tester.pumpAndSettle();
    expect(find.text('1项待处理'), findsOneWidget);
    expect(state.reminders.where((item) => !item.isCompleted), hasLength(1));
  });

  testWidgets('lower dashboard actions navigate to truthful destinations', (
    tester,
  ) async {
    await tester.pumpWidget(_app(OwnerAppState.memory()));

    for (final entry in <String, String>{
      '查看下一步': '下一步计划',
      '查看全部工人': '全部工人',
      '查看验收记录': '验收记录',
      '查看全部档案': '装修档案',
      '了解资金托管': '资金托管说明',
      '申请售后': '保障与售后',
    }.entries) {
      await _scrollTo(tester, entry.key);
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('uses selected status and identifies project-scoped content', (
    tester,
  ) async {
    final json = OwnerAppState.memory().toJson();
    final project = OwnerProject.fromJson(
      Map<String, dynamic>.from((json['projects'] as List).single as Map),
    );
    json['projects'] = [project.copyWith(status: '已竣工').toJson()];
    final state = OwnerAppState.fromJson(json);
    await tester.pumpWidget(_app(state));

    expect(find.text('已竣工'), findsOneWidget);
    await tester.tap(find.text('项目成员'));
    await tester.pumpAndSettle();
    expect(find.textContaining(project.name), findsWidgets);
  });

  testWidgets('worker rows and all-workers page open stable worker details', (
    tester,
  ) async {
    await tester.pumpWidget(_app(OwnerAppState.memory()));
    await _scrollTo(tester, '李师傅 · 水电工');
    await tester.ensureVisible(find.text('李师傅 · 水电工'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('李师傅 · 水电工'));
    await tester.pumpAndSettle();
    final detail = tester.widget<WorkerDetailPage>(
      find.byType(WorkerDetailPage),
    );
    expect(detail.workerId, 'project-1-worker-electrician-li');
    await tester.tap(find.byIcon(Icons.arrow_back_ios_rounded));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('联系').first);
    await tester.tap(find.text('联系').first);
    await tester.pumpAndSettle();
    expect(find.text('李师傅'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _scrollTo(tester, '查看全部工人');
    await tester.ensureVisible(find.text('查看全部工人'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看全部工人'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('王师傅 · 瓦工'));
    await tester.pumpAndSettle();
    final allDetail = tester.widget<WorkerDetailPage>(
      find.byType(WorkerDetailPage),
    );
    expect(allDetail.workerId, 'project-1-worker-mason-wang');
  });

  testWidgets('project notification switch persists and reports failure', (
    tester,
  ) async {
    final store = MemoryOwnerStore();
    final state = OwnerAppState.memory(store: store);
    await tester.pumpWidget(_app(state));
    await tester.tap(find.text('项目设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(state.settings.projectNotifications, isFalse);
    expect(
      OwnerAppState.memory(store: store).settings.projectNotifications,
      isFalse,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    final failing = OwnerAppState.memory(store: _FailingOwnerStore());
    await tester.pumpWidget(_app(failing));
    await tester.tap(find.text('项目设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(failing.settings.projectNotifications, isTrue);
    expect(find.text('设置保存失败，请重试'), findsOneWidget);
  });

  testWidgets('switching projects changes scoped people and records', (
    tester,
  ) async {
    final document = OwnerAppState.memory().toJson();
    document['profile'] = const OwnerProfile(name: '刘女士', city: '成都').toJson();
    document['projects'] = [
      OwnerProject(
        id: 'project-a',
        name: '青羊新家',
        city: '成都',
        address: '青羊区 1 号',
        startDate: DateTime(2026, 7, 1),
      ).toJson(),
      OwnerProject(
        id: 'project-b',
        name: '锦江新家',
        city: '成都',
        address: '锦江区 2 号',
        startDate: DateTime(2026, 9, 10),
        status: '待开工',
      ).toJson(),
    ];
    document['selectedProjectId'] = 'project-a';
    final state = OwnerAppState.fromJson(document);
    await tester.pumpWidget(_app(state));

    await tester.tap(find.text('项目成员'));
    await tester.pumpAndSettle();
    expect(find.text('刘女士 · 业主'), findsOneWidget);
    expect(find.text('周工 · 项目经理'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _scrollTo(tester, '李师傅 · 水电工');
    expect(find.text('李师傅 · 水电工'), findsOneWidget);
    await _scrollTo(tester, '施工图纸 12份');
    expect(find.text('施工图纸 12份'), findsOneWidget);

    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 2000),
      2000,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('切换项目'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('锦江新家'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('项目成员'));
    await tester.pumpAndSettle();
    expect(find.text('刘女士 · 业主'), findsOneWidget);
    expect(find.text('郑工 · 项目经理'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _scrollTo(tester, '陈师傅 · 水电工');
    expect(find.text('陈师傅 · 水电工'), findsOneWidget);
    await _scrollTo(tester, '施工图纸 9份');
    expect(find.text('施工图纸 9份'), findsOneWidget);
    await _scrollTo(tester, '查看验收记录');
    await tester.tap(find.text('查看验收记录'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-09-25'), findsOneWidget);
    expect(find.textContaining('待开工'), findsWidgets);
  });

  testWidgets('top notification and full progress actions navigate', (
    tester,
  ) async {
    await tester.pumpWidget(_app(OwnerAppState.memory()));

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    expect(find.text('消息'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _scrollTo(tester, '查看全部进度');
    await tester.tap(find.text('查看全部进度'));
    await tester.pumpAndSettle();
    expect(find.text('装修进度'), findsWidgets);
    expect(find.textContaining('进行中'), findsWidgets);
  });

  testWidgets('project fixtures remain stable after reorder and insertion', (
    tester,
  ) async {
    OwnerProject project(String id, String name) => OwnerProject(
      id: id,
      name: name,
      city: '成都',
      address: '$name地址',
      startDate: DateTime(2026, 9, 10),
    );

    OwnerAppState stateFor(List<OwnerProject> projects) {
      final json = OwnerAppState.memory().toJson();
      json['projects'] = projects.map((item) => item.toJson()).toList();
      json['selectedProjectId'] = 'project-b';
      return OwnerAppState.fromJson(json);
    }

    final a = project('project-a', '项目 A');
    final b = project('project-b', '项目 B');
    final inserted = project('project-inserted', '新增项目');

    Future<void> verifyStableFixture(OwnerAppState state) async {
      await tester.pumpWidget(_app(state));
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 2000),
        2000,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('项目成员'));
      await tester.pumpAndSettle();
      expect(find.text('郑工 · 项目经理'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _scrollTo(tester, '陈师傅 · 水电工');
      await tester.ensureVisible(find.text('陈师傅 · 水电工'));
      await tester.tap(find.text('陈师傅 · 水电工'));
      await tester.pumpAndSettle();
      final detail = tester.widget<WorkerDetailPage>(
        find.byType(WorkerDetailPage),
      );
      expect(detail.workerId, 'project-b-worker-electrician-chen');
      await tester.tap(find.byIcon(Icons.arrow_back_ios_rounded));
      await tester.pumpAndSettle();
    }

    await verifyStableFixture(stateFor([a, b]));
    await verifyStableFixture(stateFor([b, inserted, a]));
  });

  testWidgets('completed project shows complete progress and no future phase', (
    tester,
  ) async {
    final json = OwnerAppState.memory().toJson();
    final original = OwnerProject.fromJson(
      Map<String, dynamic>.from((json['projects'] as List).single as Map),
    );
    json['projects'] = [original.copyWith(status: '已竣工').toJson()];
    await tester.pumpWidget(_app(OwnerAppState.fromJson(json)));

    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, 1);
    await _scrollTo(tester, '项目已竣工');
    expect(find.text('项目已竣工'), findsOneWidget);
    expect(find.text('瓦泥施工'), findsNothing);
    await _scrollTo(tester, '查看全部进度');
    await tester.tap(find.text('查看全部进度'));
    await tester.pumpAndSettle();
    expect(find.text('竣工验收 · 已完成'), findsOneWidget);
  });

  testWidgets('pending reminders include overdue current and future work', (
    tester,
  ) async {
    final json = OwnerAppState.memory().toJson();
    json['reminders'] = [
      OwnerReminder(
        id: 'overdue',
        title: '逾期事项',
        dueAt: DateTime(2026, 6, 1),
        projectId: 'project-1',
      ).toJson(),
      OwnerReminder(
        id: 'current',
        title: '当前事项',
        dueAt: DateTime(2026, 7, 2),
        projectId: 'project-1',
      ).toJson(),
      OwnerReminder(
        id: 'future',
        title: '未来事项',
        dueAt: DateTime(2026, 12, 1),
        projectId: 'project-1',
      ).toJson(),
    ];
    await tester.pumpWidget(_app(OwnerAppState.fromJson(json)));

    expect(find.text('待办提醒'), findsOneWidget);
    expect(find.text('今日提醒'), findsNothing);
    expect(find.text('3项待处理'), findsOneWidget);
    expect(find.text('逾期事项'), findsOneWidget);
    expect(find.text('当前事项'), findsOneWidget);
    expect(find.text('未来事项'), findsOneWidget);
  });
}

class _FailingOwnerStore implements OwnerKeyValueStore {
  @override
  String? getString(String key) => null;

  @override
  Future<void> setString(String key, String value) async {
    throw StateError('write failed');
  }
}
