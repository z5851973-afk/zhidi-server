import 'package:flutter/material.dart';
import '../../../models/renovation.dart';
import '../../../design/tokens.dart';
import '../../../services/worker_directory_api_client.dart';
import '../../../services/worker_case_api_client.dart';
import '../../renovation/worker_detail_page.dart';

/// 工人列表页
/// 链路：工种(TradeSelectPage) → 工价(PriceListPage) → 工人列表(本页) → 工人详情(WorkerDetailPage)
class WorkerListPage extends StatefulWidget {
  /// 当前工种（用于动态标题）
  final Trade trade;

  /// 可选：分类名（如从 PriceListPage 传入更友好的展示名）
  final String? categoryName;

  /// 可选：用于测试或替换后端实现；默认请求 Spring Boot 工匠公开目录。
  final WorkerDirectoryApi? workerDirectoryApi;
  final WorkerCaseApi? workerCaseApi;

  const WorkerListPage({
    super.key,
    required this.trade,
    this.categoryName,
    this.workerDirectoryApi,
    this.workerCaseApi,
  });

  /// 工序名称列表（与 _PhaseEngine.phaseNames 保持同步）
  static const phaseNames = ['打拆', '水电', '防水', '泥工', '木工', '美缝', '安装', '清洁'];

  /// Trade → phaseIndex 反向映射
  static int? tradeToPhaseIndex(Trade trade) {
    switch (trade) {
      case Trade.demolition:
        return 0;
      case Trade.plumbing:
        return 1;
      case Trade.waterproof:
        return 2;
      case Trade.masonry:
        return 3;
      case Trade.carpentry:
        return 4;
      case Trade.painting:
        return 5;
      case Trade.installation:
        return 6;
      case Trade.cleaning:
        return 7;
    }
  }

  @override
  State<WorkerListPage> createState() => _WorkerListPageState();
}

class _WorkerListPageState extends State<WorkerListPage> {
  /// 选中的工人索引（单选），-1 表示未选
  int _selectedIndex = -1;

  final String _sortType = 'experience';
  List<RemoteWorkerDirectoryProfile> _remoteWorkers = const [];
  bool _loading = true;
  String? _loadError;

  WorkerDirectoryApi get _workerDirectoryApi =>
      widget.workerDirectoryApi ?? WorkerDirectoryApiClient();

  @override
  void initState() {
    super.initState();
    _loadRemoteWorkers();
  }

  @override
  void didUpdateWidget(covariant WorkerListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trade != widget.trade ||
        oldWidget.workerDirectoryApi != widget.workerDirectoryApi) {
      _selectedIndex = -1;
      _loadRemoteWorkers();
    }
  }

  // ── 动态标题 ──
  String get _title {
    final name = widget.categoryName ?? widget.trade.label;
    final title = name.endsWith('师傅') ? '$name列表' : '$name师傅列表';
    return title;
  }

  // ── 当前工种下的工人（按排序方式实时排序）──
  List<Worker> get _workers {
    final byId = <String, Worker>{};
    for (final remote in _remoteWorkers) {
      final worker = _remoteToWorker(remote);
      if (worker != null && worker.trade == widget.trade) {
        byId[worker.id] = worker;
      }
    }
    final list = byId.values.toList();
    list.sort((a, b) {
      return b.experienceYears.compareTo(a.experienceYears);
    });
    return list;
  }

  Future<void> _loadRemoteWorkers() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final workers = await _workerDirectoryApi.listWorkers();
      if (!mounted) return;
      setState(() {
        _remoteWorkers = workers;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _remoteWorkers = const [];
        _loadError = '师傅列表加载失败，请检查网络后重试';
        _loading = false;
      });
    }
  }

  void _selectWorker(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _confirmSelection(BuildContext context) async {
    if (_selectedIndex < 0) return;
    final worker = _workers[_selectedIndex];
    final remoteProfile = _remoteWorkers.firstWhere(
      (remote) => _remoteWorkerId(remote) == worker.id,
    );
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerDetailPage(
          workerName: worker.name,
          trade: worker.trade,
          distance: worker.distance,
          remoteProfile: remoteProfile,
          caseApi: widget.workerCaseApi,
        ),
      ),
    );
    if (result == true && context.mounted) {
      Navigator.of(context).pop(worker);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workers = _workers;
    final hasSelection = _selectedIndex >= 0;
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: ZdColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _title,
          style: const TextStyle(
            color: ZdColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_outlined,
                            color: ZdColors.textHint,
                            size: 44,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _loadError!,
                            style: const TextStyle(color: ZdColors.textHint),
                          ),
                          TextButton(
                            onPressed: _loadRemoteWorkers,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : workers.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无该工种师傅',
                        style: TextStyle(color: ZdColors.textHint),
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        const SliverToBoxAdapter(child: _PlatformTrustBar()),
                        SliverToBoxAdapter(
                          child: _SortBar(
                            current: _sortType,
                            onChanged: (_) {},
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          sliver: SliverList.separated(
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemCount: workers.length,
                            itemBuilder: (_, i) => _WorkerListItem(
                              worker: workers[i],
                              selected: _selectedIndex == i,
                              onTap: () => _selectWorker(i),
                              showDistance: false,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            // 底部固定确认栏
            _ConfirmBar(
              enabled: hasSelection,
              workerName: hasSelection ? workers[_selectedIndex].name : null,
              onConfirm: () => _confirmSelection(context),
            ),
          ],
        ),
      ),
    );
  }
}

