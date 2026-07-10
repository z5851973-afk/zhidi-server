# Owner Home Live Renovation Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the owner-side `我的家` upper screen into a real renovation project dashboard with a construction-photo Hero, live-looking construction log, compact priority actions, a More bottom sheet, and a lightweight log detail page.

**Architecture:** Keep `MyHomePage` as the owner project dashboard entry point and preserve its existing state reads, bottom navigation, notification route, lower-page sections, and business actions. Add small page-local view models for static construction-log visual data, reuse existing `OwnerAppState` only for current worker, pending inspections, material estimates, and phase progress, and create one focused detail page for log entries. Generated bitmap assets live under `zhidi_app/assets/images/home/`, which is already covered by the `assets/images/` pubspec entry.

**Tech Stack:** Flutter, Material widgets, existing `OwnerAppScope` / `OwnerAppState`, local assets under `zhidi_app/assets/images/`, `flutter_test`.

## Global Constraints

- Only optimize the upper-screen MVP; do not redesign lower material, inspection, worker, archive, or bottom grid modules in this pass.
- The first glance must feel like a real renovation project, not a generic template page.
- The user must immediately know who is working today and what they are doing.
- Use warm white + wood tones; keep orange only for brand/action accents.
- Hero uses a clean carpentry/masonry construction-site image, not a messy site or a finished showroom.
- The construction log is static visual data for this MVP and does not bind to backend or persisted state.
- Hero current-work floating status is display-only and must not navigate.
- Log rows open a lightweight construction log detail page.
- More opens a bottom sheet; entries are ordered with actionable/pending items first.
- Do not add comments, replies, or contact-worker actions.
- Do not change the bottom main navigation.

---

## File Structure

- Modify: `zhidi_app/lib/pages/home/my_home_page.dart`
  - Replace the current Hero, five-item quick actions, progress/reminder/next-step upper stack with the live renovation upper screen.
  - Keep the lower sections and existing business panels below the new upper screen.
  - Add page-local `_ConstructionLogEntry`, `_LogKind`, `_PriorityActions`, `_ConstructionLogFeed`, and More bottom sheet helpers.
- Create: `zhidi_app/lib/pages/home/construction_log_detail_page.dart`
  - Small read-only detail page for one static log entry.
- Add assets:
  - `zhidi_app/assets/images/home/live_renovation_hero.jpg`
  - `zhidi_app/assets/images/home/live_log_tile_01.jpg`
  - `zhidi_app/assets/images/home/live_log_tile_02.jpg`
  - `zhidi_app/assets/images/home/live_log_tile_03.jpg`
  - `zhidi_app/assets/images/home/live_log_tile_04.jpg`
- Modify: `zhidi_app/test/my_home_page_visual_test.dart`
  - Update upper-screen visual tests to assert new Hero, current-work overlay, construction log, compact actions, More sheet, and detail navigation.

## Task 1: Prepare Construction Image Assets

**Files:**
- Add: `zhidi_app/assets/images/home/live_renovation_hero.jpg`
- Add: `zhidi_app/assets/images/home/live_log_tile_01.jpg`
- Add: `zhidi_app/assets/images/home/live_log_tile_02.jpg`
- Add: `zhidi_app/assets/images/home/live_log_tile_03.jpg`
- Add: `zhidi_app/assets/images/home/live_log_tile_04.jpg`

**Interfaces:**
- Consumes: approved style direction from `docs/superpowers/specs/2026-07-10-owner-home-live-renovation-dashboard-design.md`
- Produces: stable asset paths consumed by `_HeroHeader` and `_ConstructionLogEntry.imageAsset`

- [ ] **Step 1: Generate five clean renovation photos**

Use the built-in ImageGen flow, one image per prompt, and save/copy the final images into `zhidi_app/assets/images/home/`.

Hero prompt:

```text
Photorealistic clean apartment renovation interior during carpentry and masonry stage, warm white walls, natural wood cabinet framing, unfinished but tidy floor protection, soft daylight from window, home taking shape, platform-reviewed construction photo, no prominent people, no logos, no text, no watermark, mobile hero background, leave darker readable space near lower third.
```

Log prompts:

```text
1. Clean tile and masonry progress in a Chinese apartment bathroom, warm daylight, tidy tools, platform-reviewed construction photo, no text or logos.
2. Wooden cabinet installation progress in a bright apartment living room, warm wood tones, tidy site, no text or logos.
3. Wall finishing and protected floor in a renovation site, warm white and wood tones, clean platform-reviewed progress photo, no text or logos.
4. Detail shot of carpentry boards and measuring tools in a tidy home renovation interior, warm natural light, no text or logos.
```

- [ ] **Step 2: Copy selected images into project assets**

Create the directory if needed. After each ImageGen call, the tool returns an absolute file path. Copy each returned path to its matching project asset path. The destination filenames must be exactly the five names below:

```bash
mkdir -p zhidi_app/assets/images/home
```

Destination filenames:

```text
zhidi_app/assets/images/home/live_renovation_hero.jpg
zhidi_app/assets/images/home/live_log_tile_01.jpg
zhidi_app/assets/images/home/live_log_tile_02.jpg
zhidi_app/assets/images/home/live_log_tile_03.jpg
zhidi_app/assets/images/home/live_log_tile_04.jpg
```

Expected: all five files exist under `zhidi_app/assets/images/home/`.

- [ ] **Step 3: Verify Flutter asset coverage**

Run:

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app && flutter test test/my_home_page_visual_test.dart --plain-name "my home page renders core refreshed sections"
```

Expected before code changes: test may fail on old UI expectations, but Flutter should not report missing asset manifest errors for `assets/images/home/...` once referenced in later tasks because `pubspec.yaml` already includes `assets/images/`.

- [ ] **Step 4: Commit assets**

```bash
git add zhidi_app/assets/images/home
git commit -m "assets(owner): add live renovation home imagery"
```

## Task 2: Update Upper-Screen Regression Tests

**Files:**
- Modify: `zhidi_app/test/my_home_page_visual_test.dart`

**Interfaces:**
- Consumes: `MyHomePage`
- Produces: failing tests for keys and navigation added in Tasks 3 and 4

- [ ] **Step 1: Replace the core section assertions**

Change the first test to assert the new upper-screen anchors:

```dart
testWidgets('my home page renders live renovation upper screen', (tester) async {
  await _pumpMyHome(tester, width: 390);

  expect(find.byKey(const Key('my-home-hero')), findsOneWidget);
  expect(find.byKey(const Key('my-home-current-work-card')), findsOneWidget);
  expect(find.byKey(const Key('my-home-priority-actions')), findsOneWidget);
  expect(find.byKey(const Key('my-home-construction-log')), findsOneWidget);
  expect(find.text('今日现场'), findsOneWidget);
  expect(find.text('待处理'), findsWidgets);
  expect(find.text('施工进度'), findsWidgets);
  expect(find.text('更多'), findsOneWidget);
});
```

- [ ] **Step 2: Replace old ordered-card test with new upper-screen order test**

```dart
testWidgets('current work and construction log appear before lower cards', (tester) async {
  await _pumpMyHome(tester, width: 390);

  final heroTop = tester.getTopLeft(find.byKey(const Key('my-home-hero')));
  final actionsTop = tester.getTopLeft(find.byKey(const Key('my-home-priority-actions')));
  final logTop = tester.getTopLeft(find.byKey(const Key('my-home-construction-log')));
  final inspectionBannerTop = tester.getTopLeft(find.text('平台监理验收服务'));

  expect(heroTop.dy, lessThan(actionsTop.dy));
  expect(actionsTop.dy, lessThan(logTop.dy));
  expect(logTop.dy, lessThan(inspectionBannerTop.dy));
});
```

- [ ] **Step 3: Add More sheet test**

```dart
testWidgets('more action opens project action sheet', (tester) async {
  await _pumpMyHome(tester, width: 390);

  await tester.tap(find.text('更多'));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('my-home-more-sheet')), findsOneWidget);
  expect(find.text('更多项目服务'), findsOneWidget);
  expect(find.text('我的工人'), findsOneWidget);
  expect(find.text('材料清单'), findsOneWidget);
  expect(find.text('平台保障'), findsOneWidget);
});
```

- [ ] **Step 4: Add construction detail navigation test**

```dart
testWidgets('construction log opens detail page', (tester) async {
  await _pumpMyHome(tester, width: 390);

  await tester.tap(find.byKey(const Key('construction-log-entry-0')));
  await tester.pumpAndSettle();

  expect(find.text('施工动态'), findsOneWidget);
  expect(find.byKey(const Key('construction-log-detail-image')), findsOneWidget);
  expect(find.text('木工'), findsWidgets);
});
```

- [ ] **Step 5: Run tests and verify they fail for missing new UI**

Run:

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app && flutter test test/my_home_page_visual_test.dart
```

