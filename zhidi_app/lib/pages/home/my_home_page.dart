import 'package:flutter/material.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_models.dart';

import '../message/message_page.dart';
import '../renovation/worker_chat_page.dart';
import '../renovation/worker_detail_page.dart';
import '../price/worker_quote_page.dart';
import '../../data/price_standards.dart';
import 'renovation_archive_page.dart';
import '../../design/tokens.dart';

// ============================================================
// 颜色常量
// ============================================================
const _primary = ZdColors.primary;
const _primaryBg = ZdColors.cardBg;
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _textLight = ZdColors.textSecondary;
const _bg = ZdColors.background;
const _cardBorder = Color(0x1AFF7A2F);
const _green = ZdColors.success;
const _greenBg = Color(0xFFE8F5E9);
const _star = Color(0xFFFFB800);
const _warn = ZdColors.primary;
const _warnBg = Color(0xFFFFF3E0);
const _archivePurple = Color(0xFF7B1FA2);
const _archivePurpleBg = Color(0xFFF5F3FF);

// ============================================================
// 施工工序状态枚举
// ============================================================

enum _PhaseStatus { done, current, blocked, available }

class _Phase {
  final String name;
  final int index;
  final BookedWorker? worker;
  final _PhaseStatus status;
  final bool hasConflict;

  const _Phase({
    required this.name,
    required this.index,
    this.worker,
    required this.status,
    this.hasConflict = false,
  });
}

// ============================================================
// 工序冲突检测引擎
// ============================================================
class _PhaseEngine {
  static const phaseNames = [
    '打拆', '水电', '防水', '泥工', '木工', '美缝', '安装', '清洁',
  ];

  static List<_Phase> build(List<BookedWorker> workers, Set<int> completedPhases) {
    final workerMap = <int, BookedWorker>{};
    for (final w in workers) {
      workerMap[w.phaseIndex] = w;
    }

    int lastDone = -1;
    if (completedPhases.isNotEmpty) {
      lastDone = completedPhases.reduce((a, b) => a > b ? a : b);
    }

    return List.generate(phaseNames.length, (i) {
      final worker = workerMap[i];
      _PhaseStatus status;
      bool hasConflict = false;

      if (completedPhases.contains(i)) {
        status = _PhaseStatus.done;
      } else if (i == lastDone + 1 && worker != null) {
        status = _PhaseStatus.current;
      } else if (worker != null && i > lastDone + 1) {
        status = _PhaseStatus.blocked;
        hasConflict = true;
      } else if (worker != null) {
        status = _PhaseStatus.current;
      } else if (i == lastDone + 1) {
        status = _PhaseStatus.available;
      } else {
        status = _PhaseStatus.blocked;
      }

      return _Phase(
        name: phaseNames[i],
        index: i,
        worker: worker,
        status: status,
        hasConflict: hasConflict,
      );
    });
  }

  static List<_Phase> conflicts(List<_Phase> phases) {
    return phases.where((p) => p.hasConflict).toList();
  }


}

// ============================================================


