import 'package:flutter/material.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';

import '../../design/tokens.dart';
import '../../data/price_standards.dart';
import '../../models/renovation.dart' show Trade;
import '../price/worker_quote_page.dart';
import '../renovation/construction_standards_page.dart';
import '../renovation/trade_select_page.dart';
import '../renovation/worker_detail_page.dart';
import 'renovation_archive_page.dart';

const _primary = ZdColors.primary;
const _bg = ZdColors.background;
const _card = ZdColors.surfaceWarm;
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _textLight = Color(0xFF9B8F86);
const _line = Color(0xFFF0E4D8);
const _green = ZdColors.success;
const _greenBg = Color(0xFFEAF7EF);
const _orangeSoft = Color(0xFFFFF1E7);
const _gold = Color(0xFFC8871A);

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) => const _MyHomeManagementView();
}

class _MyHomeManagementView extends StatelessWidget {
  const _MyHomeManagementView();

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _showHint(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    final workers = _uniqueServiceWorkers(state.bookedWorkers)
      ..sort((a, b) => a.phaseIndex.compareTo(b.phaseIndex));
    final currentWorker = _selectCurrentWorker(workers);
    final serviceListWorkers = currentWorker == null
        ? workers
        : workers
              .where(
                (worker) => _serviceKey(worker) != _serviceKey(currentWorker),
              )
              .toList();
    final cost = _CostSummary.fromState(state, workers);
    final showProgress = workers.length > 1 || _looksLikeWholeHome(state);

    return ColoredBox(
      color: _bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            const _PageHeader(),
            const SizedBox(height: 16),
            _CurrentServiceCard(
              key: const Key('my-home-current-service-card'),
              worker: currentWorker,
              onFindWorker: () => _push(context, const TradeSelectPage()),
              onDetail: currentWorker == null
                  ? null
                  : () => _push(
                      context,
                      _TradeServiceDetailPage(worker: currentWorker),
                    ),
            ),
            const SizedBox(height: 12),
            _ServiceListCard(
              key: const Key('my-home-service-list'),
              workers: serviceListWorkers,
              hasCurrentService: currentWorker != null,
              onFindWorker: () => _push(context, const TradeSelectPage()),
              onOpenWorker: (worker) =>
                  _push(context, _TradeServiceDetailPage(worker: worker)),
            ),
            if (showProgress) ...[
              const SizedBox(height: 12),
              _ProgressCard(workers: workers),
            ],
            const SizedBox(height: 12),
            _CostCard(
              key: const Key('my-home-cost-card'),
              summary: cost,
              onDetail: currentWorker == null
                  ? () => _showHint(context, '先预约师傅后可生成费用明细')
                  : () => _push(
                      context,
                      WorkerQuotePage(
                        workerName: currentWorker.name,
                        trade: tradeToPriceData(currentWorker.trade),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            _DocumentsCard(
              key: const Key('my-home-documents-card'),
              onQuote: currentWorker == null
                  ? () => _showHint(context, '暂无报价清单，先开始找师傅')
                  : () => _push(
                      context,
                      WorkerQuotePage(
                        workerName: currentWorker.name,
                        trade: tradeToPriceData(currentWorker.trade),
                      ),
                    ),
              onStandard: () =>
                  _push(context, const ConstructionStandardsPage()),
              onInspection: () => _push(context, const RenovationArchivePage()),
              onPayment: () => _showHint(context, '付款记录正在接入平台托管流程'),
            ),
          ],
        ),
      ),
    );
  }

  static bool _looksLikeWholeHome(OwnerAppState state) {
    final type = state.profile.decorationType;
    return type?.contains('整') == true || type?.contains('全屋') == true;
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '我的家',
          style: TextStyle(
            fontSize: 30,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: _textDark,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '管理我的装修服务，让每一步装修都有记录、有保障。',
          style: TextStyle(fontSize: 14, height: 1.45, color: _textMid),
        ),
      ],
    );
  }
}

class _CurrentServiceCard extends StatelessWidget {
  const _CurrentServiceCard({
    super.key,
    required this.worker,
    required this.onFindWorker,
    required this.onDetail,
  });