Expected: FAIL because `my-home-current-work-card`, `my-home-priority-actions`, `my-home-construction-log`, More sheet, and detail page are not implemented yet.

- [ ] **Step 6: Commit failing tests**

```bash
git add zhidi_app/test/my_home_page_visual_test.dart
git commit -m "test(owner): cover live renovation home upper screen"
```

## Task 3: Implement Live Renovation Hero, Priority Actions, And Log Feed

**Files:**
- Modify: `zhidi_app/lib/pages/home/my_home_page.dart`

**Interfaces:**
- Consumes:
  - `List<BookedWorker> activeWorkers`
  - `List<_Phase> phases`
  - `List<InspectionRequest> pendingInspections`
  - `List<MaterialEstimate> state.materialEstimates`
- Produces:
  - `_ConstructionLogEntry`
  - `_buildConstructionLogs(BookedWorker? currentWorker, List<_Phase> phases): List<_ConstructionLogEntry>`
  - `_HeroHeader(currentWorker: BookedWorker?)`
  - `_PriorityActions(pendingCount: int, onMoreTap: VoidCallback)`
  - `_ConstructionLogFeed(sectionKey: GlobalKey, entries: List<_ConstructionLogEntry>, onEntryTap: void Function(_ConstructionLogEntry))`

- [ ] **Step 1: Add imports**

Add the detail page import at the top of `my_home_page.dart`:

```dart
import 'construction_log_detail_page.dart';
```

- [ ] **Step 2: Compute current worker and logs in `build`**

Inside `_MyHomePageState.build`, after `pendingInspections`:

```dart
final currentWorker = activeWorkers.isNotEmpty
    ? activeWorkers[_currentWorkerIndex.clamp(0, activeWorkers.length - 1)]
    : null;
final constructionLogs = _buildConstructionLogs(currentWorker, phases);
final pendingActionCount = pendingInspections.length + state.materialEstimates.where((e) => e.status == EstimateStatus.pending).length;
```

Add this field to `_MyHomePageState` so the progress action can scroll to the construction log:

```dart
final _constructionLogKey = GlobalKey();
```

- [ ] **Step 3: Replace the upper-screen widget stack**

Replace the old Hero through `_NextStepCard` block with:

```dart
_HeroHeader(
  address: '金牛区 XX小区 3栋2单元',
  projectName: '全屋装修',
  workerCount: activeWorkers.length,
  notificationCount: 3,
  currentWorker: currentWorker,
  onNotificationTap: () => _push(Scaffold(
    appBar: AppBar(title: const Text('通知消息')),
    body: const MessagePage(),
  )),
),
if (conflicts.isNotEmpty)
  _ConflictBanner(conflicts: conflicts, onPush: _push, phases: phases),
_PriorityActions(
  pendingCount: pendingActionCount,
  onProgressTap: () => Scrollable.ensureVisible(
    _constructionLogKey.currentContext ?? context,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
  ),
  onMoreTap: () => _showMoreActionsSheet(
    context,
    pendingInspections: pendingInspections,
    hasPendingMaterials: state.materialEstimates.any((e) => e.status == EstimateStatus.pending),
  ),
),
_ConstructionLogFeed(
  sectionKey: _constructionLogKey,
  entries: constructionLogs,
  onEntryTap: (entry) => _push(ConstructionLogDetailPage(entry: entry.toDetailData())),
),
```

Keep the lower `InspectionPanel`, `MaterialEstimatePanel`, `InspectionBanner`, worker, archive, and bottom grid sections unchanged.

- [ ] **Step 4: Add static log data model**

Place near `_Phase`:

```dart
enum _LogKind { currentWork, pending, progress, nextStep }

class _ConstructionLogEntry {
  const _ConstructionLogEntry({
    required this.kind,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.workerName,
    required this.trade,
    required this.phaseTag,
    required this.imageAsset,
  });

  final _LogKind kind;
  final String title;
  final String body;
  final String timeLabel;
  final String workerName;
  final String trade;
  final String phaseTag;
  final String imageAsset;

  ConstructionLogDetailData toDetailData() {
    return ConstructionLogDetailData(
      title: title,
      body: body,
      timeLabel: timeLabel,
      workerName: workerName,
      trade: trade,
      phaseTag: phaseTag,
      imageAsset: imageAsset,
    );
  }
}
```

- [ ] **Step 5: Add log builder**

```dart
List<_ConstructionLogEntry> _buildConstructionLogs(BookedWorker? currentWorker, List<_Phase> phases) {
  final workerName = currentWorker?.name ?? '陈志远';
  final trade = currentWorker?.trade ?? '水电工';
  final currentPhase = phases.cast<_Phase?>().firstWhere(
    (phase) => phase?.status == _PhaseStatus.current,
    orElse: () => null,
  );
  final nextPhase = phases.cast<_Phase?>().firstWhere(
    (phase) => phase?.status == _PhaseStatus.available,
    orElse: () => null,
  );
  final doneCount = phases.where((phase) => phase.status == _PhaseStatus.done).length;

  return [
    _ConstructionLogEntry(
      kind: _LogKind.currentWork,
      title: '$workerName今天在做${currentPhase?.name ?? '水电'}收尾',
      body: '现场正在整理线路和墙面细节，晚上前会同步新的施工照片。',
      timeLabel: '今天 09:30',
      workerName: workerName,
      trade: trade,
      phaseTag: currentPhase?.name ?? '水电',
      imageAsset: 'assets/images/home/live_log_tile_01.jpg',
    ),
    _ConstructionLogEntry(
      kind: _LogKind.pending,
      title: '请确认防水测试配合事项',
      body: '楼下邻居沟通完成后，防水测试会更顺利，平台会继续提醒关键节点。',
      timeLabel: '今天 11:20',
      workerName: workerName,
      trade: trade,
      phaseTag: '待处理',
      imageAsset: 'assets/images/home/live_log_tile_02.jpg',
    ),
    _ConstructionLogEntry(
      kind: _LogKind.progress,
      title: '当前已完成 $doneCount/${phases.length} 个工序',
      body: '施工节奏正常，已完成的节点会进入装修档案，方便后续回看。',
      timeLabel: '昨天 18:10',
      workerName: '知底项目助手',
      trade: '项目进度',
      phaseTag: '进度',
      imageAsset: 'assets/images/home/live_log_tile_03.jpg',
    ),
    _ConstructionLogEntry(
      kind: _LogKind.nextStep,
      title: '下一步准备${nextPhase?.name ?? '泥工'}进场',
      body: '建议提前确认师傅进场时间，材料和现场条件会一并核对。',
      timeLabel: '昨天 15:40',
      workerName: '知底项目助手',
      trade: '下一步',
      phaseTag: nextPhase?.name ?? '泥工',
      imageAsset: 'assets/images/home/live_log_tile_04.jpg',
    ),
  ];
}
```

- [ ] **Step 6: Update `_HeroHeader` signature and implementation**

Add `currentWorker` to constructor and fields:

```dart
required this.currentWorker,
final BookedWorker? currentWorker;
```

Use this high-level structure inside `build`:

```dart
return Container(
  key: const Key('my-home-hero'),
  height: 286,
  decoration: const BoxDecoration(
    image: DecorationImage(
      image: AssetImage('assets/images/home/live_renovation_hero.jpg'),
      fit: BoxFit.cover,
      alignment: Alignment.center,
    ),
  ),
  child: Stack(
    children: [
      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withValues(alpha: .18), Colors.black.withValues(alpha: .58)], begin: Alignment.topCenter, end: Alignment.bottomCenter)))),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '我的家',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                GestureDetector(
                  key: const Key('my-home-hero-bell'),
                  onTap: onNotificationTap,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.notifications_none, color: Colors.white, size: 22),
                        if (notificationCount > 0)
                          Positioned(
                            top: 7,
                            right: 7,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(color: Color(0xFFFF3B30), shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text(
                                '$notificationCount',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(address, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: .82))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text(projectName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white))),
              _WorkerCountPill(workerCount: workerCount),
            ]),
            const SizedBox(height: 14),
            _CurrentWorkCard(worker: currentWorker),
          ],
        ),
      ),
    ],
  ),
);
```

