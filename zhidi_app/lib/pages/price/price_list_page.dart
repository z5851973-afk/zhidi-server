import 'package:flutter/material.dart';
import '../../data/price_standards.dart';
import 'construction_project_detail_page.dart';
import 'price_item_list_page.dart';
import '../home/worker/worker_list_page.dart';

/// 工价标准分类列表页（工种主页面）
/// 通过 [trade] 参数化区分7个工种，统一模板
/// 视觉风格：白底 + 橙主色 + 顶部工人作业大图 Banner + 左缩略图右标题卡片 + 底部保障卡

class PriceListPage extends StatelessWidget {
  final TradePriceData trade;

  const PriceListPage({super.key, required this.trade});

  static const Color brandOrange = Color(0xFFFF7A2F);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textGray = Color(0xFF8A8A8A);
  static const Color bgLight = Color(0xFFF6F6F6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          trade.pageTitle,
          style: const TextStyle(
            color: textDark,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.help_outline,
              color: Color(0xFFBFBFBF),
              size: 22,
            ),
            onPressed: () => _showPriceHelp(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner 区域（工人照背景 + 代码绘制文字/标签/按钮）──
            _buildBanner(context),

            const SizedBox(height: 22),

            // ── 分类区标题 ──
            _buildSectionHeader(),

            const SizedBox(height: 14),

            // ── 分类卡片列表 ──
            _buildCategoryList(context),

            const SizedBox(height: 24),

            // ── 平台保障卡 ──
            _buildGuarantee(),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  void _showPriceHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '工价说明',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textDark,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '页面展示的是平台统一人工参考价，实际结算会按现场工程量、施工难度和验收结果确认。材料、垃圾清运等非人工费用会单独说明。',
              style: TextStyle(fontSize: 14, color: textGray, height: 1.55),
            ),
          ],
        ),
      ),
    );
  }

  // ──────── Banner ────────

  Widget _buildBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 248),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(trade.bannerImage),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xB3000000), Color(0x4D000000)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 大标题
            const Text(
              '平台统一工价',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.15,
              ),
            ),
            const Text(
              '透明不加价',
              style: TextStyle(
                color: brandOrange,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '人工固定价格 · 实际工程量结算',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 12),
            // 四个标签
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _BannerTag(label: '银行监管'),
                _BannerTag(label: '验收保障'),
              ],
            ),
            const SizedBox(height: 16),
            // 查看可接单师傅按钮
            GestureDetector(
              onTap: () async {
                final worker = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkerListPage(
                      trade: trade.trade,
                      categoryName: trade.tradeName,
                    ),
                  ),
                );
                if (worker != null && context.mounted) {
                  Navigator.of(context).pop(worker);
                }
              },
              child: Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  color: brandOrange,
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: [
                    BoxShadow(
                      color: brandOrange.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '查看可接单师傅',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                '已有128位师傅在线 · 平均10分钟响应',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────── Section Header ────────

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${trade.tradeName}项目',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '统一工价 · 银行监管',
            style: TextStyle(fontSize: 13, color: textGray),
          ),
        ],
      ),
    );
  }

  // ──────── 分类列表（左缩略图 + 右标题/描述/数量 + 箭头）──────

  Widget _buildCategoryList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: trade.categories
            .map((cat) => _buildCategoryCard(context, cat))
            .toList(),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, PriceCategory category) {
    return GestureDetector(
      onTap: () {
        if (trade.tradeName == '拆除' && category.name == '墙体拆除') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const ConstructionProjectDetailPage.wallDemolition(),
            ),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PriceItemListPage(
              tradeName: trade.tradeName,
              category: category,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0F0F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 左缩略图
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: category.imageAsset != null
                    ? Image.asset(category.imageAsset!, fit: BoxFit.cover)
                    : Container(
                        color: bgLight,
                        child: Icon(
                          category.icon,
                          color: brandOrange,
                          size: 28,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            // 右标题区
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.description,
                    style: const TextStyle(fontSize: 12, color: textGray),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: brandOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${category.projectCount}项',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: brandOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }

  // ──────── 平台保障卡 ────────

  Widget _buildGuarantee() {
    const items = [
      _GuaranteeItem(icon: Icons.account_balance_outlined, label: '资金银行托管'),
      _GuaranteeItem(icon: Icons.fact_check_outlined, label: '验收付款'),
      _GuaranteeItem(icon: Icons.verified_user_outlined, label: '售后保障'),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '平台保障',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items,
          ),
        ],
      ),
    );
  }
}

/// Banner 标签
class _BannerTag extends StatelessWidget {
  final String label;
  const _BannerTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

/// 保障项
class _GuaranteeItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _GuaranteeItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: PriceListPage.brandOrange, size: 26),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: PriceListPage.textDark),
        ),
      ],
    );
  }
}