  final BookedWorker? worker;
  final VoidCallback onFindWorker;
  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context) {
    final current = worker;
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: current == null
          ? _EmptyCurrentService(onFindWorker: onFindWorker)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _SectionTitle(title: '正在服务'),
                    const Spacer(),
                    _StatusPill(
                      label: _serviceStatus(current),
                      emphasized: true,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WorkerAvatar(emoji: current.avatarEmoji, size: 68),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current.phaseName,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _displayWorkerName(current),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 9),
                          const _CertificationRow(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _orangeSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_available_rounded,
                        color: _primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '预约时间',
                        style: TextStyle(fontSize: 13, color: _textMid),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          _formatVisitTime(current.bookedAt),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: onDetail,
                    child: const Text(
                      '查看详情',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyCurrentService extends StatelessWidget {
  const _EmptyCurrentService({required this.onFindWorker});

  final VoidCallback onFindWorker;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: '正在服务'),
        const SizedBox(height: 18),
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _orangeSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.home_repair_service_rounded,
                color: _primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '还没有装修服务',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '不知道装修第一步？\n知底帮你匹配合适师傅',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: _textMid,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: onFindWorker,
            child: const Text(
              '开始找师傅',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _ServiceListCard extends StatelessWidget {
  const _ServiceListCard({
    super.key,
    required this.workers,
    required this.hasCurrentService,
    required this.onFindWorker,
    required this.onOpenWorker,
  });

  final List<BookedWorker> workers;
  final bool hasCurrentService;
  final VoidCallback onFindWorker;
  final ValueChanged<BookedWorker> onOpenWorker;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionTitle(title: '我的服务'),
              const Spacer(),
              TextButton.icon(
                onPressed: onFindWorker,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('新增'),
                style: TextButton.styleFrom(foregroundColor: _primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (workers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                hasCurrentService
                    ? '当前服务已在上方展示，新增其它工种后会在这里管理。'
                    : '暂无预约工种，首页找到师傅后会自动同步到这里。',
                style: const TextStyle(fontSize: 13, color: _textMid),
              ),
            )
          else
            ...workers.map(
              (worker) => _ServiceRow(
                key: Key('my-home-service-row-${_serviceKey(worker)}'),
                worker: worker,
                onTap: () => onOpenWorker(worker),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({super.key, required this.worker, required this.onTap});

  final BookedWorker worker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPendingMatch = worker.name.trim().isEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _orangeSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                worker.avatarEmoji.isEmpty ? '🏠' : worker.avatarEmoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker.phaseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPendingMatch ? '待匹配' : _displayWorkerName(worker),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _textMid),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusPill(label: isPendingMatch ? '待匹配' : _serviceStatus(worker)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: _textLight),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.workers});

  final List<BookedWorker> workers;

  @override
  Widget build(BuildContext context) {
    final progressWorkers = workers.take(4).toList();
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '装修进度'),
          const SizedBox(height: 16),
          Row(
            children: [
              for (int i = 0; i < progressWorkers.length; i++) ...[
                Expanded(
                  child: _ProgressStep(
                    label: _progressLabel(progressWorkers[i]),
                    status: _serviceStatus(progressWorkers[i]),
                  ),
                ),
                if (i != progressWorkers.length - 1)
                  Container(width: 14, height: 2, color: _line),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final done = status == '已完成';
    final current = status == '施工中';
    final color = done || current ? _primary : _textLight;
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: done
                ? _primary
                : current
                ? _orangeSoft
                : const Color(0xFFF4EFEA),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: done ? _primary : _line),
          ),
          child: Icon(
            done ? Icons.check_rounded : Icons.circle_rounded,
            size: done ? 18 : 9,
            color: done ? Colors.white : color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 3),
        Text(status, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}

class _CostCard extends StatelessWidget {
  const _CostCard({super.key, required this.summary, required this.onDetail});

  final _CostSummary summary;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionTitle(title: '装修费用'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _orangeSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '固定工价 · 报价透明',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CostMetric(
                  label: '已确认费用',
                  value: _money(summary.confirmed),
                  prominent: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CostMetric(label: '人工费用', value: _money(summary.labor)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CostMetric(
                  label: '辅材费用',
                  value: _money(summary.material),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: onDetail,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: Color(0xFFFFC7A3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '查看费用详情',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({
    super.key,
    required this.onQuote,
    required this.onStandard,
    required this.onInspection,
    required this.onPayment,
  });

  final VoidCallback onQuote;
  final VoidCallback onStandard;
  final VoidCallback onInspection;
  final VoidCallback onPayment;

  @override
  Widget build(BuildContext context) {
    final items = [
      _DocEntry(Icons.receipt_long_rounded, '报价清单', onQuote),
      _DocEntry(Icons.verified_user_outlined, '施工标准', onStandard),
      _DocEntry(Icons.fact_check_outlined, '验收记录', onInspection),
      _DocEntry(Icons.account_balance_wallet_outlined, '付款记录', onPayment),
    ];
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '装修资料'),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.65,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBF7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _orangeSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, size: 18, color: _primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TradeServiceDetailPage extends StatelessWidget {
  const _TradeServiceDetailPage({required this.worker});

  final BookedWorker worker;

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    final reports =
        state.dailyReports
            .where((report) => report.phaseIndex == worker.phaseIndex)
            .toList()
          ..sort(
            (a, b) => (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)),
          );
    final archives = state.archives
        .where((archive) => archive.phaseIndex == worker.phaseIndex)
        .toList();
    final inspections = state.inspections
        .where((inspection) => inspection.phaseIndex == worker.phaseIndex)
        .toList();
    final materialTotal = state.materialEstimates
        .where((estimate) => estimate.phaseIndex == worker.phaseIndex)
        .fold<double>(0, (sum, estimate) => sum + estimate.selectedTotal);
    final laborTotal = _laborPriceFor(worker);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text('${_progressLabel(worker)}服务详情'),
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _textDark,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _ServiceWorkerDetailCard(worker: worker),
            const SizedBox(height: 12),
            _ServicePriceCard(
              laborTotal: laborTotal,
              materialTotal: materialTotal,
              worker: worker,
            ),
            const SizedBox(height: 12),
            _ServiceLogCard(
              worker: worker,
              reports: reports,
              archives: archives,
              inspections: inspections,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceWorkerDetailCard extends StatelessWidget {
  const _ServiceWorkerDetailCard({required this.worker});

  final BookedWorker worker;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionTitle(title: '师傅详情'),
              const Spacer(),
              _StatusPill(label: _serviceStatus(worker), emphasized: true),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _WorkerAvatar(emoji: worker.avatarEmoji, size: 62),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayWorkerName(worker),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_progressLabel(worker)} · ${worker.years}年经验 · ${worker.completedOrders}单',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _textMid),
                    ),
                    const SizedBox(height: 8),
                    const _CertificationRow(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: worker.skills
                .take(4)
                .map((skill) => _SoftChip(skill))
                .toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkerDetailPage(
                    workerName: _displayWorkerName(worker),
                    trade: _tradeFromWorker(worker),
                    distance: worker.distance,
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: Color(0xFFFFC7A3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '查看师傅主页',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicePriceCard extends StatelessWidget {
  const _ServicePriceCard({
    required this.laborTotal,
    required this.materialTotal,
    required this.worker,
  });

  final double laborTotal;
  final double materialTotal;
  final BookedWorker worker;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionTitle(title: '价格明细'),
              const Spacer(),
              Text(
                _money(laborTotal + materialTotal),
                style: const TextStyle(
                  color: _primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _PriceExpansionTile(
            title: '人工价格',
            amount: laborTotal,
            lines: ['${_progressLabel(worker)}标准人工费', '按知底固定工价计算，施工前确认，不临时加价'],
          ),
          _PriceExpansionTile(
            title: '辅料价格',
            amount: materialTotal,
            lines: materialTotal > 0
                ? const ['辅材清单来自师傅提交，业主确认后下单', '平台保留明细，便于后续验收追溯']
                : const ['暂无已确认辅材清单', '后续师傅提交后会在这里展开明细'],
          ),
        ],
      ),
    );
  }
}

class _PriceExpansionTile extends StatelessWidget {
  const _PriceExpansionTile({
    required this.title,
    required this.amount,
    required this.lines,
  });

  final String title;
  final double amount;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 10),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _textDark,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _money(amount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _primary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded, color: _textLight),
            ],
          ),
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: _primary)),
                    Expanded(
                      child: Text(
                        line,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: _textMid,
                        ),
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

class _ServiceLogCard extends StatelessWidget {
  const _ServiceLogCard({
    required this.worker,
    required this.reports,
    required this.archives,
    required this.inspections,
  });

  final BookedWorker worker;
  final List<DailyReport> reports;
  final List<RenovationArchive> archives;
  final List<InspectionRequest> inspections;

  @override
  Widget build(BuildContext context) {
    final entryPhotos = _entryPhotos();
    final dailyPhotos = reports.expand((report) => report.imagePaths).toList();
    final inspectionPhotos = archives
        .expand((archive) => archive.photoUrls)
        .toList();
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '施工日志'),
          const SizedBox(height: 14),
          _PhotoLogSection(title: '进场拍照', photos: entryPhotos),
          _PhotoLogSection(title: '每日施工照片', photos: dailyPhotos),
          _PhotoLogSection(title: '节点验收照片', photos: inspectionPhotos),
          const SizedBox(height: 4),
          _StandardInfoBlock(
            title: '施工工艺',
            lines: _craftStandards(worker, reports),
          ),
          const SizedBox(height: 10),
          _StandardInfoBlock(
            title: '验收标准',
            lines: _inspectionStandards(worker, inspections, archives),
          ),
        ],
      ),
    );
  }

  List<String> _entryPhotos() {
    if (reports.isNotEmpty && reports.first.imagePaths.isNotEmpty) {
      return reports.first.imagePaths.take(2).toList();
    }
    return ['https://picsum.photos/seed/${worker.id}-entry/600/400'];
  }
}

class _PhotoLogSection extends StatelessWidget {
  const _PhotoLogSection({required this.title, required this.photos});

  final String title;
  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    final displayPhotos = photos.isEmpty
        ? ['https://picsum.photos/seed/${title.hashCode}/600/400']
        : photos.take(4).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: displayPhotos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) => ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  displayPhotos[index],
                  width: 96,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 96,
                    height: 72,
                    color: _orangeSoft,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_outlined, color: _primary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StandardInfoBlock extends StatelessWidget {
  const _StandardInfoBlock({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '• $line',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: _textMid,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
        boxShadow: ZdShadow.cardSoft,
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: _textDark,
      ),
    );
  }
}

class _CertificationRow extends StatelessWidget {
  const _CertificationRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_rounded, size: 16, color: _primary),
        SizedBox(width: 5),
        Flexible(
          child: Text(
            '平台认证施工师傅',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _gold,
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkerAvatar extends StatelessWidget {
  const _WorkerAvatar({required this.emoji, required this.size});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1E7), Color(0xFFFFC8A6)],
        ),
        borderRadius: BorderRadius.circular(size * .36),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AFF6A00),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        emoji.isEmpty ? '👷' : emoji,
        style: TextStyle(fontSize: size * .48),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final done = label.contains('完成');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: done
            ? _greenBg
            : emphasized
            ? _orangeSoft
            : const Color(0xFFFFF8F1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: done ? _green : _primary,
        ),
      ),
    );
  }
}

