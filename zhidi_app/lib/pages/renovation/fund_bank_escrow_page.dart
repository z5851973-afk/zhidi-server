import 'package:flutter/material.dart';
import '../../design/tokens.dart';

/// 线下付款说明页。
/// 当前真实流程是线下转账、付款信息上报和人工确认。

class FundBankEscrowPage extends StatelessWidget {
  const FundBankEscrowPage({super.key});

  static const Color _orange = ZdColors.primary;
  static const Color _textDark = ZdColors.textPrimary;
  static const Color _textGray = ZdColors.textSecondary;

  // 当前可用的付款能力
  static const List<_Advantage> _advantages = [
    _Advantage(Icons.receipt_long_outlined, '订单明细', '按订单展示报价、收款对象与应付金额'),
    _Advantage(Icons.compare_arrows_outlined, '线下转账', '业主在应用外按订单收款信息完成付款'),
    _Advantage(Icons.fact_check_outlined, '人工确认', '付款信息由相关方人工核对后更新状态'),
    _Advantage(Icons.support_agent_outlined, '售后协助', '已支付订单可提交订单绑定的售后申请'),
  ];

  // 交易流程：8 步
  static const List<_FlowStep> _flow = [
    _FlowStep('1', '选择师傅', '核对师傅资料与报价清单'),
    _FlowStep('2', '施工与验收', '施工日报和验收结果按订单留痕'),
    _FlowStep('3', '生成付款单', '查看订单对应金额与收款说明'),
    _FlowStep('4', '完成线下付款', '在应用外向订单列明的收款对象付款'),
    _FlowStep('5', '提交付款信息', '填写付款方式和交易参考号'),
    _FlowStep('6', '人工核对', '师傅确认工程款，平台核验服务费'),
    _FlowStep('7', '更新订单状态', '核对完成后保留付款记录'),
    _FlowStep('8', '订单售后', '如有问题，从已支付订单提交售后申请'),
  ];

  // 常见问题
  static const List<_Faq> _faqs = [
    _Faq('当前如何付款？', '当前采用线下付款。请只使用具体订单付款页展示的收款信息，并在付款前核对收款对象和金额。'),
    _Faq('提交付款信息后会直接转账吗？', '不会。提交动作只上报付款方式和交易参考号，订单状态要等待相关方人工核对。'),
    _Faq('付款后有问题怎么办？', '从已支付订单进入售后，提交退款、投诉或争议申请，由人工核对订单记录后处理。'),
    _Faq('在哪里查看处理结果？', '付款状态和售后处理结果都会保留在对应订单记录中。'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(),
                const SizedBox(height: 24),
                _buildAdvantageSection(),
                const SizedBox(height: 24),
                _buildFlowSection(),
                const SizedBox(height: 24),
                _buildFaqSection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 顶部导航 ──
  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: _textDark, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        '线下付款与人工确认',
        style: TextStyle(
          color: _textDark,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
      pinned: true,
    );
  }

  // ── Hero ──
  Widget _buildHero() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ZdColors.gradientPrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '线下付款与人工确认',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '付款页面展示订单金额和真实收款信息。付款在应用外完成，提交后由相关方人工核对。',
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['订单明细', '线下付款', '人工核对']
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                )
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
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: _orange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: _textDark,
            ),
          ),
        ],
      ),
    );
  }

  // ── 为什么更安全 ──
  Widget _buildAdvantageSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('当前付款方式'),
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = 12.0;
              final cardW = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _advantages
                    .map(
                      (a) =>
                          SizedBox(width: cardW, child: _buildAdvantageCard(a)),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdvantageCard(_Advantage a) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZdColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(a.icon, color: _orange, size: 26),
          const SizedBox(height: 10),
          Text(
            a.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            a.desc,
            style: const TextStyle(fontSize: 13, color: _textGray, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── 交易流程 ──
  Widget _buildFlowSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('交易流程'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZdColors.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (int i = 0; i < _flow.length; i++) ...[
                  _buildFlowRow(_flow[i]),
                  if (i < _flow.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 17),
                      child: Container(
                        width: 2,
                        height: 16,
                        color: ZdColors.divider,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowRow(_FlowStep step) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _orange,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Center(
            child: Text(
              step.no,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  step.desc,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _textGray,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 常见问题 ──
  Widget _buildFaqSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('常见问题'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZdColors.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (int i = 0; i < _faqs.length; i++) ...[
                  _FaqTile(faq: _faqs[i]),
                  if (i < _faqs.length - 1)
                    Divider(
                      height: 1,
                      color: ZdColors.divider,
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final _Faq faq;
  const _FaqTile({required this.faq});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.faq.q,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ZdColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: ZdColors.textSecondary,
                  size: 22,
                ),
              ],
            ),
            if (_open) ...[
              const SizedBox(height: 8),
              Text(
                widget.faq.a,
                style: const TextStyle(
                  fontSize: 14,
                  color: ZdColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Advantage {
  final IconData icon;
  final String title;
  final String desc;
  const _Advantage(this.icon, this.title, this.desc);
}

class _FlowStep {
  final String no;
  final String title;
  final String desc;
  const _FlowStep(this.no, this.title, this.desc);
}

class _Faq {
  final String q;
  final String a;
  const _Faq(this.q, this.a);
}
