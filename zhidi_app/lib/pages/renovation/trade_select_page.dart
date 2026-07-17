import 'package:flutter/material.dart';
import '../../models/renovation.dart';
import '../../data/price_standards.dart';
import '../price/price_transparency_page.dart';
import '../price/price_list_page.dart';
import '../home/worker/worker_list_page.dart';
import '../../design/tokens.dart';

/// 找师傅 · 工种直达（沉浸式照片卡片版）
/// 每个工种卡片使用真实工地施工照片作为背景，文字叠加在深色渐变遮罩上

// ══════════════════════════════════════════
// Trade → 工种展示数据
// ══════════════════════════════════════════
class _TradeCardData {
  final Trade? trade;
  final String label;
  final String stageLabel;
  final int workerCount; // 在线可接单师傅数（按工种统计 mockWorkers 中 isOnline 的数量）
  final List<String> tags;
  final String stepLabel;

  /// 施工照片资源路径，例如 'assets/images/trades/demolition.jpg'
  final String photoAsset;

  /// 无照片时的 fallback 渐变色
  final List<Color> fallbackColors;
  final Alignment imageAlignment;

  const _TradeCardData({
    required this.trade,
    required this.label,
    required this.stageLabel,
    required this.workerCount,
    required this.tags,
    required this.stepLabel,
    required this.photoAsset,
    required this.fallbackColors,
    this.imageAlignment = Alignment.center,
  });
}

// ══════════════════════════════════════════
// TradeSelectPage
// ══════════════════════════════════════════
class TradeSelectPage extends StatefulWidget {
  /// 可选：传入后预筛对应工种（designer / inspector / maintenance 等）
  final String? serviceType;

  const TradeSelectPage({super.key, this.serviceType});

  @override
  State<TradeSelectPage> createState() => _TradeSelectPageState();
}

class _TradeSelectPageState extends State<TradeSelectPage> {
  static const _bg = Color(0xFFF5EFE3);

  // 搜索
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // 工种数据
  late final List<_TradeCardData> _allTrades;

  /// serviceType → 预筛标签（designer/inspector/maintenance 等旧入口）
  static const Map<String, List<String>> _serviceTypeFilter = {
    'designer': ['设计', '设计师'],
    'inspector': ['监理', '验收'],
    'maintenance': ['维修', '售后'],
  };

