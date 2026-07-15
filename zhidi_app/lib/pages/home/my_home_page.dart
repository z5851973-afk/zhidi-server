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
    final archives = state.archives.toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final materialEstimates = state.materialEstimates.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
            const SizedBox(height: 14),
            _MaterialSection(estimates: materialEstimates),
            const SizedBox(height: 14),
            _ArchiveSection(archives: archives),
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

  InspectionRequest? _latestInspection(List<InspectionRequest> inspections) {
    final matched = inspections
        .where((item) => item.workerId == worker.id)
        .toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return matched.isEmpty ? null : matched.first;
  }

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    final isCompleted =
        state.completedPhases.contains(worker.phaseIndex) || worker.isCompleted;
    final inspection = _latestInspection(state.inspections);
    final statusLabel = isCompleted
        ? '已完成'
        : inspection?.status == InspectionStatus.pending
        ? '待验收'
        : inspection?.status == InspectionStatus.rejected
        ? '验收未通过'
        : '进行中';

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
              _StatusChip(label: statusLabel),
            ],
          ),
          if (!isCompleted) ...[
            const SizedBox(height: 12),
            if (inspection?.status == InspectionStatus.pending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => state.rejectInspection(
                        inspection!.id,
                        note: '业主要求整改',
                      ),
                      child: const Text('驳回'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => state.approveInspection(inspection!.id),
                      style: FilledButton.styleFrom(
                        backgroundColor: MyHomePage._primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('通过验收'),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => state.requestInspection(worker.id),
                  style: FilledButton.styleFrom(
                    backgroundColor: MyHomePage._primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    inspection?.status == InspectionStatus.rejected
                        ? '重新申请验收'
                        : '申请验收',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ArchiveSection extends StatelessWidget {
  const _ArchiveSection({required this.archives});

  final List<RenovationArchive> archives;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '装修档案',
      child: archives.isEmpty
          ? const _EmptyHint(text: '验收通过后，阶段记录会自动归档。')
          : Column(
              children: archives
                  .take(3)
                  .map((archive) => _ArchiveTile(archive: archive))
                  .toList(),
            ),
    );
  }
}

class _MaterialSection extends StatelessWidget {
  const _MaterialSection({required this.estimates});

  final List<MaterialEstimate> estimates;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '材料估算',
      child: estimates.isEmpty
          ? const _EmptyHint(text: '师傅提交材料清单后，会在这里确认采购。')
          : Column(
              children: estimates
                  .take(3)
                  .map((estimate) => _MaterialEstimateCard(estimate: estimate))
                  .toList(),
            ),
    );
  }
}

class _MaterialEstimateCard extends StatelessWidget {
  const _MaterialEstimateCard({required this.estimate});

  final MaterialEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    final ordered = estimate.status == MaterialEstimateStatus.ordered;
    final firstItem = estimate.items.isEmpty ? null : estimate.items.first;

    return Container(
      key: Key('my-home-material-${estimate.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3EA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: MyHomePage._primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${estimate.phaseName}材料清单',
                      style: const TextStyle(
                        color: MyHomePage._textDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${estimate.workerName} · 预计 ¥${estimate.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: MyHomePage._textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(label: ordered ? '已确认采购' : '待确认'),
            ],
          ),
          if (firstItem != null) ...[
            const SizedBox(height: 8),
            Text(
              '${firstItem.name} ${firstItem.quantity}${firstItem.unit}',
              style: const TextStyle(
                color: MyHomePage._textMuted,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (!ordered)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => state.confirmMaterialEstimate(estimate.id),
                style: FilledButton.styleFrom(
                  backgroundColor: MyHomePage._primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('确认采购'),
              ),
            )
          else
            const Text(
              '已确认采购',
              style: TextStyle(
                color: Color(0xFF1F9D55),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({required this.archive});

  final RenovationArchive archive;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('my-home-archive-${archive.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F6EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Color(0xFF1F9D55),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${archive.phaseName}阶段已归档',
                  style: const TextStyle(
                    color: MyHomePage._textDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${archive.workerName} · ${archive.status}',
                  style: const TextStyle(
                    color: MyHomePage._textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
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
    final pending = label == '待验收';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFFE7F6EE)
            : pending
            ? const Color(0xFFEAF2FF)
            : const Color(0xFFFFF3EA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: done
              ? const Color(0xFF1F9D55)
              : pending
              ? const Color(0xFF2563EB)
              : MyHomePage._primary,
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