class _CostMetric extends StatelessWidget {
  const _CostMetric({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: prominent ? _orangeSoft : const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _textMid)),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: prominent ? 18 : 15,
                fontWeight: FontWeight.w900,
                color: prominent ? _primary : _textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _orangeSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _primary,
        ),
      ),
    );
  }
}

class _DocEntry {
  const _DocEntry(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _CostSummary {
  const _CostSummary({
    required this.confirmed,
    required this.labor,
    required this.material,
  });

  final double confirmed;
  final double labor;
  final double material;

  static _CostSummary fromState(
    OwnerAppState state,
    List<BookedWorker> workers,
  ) {
    final quoteTotal = state.savedQuotes.fold<double>(
      0.0,
      (sum, quote) => sum + quote.grandTotal,
    );
    final fallbackLabor = workers.isEmpty ? 0.0 : workers.length * 1800.0;
    final labor = quoteTotal > 0 ? quoteTotal : fallbackLabor;
    final material = state.materialEstimates.fold<double>(
      0.0,
      (sum, estimate) => sum + estimate.selectedTotal,
    );
    return _CostSummary(
      confirmed: labor + material,
      labor: labor,
      material: material,
    );
  }
}

String _serviceStatus(BookedWorker worker) {
  final raw = worker.status;
  if (raw.contains('完成')) return '已完成';
  if (raw.contains('报价')) return '等待报价';
  if (raw.contains('施工')) return '施工中';
  if (raw.contains('测量') || raw.contains('上门') || raw.contains('接单')) {
    return '等待上门测量';
  }
  return raw.isEmpty ? '等待上门测量' : raw;
}

String _progressLabel(BookedWorker worker) {
  final label = worker.phaseName.trim().isNotEmpty
      ? worker.phaseName.trim()
      : worker.trade.trim();
  if (label.contains('泥瓦')) return '泥瓦';
  if (label.contains('泥工')) return '泥工';
  if (label.contains('防水')) return '防水';
  if (label.contains('水电')) return '水电';
  if (label.contains('拆')) return '拆除';
  if (label.contains('木')) return '木工';
  if (label.contains('油漆') || label.contains('涂')) return '油漆';
  if (label.contains('安装')) return '安装';
  return label;
}

String _displayWorkerName(BookedWorker worker) {
  return worker.name.trim();
}

Trade? _tradeFromWorker(BookedWorker worker) {
  final text = '${worker.trade} ${worker.phaseName}';
  if (text.contains('拆')) return Trade.demolition;
  if (text.contains('水电')) return Trade.plumbing;
  if (text.contains('泥') || text.contains('瓦') || text.contains('贴砖')) {
    return Trade.masonry;
  }
  if (text.contains('防水')) return Trade.waterproof;
  if (text.contains('木')) return Trade.carpentry;
  if (text.contains('油漆') || text.contains('涂')) return Trade.painting;
  if (text.contains('安装')) return Trade.installation;
  if (text.contains('清洁') || text.contains('保洁')) return Trade.cleaning;
  return null;
}

List<BookedWorker> _uniqueServiceWorkers(List<BookedWorker> workers) {
  final byService = <String, BookedWorker>{};
  for (final worker in workers) {
    final key = _serviceKey(worker);
    final existing = byService[key];
    if (existing == null || _preferWorker(worker, existing)) {
      byService[key] = worker;
    }
  }
  return byService.values.toList();
}

String _serviceKey(BookedWorker worker) {
  if (worker.phaseIndex >= 0) return 'phase-${worker.phaseIndex}';
  final trade = _tradeFromWorker(worker);
  if (trade != null) return 'trade-${trade.name}';
  final normalized = '${worker.phaseName}-${worker.trade}'.trim();
  return normalized.isEmpty ? worker.id : normalized;
}

bool _preferWorker(BookedWorker candidate, BookedWorker current) {
  if (!candidate.isCompleted && current.isCompleted) return true;
  if (candidate.isCompleted && !current.isCompleted) return false;
  final candidateTime = candidate.bookedAt;
  final currentTime = current.bookedAt;
  if (candidateTime != null && currentTime != null) {
    return candidateTime.isAfter(currentTime);
  }
  if (candidateTime != null) return true;
  return false;
}

BookedWorker? _selectCurrentWorker(List<BookedWorker> workers) {
  final active = workers.where((worker) => !worker.isCompleted).toList();
  if (active.isEmpty) return workers.isEmpty ? null : workers.last;

  BookedWorker? best;
  for (final worker in active) {
    if (best == null ||
        _currentServiceScore(worker) > _currentServiceScore(best)) {
      best = worker;
    }
  }
  return best;
}

int _currentServiceScore(BookedWorker worker) {
  final status = worker.status;
  var score = 0;
  if (status.contains('施工')) {
    score = 40000;
  } else if (status.contains('报价')) {
    score = 30000;
  } else if (status.contains('上门') || status.contains('测量')) {
    score = 20000;
  } else if (status.contains('确认') || status.contains('接单')) {
    score = 10000;
  }
  score += (worker.bookedAt?.millisecondsSinceEpoch ?? 0) ~/ 1000000000;
  return score;
}

double _laborPriceFor(BookedWorker worker) {
  final base = switch (_tradeFromWorker(worker)) {
    Trade.demolition => 1600.0,
    Trade.plumbing => 2600.0,
    Trade.waterproof => 1800.0,
    Trade.masonry => 3000.0,
    Trade.carpentry => 3200.0,
    Trade.painting => 2200.0,
    Trade.installation => 1400.0,
    Trade.cleaning => 800.0,
    null => 1800.0,
  };
  return base + worker.years * 60;
}

List<String> _craftStandards(BookedWorker worker, List<DailyReport> reports) {
  final label = _progressLabel(worker);
  final latestNote = reports.isNotEmpty ? reports.last.note : '';
  final base = switch (_tradeFromWorker(worker)) {
    Trade.demolition => ['现场保护后拆除，建筑垃圾分区堆放', '拆改完成后清扫地面并保留影像记录'],
    Trade.plumbing => ['水电横平竖直，强弱电分槽布线', '管线隐蔽前完成照片留档'],
    Trade.waterproof => ['基层清理后涂刷防水，阴阳角加强处理', '闭水试验前后拍照留档'],
    Trade.masonry => ['墙地砖铺贴前先排版，控制空鼓和平整度', '阴阳角、坡度、缝隙按标准验收'],
    Trade.carpentry => ['基层找平后安装，板材封边和收口留档', '吊顶龙骨间距按标准施工'],
    Trade.painting => ['基层处理、腻子找平、底漆面漆分步施工', '每道工序干透后再进入下一步'],
    Trade.installation => ['成品安装前复核尺寸和开孔位置', '安装后进行牢固度和功能检查'],
    Trade.cleaning => ['开荒清洁按空间分区推进', '玻璃、五金、地面分别验收'],
    null => ['$label施工过程按平台标准记录', '关键节点拍照留档'],
  };
  return latestNote.isEmpty ? base : [latestNote, ...base];
}

List<String> _inspectionStandards(
  BookedWorker worker,
  List<InspectionRequest> inspections,
  List<RenovationArchive> archives,
) {
  final archiveNote = archives.isNotEmpty ? archives.last.inspectionNote : null;
  final inspectionNote = inspections.isNotEmpty
      ? inspections.last.inspectorNote
      : null;
  final notes = [archiveNote, inspectionNote]
      .where((note) => note != null && note.trim().isNotEmpty)
      .cast<String>()
      .toList();
  if (notes.isNotEmpty) return notes;
  return switch (_tradeFromWorker(worker)) {
    Trade.demolition => ['拆除范围与需求一致，无误拆漏拆', '垃圾清运完成，现场具备下道工序条件'],
    Trade.plumbing => ['管线走向清晰，开槽深度合理', '通水通电测试正常，隐蔽工程照片完整'],
    Trade.waterproof => ['防水高度和涂刷遍数达标', '闭水试验无渗漏，节点照片完整'],
    Trade.masonry => ['砖面平整、缝隙均匀、空鼓率达标', '阴阳角垂直，地漏坡度正确'],
    Trade.carpentry => ['安装牢固，收口平整，无明显缝隙', '柜体/吊顶尺寸与方案一致'],
    Trade.painting => ['墙面平整无明显色差、裂纹和流坠', '阴阳角顺直，成品保护完整'],
    Trade.installation => ['设备安装牢固，功能测试正常', '五金收口整洁，无划伤破损'],
    Trade.cleaning => ['空间无明显灰尘、胶痕和施工残留', '玻璃、地面、台面清洁达标'],
    null => ['施工结果符合平台验收标准', '照片、记录、验收结论完整留档'],
  };
}

String _formatVisitTime(DateTime? time) {
  if (time == null) return '待确认上门时间';
  final period = time.hour < 12 ? '上午' : '下午';
  final hour = time.hour <= 12 ? time.hour : time.hour - 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.month}月${time.day}日 $period$hour:$minute';
}

String _money(double value) {
  if (value <= 0) return '¥0';
  return '¥${value.toStringAsFixed(0)}';
}