- [ ] **Step 7: Add current work card**

```dart
class _CurrentWorkCard extends StatelessWidget {
  const _CurrentWorkCard({required this.worker});
  final BookedWorker? worker;

  @override
  Widget build(BuildContext context) {
    final name = worker?.name ?? '陈志远';
    final trade = worker?.trade ?? '水电工';
    final avatar = worker?.avatarEmoji ?? '工';
    return Container(
      key: const Key('my-home-current-work-card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.white, child: Text(avatar, style: const TextStyle(color: _primary, fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$name · $trade', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 3),
            Text('今天在做水电收尾，晚上前会同步现场照片', style: TextStyle(color: Colors.white.withValues(alpha: .86), fontSize: 12, height: 1.35)),
          ])),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Add priority actions widgets**

Add:

```dart
class _PriorityActions extends StatelessWidget {
  const _PriorityActions({
    required this.pendingCount,
    required this.onProgressTap,
    required this.onMoreTap,
  });

  final int pendingCount;
  final VoidCallback onProgressTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Row(
        key: const Key('my-home-priority-actions'),
        children: [
          Expanded(
            child: _PriorityActionTile(
              icon: Icons.notifications_none_rounded,
              title: '待处理',
              subtitle: pendingCount > 0 ? '$pendingCount 项需要确认' : '暂无待办',
              badge: pendingCount > 0 ? '$pendingCount' : null,
              onTap: () {},
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PriorityActionTile(
              icon: Icons.route_rounded,
              title: '施工进度',
              subtitle: '查看阶段推进',
              onTap: onProgressTap,
            ),
          ),
          const SizedBox(width: 10),
          _MoreActionButton(onTap: onMoreTap),
        ],
      ),
    );
  }
}
```

- [ ] **Step 9: Add log feed widgets**

Add:

```dart
class _ConstructionLogFeed extends StatelessWidget {
  const _ConstructionLogFeed({
    required this.sectionKey,
    required this.entries,
    required this.onEntryTap,
  });