// ============================================================
// MyHomePage V3 — 装修服务履约中心（新视觉版）
// ============================================================
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final int _currentWorkerIndex = 0;

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    final workers = state.bookedWorkers;
    final activeWorkers = workers.where((w) => !w.isCompleted).toList();
    final completed = state.completedPhases;
    final phases = _PhaseEngine.build(workers, completed);
    final conflicts = _PhaseEngine.conflicts(phases);
    final pendingInspections = state.inspections.where((i) => i.status == InspectionStatus.pending).toList();
    final archives = state.archives;

    return Container(
      color: _bg,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Hero 头部 ──
              _HeroHeader(
                address: '金牛区 XX小区 3栋2单元',
                projectName: '全屋装修',
                workerCount: activeWorkers.length,
                notificationCount: 3,
                onNotificationTap: () => _push(Scaffold(
                  appBar: AppBar(title: const Text('通知消息')),
                  body: const MessagePage(),
                )),
              ),

              // ── 2. 冲突警告条 ──
              if (conflicts.isNotEmpty)
                _ConflictBanner(conflicts: conflicts, onPush: _push, phases: phases),

              // ── 3. 快捷入口 ──
              _QuickActionsRow(onPush: _push),

              // ── 4. 装修进度条 ──
              _ProgressBar(phases: phases),

              // ── 5. 今日提醒 ──
              if (activeWorkers.isNotEmpty)
                _TodayReminderCard(
                  worker: activeWorkers[_currentWorkerIndex.clamp(0, activeWorkers.length - 1)],
                  onPush: _push,
                ),

              // ── 6. 下一步计划 ──
              _NextStepCard(phases: phases, workers: workers),

              // ── 7. 验收面板 ──
              if (pendingInspections.isNotEmpty) ...[
                const SizedBox(height: 4),
                for (final insp in pendingInspections)
                  _InspectionPanel(
                    inspection: insp,
                    onAccept: () => state.acceptInspection(insp.id),
                    onReject: (note) => state.rejectInspection(insp.id, note: note),
                  ),
              ],

              // ── 8. 材料商场 ──
              if (state.materialEstimates.isNotEmpty) ...[
                const SizedBox(height: 4),
                for (final estimate in state.materialEstimates)
                  _MaterialEstimatePanel(
                    estimate: estimate,
                    onToggleItem: (itemId) => state.toggleMaterialItem(estimate.id, itemId),
                    onConfirm: () => state.confirmMaterialOrder(estimate.id),
                  ),
              ],

              // ── 9. 平台验收 Banner ──
              _InspectionBanner(onTap: () {}),

              // ── 10. 我的工人 ──
              const _SectionLabel('我的工人'),
              if (activeWorkers.isNotEmpty)
                ...activeWorkers.map((w) => _WorkerCard(
                  worker: w,
                  onPush: _push,
                  onConfirmPhaseComplete: () => state.confirmPhaseComplete(w.phaseIndex),
                )),

              // ── 11. 装修档案 ──
              const _SectionLabel('装修档案'),
              _ArchiveCard(
                archives: archives,
                totalPhases: 8,
                onTap: () => _push(const RenovationArchivePage()),
              ),

              // ── 12. 四宫格 ──
              _BottomGrid(
                pendingInspections: pendingInspections,
                onPush: _push,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 1. Hero 头部
// ============================================================
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.address,
    required this.projectName,
    required this.workerCount,
    required this.notificationCount,
    required this.onNotificationTap,
  });

  final String address;
  final String projectName;
  final int workerCount;
  final int notificationCount;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('my-home-hero'),
      height: 228,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ZdColors.heroWoodDark,
            ZdColors.heroWoodMid,
            Color(0xFF5B5149),
            Color(0xFF3D4653),
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: _HeroAmbientPainter(),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white12,
                    Colors.black26,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
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
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.notifications_none,
                              color: Colors.white,
                              size: 22,
                            ),
                            if (notificationCount > 0)
                              Positioned(
                                top: 7,
                                right: 7,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF3B30),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$notificationCount',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
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
                Text(
                  address,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      projectName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$workerCount位师傅',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroAmbientPainter extends CustomPainter {
  const _HeroAmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final spots = [
      _AmbientSpot(
        Offset(size.width * 0.18, size.height * 0.24),
        110,
        72,
        const Color(0x26C58C62),
      ),
      _AmbientSpot(
        Offset(size.width * 0.80, size.height * 0.28),
        76,
        52,
        const Color(0x1AFFF0D4),
      ),
      _AmbientSpot(
        Offset(size.width * 0.62, size.height * 0.70),
        120,
        54,
        const Color(0x1C6A7380),
      ),
      _AmbientSpot(
        Offset(size.width * 0.34, size.height * 0.64),
        86,
        44,
        const Color(0x16E8B68A),
      ),
    ];
    for (final spot in spots) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [spot.color, spot.color.withValues(alpha: 0)],
        ).createShader(Rect.fromCenter(center: spot.center, width: spot.rx * 2, height: spot.ry * 2))
        ..blendMode = BlendMode.srcOver;
      canvas.drawOval(
        Rect.fromCenter(center: spot.center, width: spot.rx * 2, height: spot.ry * 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AmbientSpot {
  final Offset center;
  final double rx;
  final double ry;
  final Color color;
  const _AmbientSpot(this.center, this.rx, this.ry, this.color);
}

// ============================================================
// 2. 冲突警告条（保留原有逻辑）
// ============================================================
class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.conflicts, required this.onPush, required this.phases});
  final List<_Phase> conflicts;
  final void Function(Widget) onPush;
  final List<_Phase> phases;


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _warnBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _warn.withValues(alpha: .2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: _warn, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('工序顺序提醒',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _warn)),
                  const SizedBox(height: 6),
                  ...conflicts.map((p) {
                    final prevNames = _PhaseEngine.phaseNames.take(p.index).where((n) {
                      final idx = _PhaseEngine.phaseNames.indexOf(n);
                      return idx > 0;
                    }).join('→');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${p.worker?.name ?? ''}（${p.name}）已预约，${p.name}需在$prevNames完成后进场',
                        style: const TextStyle(fontSize: 12, color: _textMid, height: 1.4),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 3. 快捷入口
// ============================================================
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.onPush});
  final void Function(Widget) onPush;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Container(
        key: const Key('my-home-quick-actions'),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        decoration: BoxDecoration(
          color: ZdColors.surfaceWarm,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0E7DE)),
          boxShadow: ZdShadow.cardSoft,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _QuickItem(
              icon: Icons.house_siding_rounded,
              label: '施工进度',
              bgColor: const Color(0xFFFFF2E8),
              iconColor: ZdColors.primary,
            ),
            _QuickItem(
              icon: Icons.person_rounded,
              label: '我的工人',
              bgColor: const Color(0xFFFFF7EF),
              iconColor: const Color(0xFF9A6337),
            ),
            _QuickItem(
              icon: Icons.notifications_none_rounded,
              label: '待处理',
              bgColor: const Color(0xFFFFF8F1),
              iconColor: ZdColors.primary,
              badge: '2',
            ),
            _QuickItem(
              icon: Icons.receipt_long_rounded,
              label: '材料清单',
              bgColor: const Color(0xFFF8F2EA),
              iconColor: const Color(0xFF8A6B56),
            ),
            _QuickItem(
              icon: Icons.shield_outlined,
              label: '平台保障',
              bgColor: const Color(0xFFF7F4EE),
              iconColor: const Color(0xFF7A6B5A),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickItem extends StatelessWidget {
  const _QuickItem({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    this.badge,
  });
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            if (badge != null)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badge!,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6D6259),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 4. 装修进度条
// ============================================================
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.phases});
  final List<_Phase> phases;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Container(
        key: const Key('my-home-progress-card'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('装修进度'),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < phases.length; i++) ...[
                    if (i > 0) _ProgressLine(done: phases[i - 1].status == _PhaseStatus.done),
                    _ProgressDot(phase: phases[i]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDot extends StatelessWidget {
  const _ProgressDot({required this.phase});
  final _Phase phase;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color textColor;
    Widget content;

    switch (phase.status) {
      case _PhaseStatus.done:
        bg = _green;
        textColor = _green;
        content = const Icon(Icons.check, size: 14, color: Colors.white);
      case _PhaseStatus.current:
        bg = _primary;
        textColor = _primary;
        content = Text('${phase.index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white));
      default:
        bg = const Color(0xFFEEEEEE);
        textColor = const Color(0xFF999999);
        content = Text('${phase.index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFBBBBBB)));
    }

    return SizedBox(
      width: 44,
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: phase.status == _PhaseStatus.current
                  ? [BoxShadow(color: _primary.withValues(alpha: 0.15), blurRadius: 4, spreadRadius: 2)]
                  : null,
            ),
            alignment: Alignment.center,
            child: content,
          ),
          const SizedBox(height: 6),
          Text(
            phase.name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: phase.status == _PhaseStatus.current ? FontWeight.w600 : FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 2,
      color: done ? _green : const Color(0xFFEEEEEE),
      margin: const EdgeInsets.only(bottom: 20),
    );
  }
}

// ============================================================
// 5. 今日提醒
// ============================================================
class _TodayReminderCard extends StatelessWidget {
  const _TodayReminderCard({required this.worker, required this.onPush});
  final BookedWorker worker;
  final void Function(Widget) onPush;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Container(
        key: const Key('my-home-reminder-card'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _warnBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.notifications_active, color: _primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '今日提醒',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '【${worker.name}·${worker.trade}】正在施工中，预计今天完成。\n提醒：请确认楼下邻居已沟通防水测试配合事项。',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A), height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => onPush(WorkerDetailPage(workerName: worker.name, distance: worker.distance)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('查看详情', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primary)),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 14, color: _primary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 6. 下一步计划
// ============================================================
class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.phases, required this.workers});
  final List<_Phase> phases;
  final List<BookedWorker> workers;

  @override
  Widget build(BuildContext context) {
    // 找下一个工序
    final nextPhases = phases.where((p) => p.status == _PhaseStatus.available || p.status == _PhaseStatus.blocked).toList();
    String desc = '按计划推进，等待下一阶段施工';
    if (nextPhases.isNotEmpty) {
      desc = '下一步：${nextPhases.first.name}工序，建议提前联系师傅确认进场时间';
    }

    final currentPhase = phases.cast<_Phase?>().firstWhere(
      (p) => p?.status == _PhaseStatus.current,
      orElse: () => null,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Container(
        key: const Key('my-home-next-step-card'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _greenBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle_outline, color: _green, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '下一步计划',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A), height: 1.5)),
                  if (currentPhase != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {},
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('联系下一位师傅', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primary)),
                          SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 14, color: _primary),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 7. 验收面板（保留原有逻辑）
// ============================================================
class _InspectionPanel extends StatefulWidget {
  const _InspectionPanel({
    required this.inspection,
    required this.onAccept,
    required this.onReject,
  });
  final InspectionRequest inspection;
  final VoidCallback onAccept;
  final void Function(String? note) onReject;

  @override
  State<_InspectionPanel> createState() => _InspectionPanelState();
}

class _InspectionPanelState extends State<_InspectionPanel> {
  bool _showRejectInput = false;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insp = widget.inspection;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF3E0), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorder),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fact_check_outlined, color: _primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('验收通知',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textDark, letterSpacing: -0.2)),
                      const SizedBox(height: 2),
                      Text(
                        '${insp.phaseName}施工已完成，${insp.workerName}发起验收申请',
                        style: const TextStyle(fontSize: 13, color: _textMid),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: _primary),
                SizedBox(width: 6),
                Text('是否需要平台监理上门验收？', style: TextStyle(fontSize: 13, color: _textDark)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        if (_showRejectInput) {
                          final note = _noteController.text.trim();
                          widget.onReject(note.isNotEmpty ? note : null);
                          _showRejectInput = false;
                          _noteController.clear();
                        } else {
                          setState(() => _showRejectInput = true);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _warn,
                        side: const BorderSide(color: _warn),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(_showRejectInput ? '确认返工' : '返工整改',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: widget.onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('验收合格', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
            if (_showRejectInput) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                autofocus: true,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: '请说明不合格项，帮助师傅精准整改…',
                  hintStyle: const TextStyle(fontSize: 13, color: _textLight),
                  filled: true,
                  fillColor: ZdColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showRejectInput = false;
                    _noteController.clear();
                  });
                },
                child: const Text('取消', style: TextStyle(fontSize: 12, color: _textLight)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 8. 材料商场卡片
// ============================================================
class _MaterialEstimatePanel extends StatefulWidget {
  const _MaterialEstimatePanel({
    required this.estimate,
    required this.onToggleItem,
    required this.onConfirm,
  });

  final MaterialEstimate estimate;
  final void Function(String itemId) onToggleItem;
  final VoidCallback onConfirm;

  @override
  State<_MaterialEstimatePanel> createState() => _MaterialEstimatePanelState();
}

class _MaterialEstimatePanelState extends State<_MaterialEstimatePanel> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.estimate;
    final isPending = e.status == EstimateStatus.pending;
    final allItems = [...e.auxiliaryItems, ...e.mainItems];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('材料商场',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark, letterSpacing: -0.2)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _warnBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('待确认',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _primary)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('${e.workerName} · ${e.workerTrade}',
                  style: const TextStyle(fontSize: 12, color: _textLight)),
              const SizedBox(height: 14),
              ...allItems.map((item) => _MaterialItemCard(
                    item: item,
                    checked: e.selectedItemIds.contains(item.id),
                    enabled: isPending,
                    onToggle: () => widget.onToggleItem(item.id),
                  )),
              const Divider(height: 24),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('平台下单材料享质保',
                          style: TextStyle(fontSize: 12, color: _textLight)),
                      const SizedBox(height: 2),
                      Text(
                        '合计 ¥${e.selectedTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700, color: _primary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: isPending && !_confirming
                          ? () {
                              setState(() => _confirming = true);
                              widget.onConfirm();
                              setState(() => _confirming = false);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        disabledBackgroundColor: const Color(0xFFDDDDDD),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: const Text('确认下单',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialItemCard extends StatelessWidget {
  const _MaterialItemCard({
    required this.item,
    required this.checked,
    required this.enabled,
    required this.onToggle,
  });

  final MaterialItem item;
  final bool checked;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: enabled ? onToggle : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFF0F0F0)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // 缩略图
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (item.imageUrl?.isNotEmpty ?? false)
                      ? Image.network(item.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholderIcon())
                      : _placeholderIcon(),
                ),
              ),
              const SizedBox(width: 12),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((item.brand?.isNotEmpty ?? false))
                      Text(item.brand!, style: const TextStyle(fontSize: 11, color: _textLight)),
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: checked ? _textDark : _textLight,
                      ),
                    ),
                    if ((item.spec?.isNotEmpty ?? false))
                      Text('规格：${item.spec}', style: const TextStyle(fontSize: 11, color: _textLight)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '单价：¥${item.unitPrice.toStringAsFixed(0)}/${item.unit}',
                          style: const TextStyle(fontSize: 12, color: _textMid),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '数量：${item.quantity}${item.unit}',
                          style: const TextStyle(fontSize: 12, color: _textMid),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 总价
              Text(
                '¥${item.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderIcon() {
    return const Icon(Icons.inventory_2_outlined, color: Color(0xFFCCCCCC), size: 28);
  }
}

// ============================================================
// 9. 平台验收 Banner
// ============================================================
class _InspectionBanner extends StatelessWidget {
  const _InspectionBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, Color(0xFFFF5A1F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -15,
                right: 40,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '平台监理验收服务',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '专业监理上门验收，保障施工质量',
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '立即预约',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 10. 我的工人卡片
// ============================================================
class _WorkerCard extends StatelessWidget {
  const _WorkerCard({
    required this.worker,
    required this.onPush,
    required this.onConfirmPhaseComplete,
  });
  final BookedWorker worker;
  final void Function(Widget) onPush;
  final VoidCallback onConfirmPhaseComplete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _primaryBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Text(worker.avatarEmoji, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(worker.name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
                          const SizedBox(width: 6),
                          Text(worker.trade,
                              style: const TextStyle(fontSize: 13, color: _textMid)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _greenBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('施工中',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _green)),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.star, size: 12, color: _star),
                          Text(' ${worker.rating}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark)),
                          Text('  ${worker.completedOrders}单 · ${worker.years}年',
                              style: const TextStyle(fontSize: 12, color: _textLight)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (worker.skills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: worker.skills
                    .map((s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(s, style: const TextStyle(fontSize: 11, color: _textMid)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _WorkerBtn(
                    icon: Icons.chat_outlined,
                    label: '一键联系',
                    onTap: () => onPush(WorkerChatPage(workerName: worker.name)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _WorkerBtn(
                    icon: Icons.person_outline,
                    label: '查看详情',
                    onTap: () => onPush(WorkerDetailPage(workerName: worker.name, distance: worker.distance)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _WorkerBtn(
                    icon: Icons.article_outlined,
                    label: '查看报价',
                    primary: true,
                    onTap: () => onPush(WorkerQuotePage(
                      workerName: worker.name,
                      trade: tradeToPriceData(worker.trade),
                    )),
                  ),
                ),
              ],
            ),
            if (!worker.isCompleted) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: onConfirmPhaseComplete,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text('${worker.phaseName}已完成，通知下一工序'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkerBtn extends StatelessWidget {
  const _WorkerBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: primary ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: primary ? null : Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: primary ? Colors.white : _textMid),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  color: primary ? Colors.white : _textMid,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 11. 装修档案卡片
// ============================================================
class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({
    required this.archives,
    required this.totalPhases,
    required this.onTap,
  });
  final List<RenovationArchive> archives;
  final int totalPhases;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '已记录 ${archives.length}/$totalPhases 个验收项',
                  style: const TextStyle(fontSize: 13, color: _textMid),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onTap,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('查看档案',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _archivePurple)),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 14, color: _archivePurple),
                    ],
                  ),
                ),
              ],
            ),
            if (archives.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: archives.take(4).map((a) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _archivePurpleBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 12, color: _archivePurple),
                        const SizedBox(width: 4),
                        Text(
                          a.phaseName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _archivePurple,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            if (archives.length < totalPhases)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '下次节点：${_PhaseEngine.phaseNames[archives.length]}验收',
                  style: const TextStyle(fontSize: 11, color: _textLight),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 12. 四宫格
// ============================================================
class _BottomGrid extends StatelessWidget {
  const _BottomGrid({
    required this.pendingInspections,
    required this.onPush,
  });
  final List<InspectionRequest> pendingInspections;
  final void Function(Widget) onPush;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _GridItem(
                  icon: Icons.fact_check_outlined,
                  iconBg: _warnBg,
                  iconColor: _primary,
                  label: '平台验收',
                  desc: pendingInspections.isNotEmpty
                      ? '${pendingInspections.first.workerName}发起验收申请'
                      : '暂无待验收项',
                  status: pendingInspections.isNotEmpty ? '待处理' : null,
                  statusColor: _primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GridItem(
                  icon: Icons.account_balance_wallet,
                  iconBg: const Color(0xFFE3F2FD),
                  iconColor: const Color(0xFF1976D2),
                  label: '资金托管',
                  desc: '装修资金平台托管，完工验收后付款',
                  status: '已托管',
                  statusColor: const Color(0xFF1976D2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _GridItem(
                  icon: Icons.verified_user_outlined,
                  iconBg: _greenBg,
                  iconColor: _green,
                  label: '售后保障',
                  desc: '完工后享 2 年质保，维修响应及时',
                  status: '查看细则',
                  statusColor: _green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GridItem(
                  icon: Icons.add,
                  iconBg: const Color(0xFFF5F5F5),
                  iconColor: const Color(0xFF999999),
                  label: '更多服务',
                  desc: '',
                  noStatus: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  const _GridItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.desc,
    this.status,
    this.statusColor,
    this.noStatus = false,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String desc;
  final String? status;
  final Color? statusColor;
  final bool noStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textDark)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(desc, style: const TextStyle(fontSize: 11, color: _textLight), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (status != null && !noStatus) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status!.contains('待'))
                  const Icon(Icons.error_outline, size: 14, color: _primary)
                else if (status!.contains('托管'))
                  const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF1976D2))
                else
                  const Icon(Icons.check_circle, size: 14, color: _green),
                const SizedBox(width: 4),
                Text(
                  status!,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// 通用 Section 标签
// ============================================================
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _textDark,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
