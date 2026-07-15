import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  static const _primary = Color(0xFFFF7A2F);
  static const _background = Color(0xFFF7F8FA);
  static const _textDark = Color(0xFF1F2933);
  static const _textMuted = Color(0xFF697386);

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    final project = state.selectedProject;
    final workers = state.bookedWorkers.toList()
      ..sort((a, b) => a.phaseIndex.compareTo(b.phaseIndex));
    final completedPhases = state.completedPhases;

    return ColoredBox(
      color: _background,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _ProjectHeader(
              projectName: project?.name ?? '我的家',
              address: project?.address ?? state.profile.address ?? '暂无项目地址',
              workerCount: workers.length,
              completedCount: completedPhases.length,
            ),
            const SizedBox(height: 14),
            _ProgressCard(workers: workers, completedPhases: completedPhases),
            const SizedBox(height: 14),
            _WorkerSection(workers: workers),
          ],
        ),
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({
    required this.projectName,
    required this.address,
    required this.workerCount,
    required this.completedCount,
  });

  final String projectName;
  final String address;
  final int workerCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('my-home-hero'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '我的家',
            style: TextStyle(
              color: MyHomePage._primary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            projectName,
            style: const TextStyle(
              color: MyHomePage._textDark,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            address,
            style: const TextStyle(color: MyHomePage._textMuted, height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(label: '施工师傅', value: '$workerCount 位'),
              _MetricPill(label: '已完成阶段', value: '$completedCount 个'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3EA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: MyHomePage._primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.workers, required this.completedPhases});

  final List<BookedWorker> workers;
  final Set<int> completedPhases;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      key: const Key('my-home-progress-card'),
      title: '施工进度',
      child: workers.isEmpty
          ? const _EmptyHint(text: '暂无施工师傅，先从首页选择可信师傅。')
          : Column(
              children: workers
                  .map(
                    (worker) => _PhaseRow(
                      worker: worker,
                      isCompleted:
                          completedPhases.contains(worker.phaseIndex) ||
                          worker.isCompleted,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({required this.worker, required this.isCompleted});

  final BookedWorker worker;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isCompleted
                  ? const Color(0xFFE7F6EE)
                  : const Color(0xFFFFF3EA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCompleted ? Icons.check_rounded : Icons.construction_rounded,
              color: isCompleted
                  ? const Color(0xFF1F9D55)
                  : MyHomePage._primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worker.phaseName,
                  style: const TextStyle(
                    color: MyHomePage._textDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  worker.name,
                  style: const TextStyle(
                    color: MyHomePage._textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(label: isCompleted ? '已完成' : '进行中'),
        ],
      ),
    );
  }
}

class _WorkerSection extends StatelessWidget {
  const _WorkerSection({required this.workers});

  final List<BookedWorker> workers;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '施工师傅',
      child: workers.isEmpty
          ? const _EmptyHint(text: '还没有预约师傅。')
          : Column(
              children: workers
                  .map((worker) => _WorkerCard(worker: worker))
                  .toList(),
            ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  const _WorkerCard({required this.worker});

  final BookedWorker worker;

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    final isCompleted =
        state.completedPhases.contains(worker.phaseIndex) || worker.isCompleted;

    return Container(
      key: Key('my-home-worker-${worker.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(worker.avatarEmoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.name,
                      style: const TextStyle(
                        color: MyHomePage._textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${worker.phaseName} · ${worker.trade}',
                      style: const TextStyle(
                        color: MyHomePage._textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(label: isCompleted ? '已完成' : '进行中'),
            ],
          ),
          if (!isCompleted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => state.confirmPhaseComplete(worker.phaseIndex),
                style: FilledButton.styleFrom(
                  backgroundColor: MyHomePage._primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('确认完成'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final done = label == '已完成';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFE7F6EE) : const Color(0xFFFFF3EA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: done ? const Color(0xFF1F9D55) : MyHomePage._primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: MyHomePage._textDark,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: MyHomePage._textMuted, height: 1.5),
    );
  }
}