  @override
  void initState() {
    super.initState();
    final filterTags = widget.serviceType != null
        ? _serviceTypeFilter[widget.serviceType]
        : null;
    _allTrades = [
      _TradeCardData(
        trade: Trade.demolition,
        label: '拆除师傅',
        stageLabel: '拆旧阶段',
        stepLabel: '第一步',
        workerCount: 0,
        tags: ['拆墙', '拆旧', '垃圾清运'],
        photoAsset: 'assets/images/trades/demolition_banner.jpg',
        fallbackColors: [const Color(0xFF7B3A1E), const Color(0xFF5A2510)],
        imageAlignment: Alignment.centerLeft,
      ),
      _TradeCardData(
        trade: Trade.plumbing,
        label: '水电师傅',
        stageLabel: '基础施工',
        stepLabel: '第二步',
        workerCount: 0,
        tags: ['水电改造', '管道安装', '布线'],
        photoAsset: 'assets/images/trades/plumbing_banner.jpg',
        fallbackColors: [const Color(0xFF6B4A30), const Color(0xFF4A2E1C)],
        imageAlignment: Alignment.centerRight,
      ),
      _TradeCardData(
        trade: Trade.waterproof,
        label: '防水师傅',
        stageLabel: '基础施工',
        stepLabel: '第三步',
        workerCount: 0,
        tags: ['厨卫防水', '阳台防水', '堵漏'],
        photoAsset: 'assets/images/trades/waterproof.jpg',
        fallbackColors: [const Color(0xFF7A5540), const Color(0xFF4D3326)],
        imageAlignment: Alignment.center,
      ),
      _TradeCardData(
        trade: Trade.masonry,
        label: '泥瓦师傅',
        stageLabel: '基础施工',
        stepLabel: '第四步',
        workerCount: 0,
        tags: ['贴砖', '砌墙', '地面找平'],
        photoAsset: 'assets/images/trades/masonry_banner.jpg',
        fallbackColors: [const Color(0xFF8B5E3C), const Color(0xFF5E3A20)],
        imageAlignment: Alignment.center,
      ),
      _TradeCardData(
        trade: Trade.carpentry,
        label: '木工师傅',
        stageLabel: '硬装施工',
        stepLabel: '第五步',
        workerCount: 0,
        tags: ['吊顶', '衣柜', '橱柜'],
        photoAsset: 'assets/images/trades/carpentry_banner.jpg',
        fallbackColors: [const Color(0xFF7B5A3E), const Color(0xFF553A25)],
        imageAlignment: Alignment.center,
      ),
      _TradeCardData(
        trade: Trade.painting,
        label: '油漆师傅',
        stageLabel: '收尾安装',
        stepLabel: '第六步',
        workerCount: 0,
        tags: ['刷墙', '喷漆', '墙面修复'],
        photoAsset: 'assets/images/trades/painting_banner.jpg',
        fallbackColors: [const Color(0xFF9B6A4A), const Color(0xFF6B4530)],
        imageAlignment: Alignment.center,
      ),
      _TradeCardData(
        trade: Trade.installation,
        label: '安装师傅',
        stageLabel: '收尾安装',
        stepLabel: '第七步',
        workerCount: 0,
        tags: ['灯具安装', '洁具安装', '五金'],
        photoAsset: 'assets/images/trades/installation_banner.jpg',
        fallbackColors: [const Color(0xFF6B4C36), const Color(0xFF4A3220)],
        imageAlignment: Alignment.center,
      ),
      _TradeCardData(
        trade: null,
        label: '报价',
        stageLabel: '费用确认',
        stepLabel: '第八步',
        workerCount: 0,
        tags: ['固定工价', '报价透明', '费用明细'],
        photoAsset: 'assets/images/trades/carpentry_banner.jpg',
        fallbackColors: [const Color(0xFF8B6B52), const Color(0xFF5E4535)],
        imageAlignment: Alignment.center,
      ),
    ];
    if (filterTags != null) {
      _allTrades = _allTrades.where((t) {
        return t.tags.any((tag) => filterTags.any((f) => tag.contains(f))) ||
            filterTags.any((f) => t.label.contains(f));
      }).toList();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── 过滤 ──
  List<_TradeCardData> get _filteredTrades {
    if (_searchQuery.isEmpty) return _allTrades;
    final q = _searchQuery.toLowerCase();
    return _allTrades.where((t) {
      return t.label.contains(q) ||
          t.tags.any((tag) => tag.contains(q)) ||
          t.stageLabel.contains(q);
    }).toList();
  }

  Future<void> _onTradeTap(Trade trade) async {
    final serviceType = switch (trade) {
      Trade.demolition => 'demolition',
      Trade.plumbing => 'plumbing',
      Trade.masonry => 'masonry',
      Trade.waterproof => 'waterproof',
      Trade.carpentry => 'carpentry',
      Trade.painting => 'painter',
      Trade.installation => 'installation',
      Trade.cleaning => 'cleaning',
    };

    final worker = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PriceListPage(trade: tradeToPriceData(serviceType)),
      ),
    );
    if (!mounted) return;
    if (worker != null) {
      Navigator.of(context).pop(worker);
    }
  }

