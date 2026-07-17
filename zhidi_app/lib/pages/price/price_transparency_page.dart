import 'package:flutter/material.dart';
import '../renovation/trade_select_page.dart';

/// 工价透明（工价知底）页
/// 首页「工价透明」入口跳转目标。
/// 展示平台统一人工/辅材/主材单价标准，数据来自 quotation_templates.dart 真实报价模版。

class PriceTransparencyPage extends StatelessWidget {
  const PriceTransparencyPage({super.key});

  static const Color brandOrange = Color(0xFFFF7A2F);
  static const Color textDark = Color(0xFF333333);
  static const Color textGray = Color(0xFF808080);
  static const Color bgLight = Color(0xFFF8F8F8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBanner(),
                const SizedBox(height: 20),
                _buildGuaranteeCards(),
                const SizedBox(height: 24),
                _buildPriceSource(),
                const SizedBox(height: 24),
                _buildWorkflow(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomCta(context),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: brandOrange,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        '工价透明',
        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
      ),
      centerTitle: true,
      pinned: true,
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brandOrange, brandOrange.withValues(alpha: 0.85)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '平台统一工价',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            '人工 / 辅材 / 主材 明码标价，透明不加价',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ['工价透明', '银行监管', '验收保障']
                .map((label) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.5),
                      ),
                      child: Text(label,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGuaranteeCards() {
    const items = [
      (Icons.visibility_outlined, '工价透明', '统一标准\n杜绝随意加价'),
      (Icons.account_balance_outlined, '银行监管', '价格备案\n全程可追溯'),
      (Icons.verified_user_outlined, '师傅认证', '严选持证\n上岗有保障'),
      (Icons.assignment_turned_in_outlined, '验收保障', '满意验收\n再付工程款'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: items.asMap().entries.map((e) {
          final item = e.value;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: e.key == items.length - 1 ? 0 : 10),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: bgLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(item.$1, color: brandOrange, size: 24),
                  const SizedBox(height: 8),
                  Text(item.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textDark)),
                  const SizedBox(height: 4),
                  Text(item.$3, style: const TextStyle(fontSize: 10, color: textGray, height: 1.3), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 人工价格怎么来的 ──
  Widget _buildPriceSource() {
    const sources = [
      (Icons.groups_outlined, '市场调研', '采集本地装修市场各工种人工单价，取合理区间'),
      (Icons.rule_outlined, '标准核算', '按施工工艺、工时消耗与材料损耗综合测算'),
      (Icons.balance_outlined, '平台校准', '剔除虚高报价，统一备案形成参考单价'),
      (Icons.sync_outlined, '动态更新', '随市场行情定期复核，确保价格真实有效'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 14),
            child: Row(
              children: [
                Container(width: 4, height: 18, decoration: BoxDecoration(color: brandOrange, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                const Text('人工价格怎么来的', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textDark)),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: sources.asMap().entries.map((e) {
                final item = e.value;
                final isLast = e.key == sources.length - 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: brandOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.$1, color: brandOrange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textDark)),
                            const SizedBox(height: 4),
                            Text(item.$3, style: const TextStyle(fontSize: 13, color: textGray, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              '平台仅提供人工参考单价，最终以实际工程量测量结算，杜绝随意加价。',
              style: TextStyle(fontSize: 12, color: textGray, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflow() {
    const steps = [
      ('预约师傅', '选择工种\n平台派单上门', Icons.person_add_alt_1, 'assets/images/worker_confident.png'),
      ('上门测量', '师傅现场勘测\n确认工程量', Icons.straighten, 'assets/images/trades/masonry_banner.jpg'),
      ('免费报价', '按平台标准\n核算人工与材料', Icons.price_check, 'assets/images/trades/carpentry_banner.jpg'),
      ('确认签约', '明细透明\n线上签约托管', Icons.handshake, 'assets/images/trades/installation_banner.jpg'),
      ('阶段验收', '按节点验收\n满意再付款', Icons.task_alt, 'assets/images/trades/painting_banner.jpg'),
      ('完工结算', '验收合格\n按实结算尾款', Icons.celebration, 'assets/images/trades/cleaning_banner.jpg'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 14),
            child: Row(
              children: [
                Container(width: 4, height: 18, decoration: BoxDecoration(color: brandOrange, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                const Text('报价流程', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textDark)),
              ],
            ),
          ),
          ...steps.asMap().entries.map((e) {
            final step = e.value;
            final isLast = e.key == steps.length - 1;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: brandOrange, borderRadius: BorderRadius.circular(16)),
                          child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                        ),
                        if (!isLast)
                          Expanded(child: Container(width: 2, color: brandOrange.withValues(alpha: 0.2))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: AssetImage(step.$4),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.55),
                              BlendMode.darken,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: brandOrange.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(step.$3, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(step.$1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text(step.$2, style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomCta(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TradeSelectPage()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: brandOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            child: const Text('立即找师傅'),
          ),
        ),
      ),
    );
  }
}
