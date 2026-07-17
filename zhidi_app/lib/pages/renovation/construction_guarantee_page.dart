import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import 'trade_select_page.dart';

/// 施工保障页
/// 首页「施工保障」入口跳转目标。
/// 文案与布局 1:1 还原参考图：Banner + 5大保障体系 + 标准施工流程 + 知底承诺 + 底部CTA。

class ConstructionGuaranteePage extends StatelessWidget {
  const ConstructionGuaranteePage({super.key});

  static const Color _orange = ZdColors.primary;
  static const Color _orangeDark = ZdColors.primaryDark;
  static const Color _textDark = ZdColors.textPrimary;
  static const Color _textGray = ZdColors.textSecondary;
  static const Color _bgLight = ZdColors.cardBg;

  // 5大保障体系
  static const List<_Guarantee> _guarantees = [
    _Guarantee(Icons.engineering_outlined, '师傅严选', ['多重审核认证', '专业技能考核', '持证上岗']),
    _Guarantee(Icons.monetization_on_outlined, '工价透明', ['平台统一工价', '明码标价 无增项', '拒绝乱收费']),
    _Guarantee(Icons.rule_outlined, '施工规范', ['标准施工流程', '节点验收把控', '质量有保障']),
    _Guarantee(Icons.account_balance_outlined, '资金银行托管', ['装修款进银行监管账户', '平台不设资金池', '银行按节点放款']),
    _Guarantee(Icons.headset_mic_outlined, '售后无忧', ['专属客服跟进', '售后问题及时响应', '解决更省心']),
  ];

  // 标准施工流程（6步横向）
  static const List<_FlowStep> _flow = [
    _FlowStep(Icons.straighten, '上门量房', '精准测量 明确需求'),
    _FlowStep(Icons.price_check, '报价确认', '明细报价 确认无误'),
    _FlowStep(Icons.description_outlined, '签约下单', '平台签约 保障权益'),
    _FlowStep(Icons.construction_outlined, '施工开工', '规范施工 按期推进'),
    _FlowStep(Icons.fact_check_outlined, '竣工验收', '节点验收 质量把关'),
    _FlowStep(Icons.paid_outlined, '满意付款', '验收合格 平台付款'),
  ];

  // 知底承诺（2x2）
  static const List<_Promise> _promises = [
    _Promise(Icons.shield_outlined, '卖约必赔', '师傅爽约\n平台赔付'),
    _Promise(Icons.schedule_outlined, '延误必赔', '工期延误\n平台赔付'),
    _Promise(Icons.verified_outlined, '质量保障', '施工质量不达标\n平台介入处理'),
    _Promise(Icons.lock_outline, '隐私保障', '严密保护您的\n个人信息安全'),
  ];

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
                const SizedBox(height: 24),
                _buildGuaranteeSection(),
                const SizedBox(height: 24),
                _buildFlowSection(),
                const SizedBox(height: 24),
                _buildPromiseSection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomCta(context),
    );
  }

  // ── 顶部导航 ──
  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: _orange,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('施工保障', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
      centerTitle: true,
      pinned: true,
    );
  }

  // ── Banner ──
  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_orange, _orangeDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('施工保障', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('装修全程 · 安心托付', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text('5大保障体系 · 守护您的装修每一步', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: ['更专业', '更规范', '更透明', '更放心']
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check, color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                          Text(t, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── 区块标题 ──
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 14),
      child: Row(
        children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _textDark)),
        ],
      ),
    );
  }

  // ── 5大保障体系 ──
  Widget _buildGuaranteeSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('5大保障 全程守护'),
          ..._guarantees.map((g) => _buildGuaranteeCard(g)),
        ],
      ),
    );
  }

  Widget _buildGuaranteeCard(_Guarantee g) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZdColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(g.icon, color: _orange, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textDark)),
                const SizedBox(height: 6),
                ...g.points.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          Container(width: 4, height: 4, decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Text(p, style: const TextStyle(fontSize: 13, color: _textGray, height: 1.4)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 标准施工流程（横向滚动）──
  Widget _buildFlowSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _sectionTitle('标准施工流程 规范每一步'),
        ),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _flow.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final step = _flow[i];
              final isLast = i == _flow.length - 1;
              return Container(
                width: 104,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bgLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ZdColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(14)),
                          child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
                        ),
                        const SizedBox(width: 8),
                        Icon(step.icon, color: _orange, size: 20),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(step.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textDark)),
                    const SizedBox(height: 4),
                    Text(step.desc, style: const TextStyle(fontSize: 11, color: _textGray, height: 1.4)),
                    if (isLast) const SizedBox.shrink(),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 知底承诺（2x2）──
  Widget _buildPromiseSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('知底承诺 装修更放心'),
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = 12.0;
              final cardW = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _promises.map((p) => SizedBox(width: cardW, child: _buildPromiseCard(p))).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPromiseCard(_Promise p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZdColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(p.icon, color: _orange, size: 24),
          const SizedBox(height: 10),
          Text(p.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textDark)),
          const SizedBox(height: 4),
          Text(p.desc, style: const TextStyle(fontSize: 12, color: _textGray, height: 1.4)),
        ],
      ),
    );
  }

  // ── 底部 CTA ──
  Widget _buildBottomCta(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('装修找知底 安心有保障', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textDark)),
            const SizedBox(height: 4),
            const Text('工价透明 施工规范 售后无忧', style: TextStyle(fontSize: 12, color: _textGray)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TradeSelectPage()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('立即找师傅'),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Guarantee {
  final IconData icon;
  final String title;
  final List<String> points;
  const _Guarantee(this.icon, this.title, this.points);
}

class _FlowStep {
  final IconData icon;
  final String title;
  final String desc;
  const _FlowStep(this.icon, this.title, this.desc);
}

class _Promise {
  final IconData icon;
  final String title;
  final String desc;
  const _Promise(this.icon, this.title, this.desc);
}