  void _onQuoteTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PriceTransparencyPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('找师傅', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: ZdColors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '先选工种，平台马上为你匹配可接单师傅',
                  style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
                ),
              ),
            ),
            Expanded(child: _buildTradeGrid()),
          ],
        ),
      ),
    );
  }

  // ═══ 搜索框 ═══
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDE8),
                borderRadius: BorderRadius.circular(21),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(
                  fontSize: 14,
                  color: ZdColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: '搜工种、搜需求，比如"贴砖""水电"',
                  hintStyle: TextStyle(fontSize: 14, color: ZdColors.textHint),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: ZdColors.textHint,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E0),
              borderRadius: BorderRadius.circular(21),
            ),
            child: const Center(
              child: Text(
                '帮我选',
                style: TextStyle(
                  fontSize: 14,
                  color: ZdColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══ 工种网格 ═══
  Widget _buildTradeGrid() {
    final trades = _filteredTrades;
    if (trades.isEmpty) {
      return const Center(
        child: Text('没找到匹配的工种', style: TextStyle(color: ZdColors.textHint)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.92,
      ),
      itemCount: trades.length,
      itemBuilder: (_, i) => _TradeCard(
        data: trades[i],
        onTap: () {
          final trade = trades[i].trade;
          if (trade == null) {
            _onQuoteTap();
          } else {
            _onTradeTap(trade);
          }
        },
        onWorkerTap: () async {
          final trade = trades[i].trade;
          if (trade == null) {
            _onQuoteTap();
            return;
          }
          final worker = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  WorkerListPage(trade: trade, categoryName: trades[i].label),
            ),
          );
          if (!mounted) return;
          if (worker != null) {
            Navigator.of(context).pop(worker);
          }
        },
      ),
    );
  }
}

// ══════════════════════════════════════════
// 工种卡片组件（沉浸式照片版）
// ══════════════════════════════════════════
class _TradeCard extends StatelessWidget {
  final _TradeCardData data;
  final VoidCallback onTap;
  final VoidCallback onWorkerTap;

  const _TradeCard({
    required this.data,
    required this.onTap,
    required this.onWorkerTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 底层：施工照片（加载失败时 fallback 渐变） ──
            Image.asset(
              data.photoAsset,
              fit: BoxFit.cover,
              alignment: data.imageAlignment,
              errorBuilder: (_, _, _) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: data.fallbackColors,
                  ),
                ),
              ),
            ),
            // ── 渐变遮罩：底部深色 → 顶部透明 ──
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x22351A0C),
                    Color(0x8844260F),
                  ],
                  stops: [0.0, 0.52, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _StepBadge(label: data.stepLabel),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _TradeCueBadge(trade: data.trade),
            ),
            // ── 内容 ──
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 工种名
                  Text(
                    data.label,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 标签
                  _buildTags(),
                  const SizedBox(height: 10),
                  // 师傅信息
                  _buildWorkerRow(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTags() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: data.tags.map((t) {
          return Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              t,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFFE8E0D8),
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWorkerRow() {
    return Row(
      children: [
        const Spacer(),
        if (data.trade == null)
          Text(
            '查看报价标准',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
          )
        else
          Text(
            '${data.workerCount}位可接单',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: ZdColors.primary.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          height: 1,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TradeCueBadge extends StatelessWidget {
  const _TradeCueBadge({required this.trade});

  final Trade? trade;

  IconData get _icon {
    return switch (trade) {
      Trade.demolition => Icons.construction_rounded,
      Trade.plumbing => Icons.electrical_services_rounded,
      Trade.masonry => Icons.grid_view_rounded,
      Trade.waterproof => Icons.water_drop_rounded,
      Trade.carpentry => Icons.carpenter_rounded,
      Trade.painting => Icons.format_paint_rounded,
      Trade.installation => Icons.build_rounded,
      Trade.cleaning => Icons.auto_awesome_rounded,
      null => Icons.price_check_rounded,
    };
  }

  Color get _color {
    return switch (trade) {
      Trade.demolition => const Color(0xFFD8B28A),
      Trade.plumbing => const Color(0xFF5DA7E8),
      Trade.masonry => const Color(0xFFE6D5BD),
      Trade.waterproof => const Color(0xFF2E8FE8),
      Trade.carpentry => const Color(0xFFD39B5B),
      Trade.painting => const Color(0xFFF2E9DC),
      Trade.installation => const Color(0xFFE8C16E),
      Trade.cleaning => const Color(0xFFB9E7E2),
      null => const Color(0xFFFFD39B),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Icon(_icon, color: _color, size: 19),
    );
  }
}

// ══════════════════════════════════════════
// 通用按钮（保留）
// ══════════════════════════════════════════