Worker? _remoteToWorker(RemoteWorkerDirectoryProfile remote) {
  final trade = _remoteTrade(remote.primaryTrade);
  if (trade == null) return null;
  return Worker(
    id: _remoteWorkerId(remote),
    name: remote.name,
    trade: trade,
    experienceYears: remote.experienceYears,
    completedProjects: 0,
    rating: 0,
    avatar: trade.icon,
    intro: remote.bio?.isNotEmpty == true
        ? remote.bio!
        : '${remote.serviceCity ?? '本地'}${remote.primaryTrade}师傅，资料已完善。',
    certifications: const [],
    creditScore: 0,
    distance: 0,
    isOnline: false,
  );
}

String _remoteWorkerId(RemoteWorkerDirectoryProfile remote) =>
    'server:${remote.userId}';

Trade? _remoteTrade(String primaryTrade) {
  final value = primaryTrade.trim();
  // 优先按枚举名匹配（后端返回英文）
  for (final t in Trade.values) {
    if (t.name == value) return t;
  }
  // 兜底中文
  if (value.contains('拆')) return Trade.demolition;
  if (value.contains('水电')) return Trade.plumbing;
  if (value.contains('防水')) return Trade.waterproof;
  if (value.contains('泥') || value.contains('瓦')) return Trade.masonry;
  if (value.contains('木')) return Trade.carpentry;
  if (value.contains('漆') || value.contains('油')) return Trade.painting;
  if (value.contains('安装')) return Trade.installation;
  if (value.contains('洁') || value.contains('清')) return Trade.cleaning;
  return null;
}

/// 平台信任条（顶部，打破死板 + 强化兜底）
class _PlatformTrustBar extends StatelessWidget {
  const _PlatformTrustBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E9), Color(0xFFFFF8F2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(ZdRadius.md),
        border: Border.all(color: ZdColors.primary.withAlpha(20), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, size: 18, color: ZdColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '资料来自平台服务器 · 报价按平台价格表生成',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: ZdColors.primaryDark,
                height: 1.3,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: ZdColors.primary,
          ),
        ],
      ),
    );
  }
}

/// 排序标签栏（信用 / 距离 / 评分）
class _SortBar extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _SortBar({required this.current, required this.onChanged});

  static const _options = [(key: 'experience', label: '按从业年限排序')];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: _options.map((opt) {
          final active = current == opt.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt.key),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                height: 34,
                decoration: BoxDecoration(
                  color: active ? ZdColors.primary : ZdColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(ZdRadius.pill),
                  border: Border.all(
                    color: active ? ZdColors.primary : const Color(0xFFE5E5E5),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    color: active ? Colors.white : ZdColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 底部固定确认栏
class _ConfirmBar extends StatelessWidget {
  final bool enabled;
  final String? workerName;
  final VoidCallback onConfirm;

  const _ConfirmBar({
    required this.enabled,
    this.workerName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: enabled ? onConfirm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: ZdColors.primary,
              disabledBackgroundColor: const Color(0xFFE0E0E0),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              enabled ? '查看$workerName资料' : '请先选择一位师傅',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

/// 工人列表项卡片
class _WorkerListItem extends StatelessWidget {
  final Worker worker;
  final bool selected;
  final VoidCallback onTap;
  final bool showDistance;

  const _WorkerListItem({
    required this.worker,
    required this.selected,
    required this.onTap,
    this.showDistance = false,
  });

  /// 金牌师傅：高评分或高接单量
  bool get _isGold => worker.rating >= 4.9 || worker.completedProjects >= 500;

  @override
  Widget build(BuildContext context) {
    final isGold = _isGold;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? ZdColors.primary.withAlpha(12)
              : isGold
              ? const Color(0xFFFFF8F2)
              : ZdColors.surfaceWhite,
          borderRadius: BorderRadius.circular(ZdRadius.card),
          border: selected
              ? Border.all(color: ZdColors.primary, width: 1.5)
              : isGold
              ? Border.all(color: ZdColors.primary.withAlpha(40), width: 1)
              : null,
          boxShadow: ZdShadow.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧选中指示条（强化锚点）
            if (selected)
              Container(
                width: 4,
                height: 64,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: ZdColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            // 头像 + 金牌角标
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0EB),
                    borderRadius: BorderRadius.circular(ZdRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    worker.avatar,
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
                if (isGold)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x20000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            size: 9,
                            color: Colors.white,
                          ),
                          SizedBox(width: 2),
                          Text(
                            '金牌',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 姓名 + 资料状态 + 选中勾选徽标
                  Row(
                    children: [
                      Text(
                        worker.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ZdColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withAlpha(14),
                          borderRadius: BorderRadius.circular(ZdRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '资料已完善',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF34C759),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (selected)
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: ZdColors.primary,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        worker.rating > 0 ? '${worker.rating}分' : '暂无评价',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: ZdColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${worker.experienceYears}年经验',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ZdColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 差异化信任信息
                  Text(
                    worker.intro,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ZdColors.textHint,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    worker.certifications.isEmpty
                        ? '暂无资质证明'
                        : worker.certifications.join(' · '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: ZdColors.textHint,
                    ),
                  ),
                  if (showDistance)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            size: 13,
                            color: ZdColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '距您 ${worker.distance}km',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ZdColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // 右侧箭头
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: ZdColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