  final GlobalKey sectionKey;
  final List<_ConstructionLogEntry> entries;
  final void Function(_ConstructionLogEntry entry) onEntryTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 4),
      child: Column(
        key: sectionKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(key: Key('my-home-construction-log'), height: 0),
          const Text('今日现场', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textDark)),
          const SizedBox(height: 10),
          for (var index = 0; index < entries.length; index++)
            _ConstructionLogTile(
              key: Key('construction-log-entry-$index'),
              entry: entries[index],
              onTap: () => onEntryTap(entries[index]),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 10: Run tests**

Run:

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app && flutter test test/my_home_page_visual_test.dart
```

Expected: More sheet and detail navigation tests may still fail until Task 4; upper-screen render/order tests should pass.

- [ ] **Step 11: Commit upper-screen implementation**

```bash
git add zhidi_app/lib/pages/home/my_home_page.dart
git commit -m "feat(owner): add live renovation home upper screen"
```

## Task 4: Implement More Bottom Sheet And Construction Log Detail Page

**Files:**
- Create: `zhidi_app/lib/pages/home/construction_log_detail_page.dart`
- Modify: `zhidi_app/lib/pages/home/my_home_page.dart`
- Test: `zhidi_app/test/my_home_page_visual_test.dart`

**Interfaces:**
- Consumes:
  - `_ConstructionLogEntry.toDetailData()`
  - `_showMoreActionsSheet(BuildContext, {required List<InspectionRequest> pendingInspections, required bool hasPendingMaterials})`
- Produces:
  - `ConstructionLogDetailData`
  - `ConstructionLogDetailPage`
  - More sheet key `my-home-more-sheet`

- [ ] **Step 1: Create detail data and page**

Create `construction_log_detail_page.dart`:

```dart
import 'package:flutter/material.dart';
import '../../design/tokens.dart';

class ConstructionLogDetailData {
  const ConstructionLogDetailData({
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.workerName,
    required this.trade,
    required this.phaseTag,
    required this.imageAsset,
  });

  final String title;
  final String body;
  final String timeLabel;
  final String workerName;
  final String trade;
  final String phaseTag;
  final String imageAsset;
}

class ConstructionLogDetailPage extends StatelessWidget {
  const ConstructionLogDetailPage({super.key, required this.entry});
  final ConstructionLogDetailData entry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text('施工动态'),
        backgroundColor: ZdColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                entry.imageAsset,
                key: const Key('construction-log-detail-image'),
                width: double.infinity,
                height: 260,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              children: [
                _DetailTag(entry.phaseTag),
                _DetailTag(entry.trade),
              ],
            ),
            const SizedBox(height: 14),
            Text(entry.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ZdColors.textPrimary, height: 1.25)),
            const SizedBox(height: 10),
            Text(entry.body, style: const TextStyle(fontSize: 15, color: ZdColors.textSecondary, height: 1.6)),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 18, color: ZdColors.textSecondary),
                const SizedBox(width: 6),
                Text('${entry.workerName} · ${entry.timeLabel}', style: const TextStyle(fontSize: 13, color: ZdColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTag extends StatelessWidget {
  const _DetailTag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ZdColors.surfaceWarm,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE9DDD0)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, color: ZdColors.textSecondary, fontWeight: FontWeight.w600)),
    );
  }
}
```

- [ ] **Step 2: Add More sheet helper**

In `_MyHomePageState`, add:

```dart
void _showMoreActionsSheet(
  BuildContext context, {
  required List<InspectionRequest> pendingInspections,
  required bool hasPendingMaterials,
}) {
  final items = <_MoreActionItem>[
    _MoreActionItem(Icons.receipt_long_rounded, '材料清单', hasPendingMaterials ? '待确认材料' : '查看材料明细', hasPendingMaterials),
    _MoreActionItem(Icons.person_rounded, '我的工人', '查看已预约师傅', false),
    _MoreActionItem(Icons.shield_outlined, '平台保障', '查看保障说明', false),
  ]..sort((a, b) => b.isPending.toString().compareTo(a.isPending.toString()));

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _MoreActionsSheet(items: items),
  );
}
```

- [ ] **Step 3: Add `_MoreActionItem` and `_MoreActionsSheet`**

```dart
class _MoreActionItem {
  const _MoreActionItem(this.icon, this.title, this.subtitle, this.isPending);
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPending;
}

class _MoreActionsSheet extends StatelessWidget {
  const _MoreActionsSheet({required this.items});
  final List<_MoreActionItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('my-home-more-sheet'),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
      decoration: const BoxDecoration(
        color: ZdColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFFD8CEC4), borderRadius: BorderRadius.circular(999)))),
          const SizedBox(height: 18),
          const Text('更多项目服务', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textDark)),
          const SizedBox(height: 12),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: item.isPending ? const Color(0xFFFFF2E8) : ZdColors.surfaceWarm, child: Icon(item.icon, color: item.isPending ? _primary : _textMid)),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, color: _textDark)),
              subtitle: Text(item.subtitle),
              trailing: item.isPending ? const Text('待处理', style: TextStyle(color: _primary, fontWeight: FontWeight.w700)) : const Icon(Icons.chevron_right_rounded),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app && flutter test test/my_home_page_visual_test.dart
```

Expected: PASS.

- [ ] **Step 5: Run analyzer**

Run:

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app && flutter analyze lib/pages/home/my_home_page.dart lib/pages/home/construction_log_detail_page.dart test/my_home_page_visual_test.dart
```

Expected: `No issues found!`

- [ ] **Step 6: Commit detail and More sheet**

```bash
git add zhidi_app/lib/pages/home/my_home_page.dart zhidi_app/lib/pages/home/construction_log_detail_page.dart zhidi_app/test/my_home_page_visual_test.dart
git commit -m "feat(owner): add construction log detail and more actions"
```

## Self-Review

- Spec coverage: Hero image, current-work floating status, construction log, images, compact actions, More sheet, detail page, static visual data, and upper-screen-only scope are all covered by Tasks 1-4.
- Placeholder scan: complete; no red-flag placeholder language remains.
- Type consistency: `_ConstructionLogEntry.toDetailData()` produces `ConstructionLogDetailData`; `ConstructionLogDetailPage` consumes that type; `_PriorityActions` and `_showMoreActionsSheet` are defined before use in the plan.
