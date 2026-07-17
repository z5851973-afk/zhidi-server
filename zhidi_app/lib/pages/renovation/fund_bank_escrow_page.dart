import 'package:flutter/material.dart';
import '../../design/tokens.dart';

/// 资金银行托管页
/// 参考设计稿重画为项目风格 widget：Hero + 为什么更安全(4优势) + 8步交易流程 + 常见问题(可展开)。
/// 文案 1:1 还原参考图，视觉走 ZdColors token，主色橙色。

class FundBankEscrowPage extends StatelessWidget {
  const FundBankEscrowPage({super.key});

  static const Color _orange = ZdColors.primary;
  static const Color _textDark = ZdColors.textPrimary;
  static const Color _textGray = ZdColors.textSecondary;

  // 为什么更安全：4 个优势
  static const List<_Advantage> _advantages = [
    _Advantage(Icons.account_balance_outlined, '银行监管', '资金进入银行监管账户，不是平台账户'),
    _Advantage(Icons.block_outlined, '平台不碰钱', '平台无法挪用、无法截留业主资金'),
    _Advantage(Icons.fact_check_outlined, '验收再放款', '施工完成并验收通过后，银行再放款'),
    _Advantage(Icons.lock_outline, '异常可冻结', '发生争议时资金暂留，保障双方权益'),
  ];

  // 交易流程：8 步
  static const List<_FlowStep> _flow = [
    _FlowStep('1', '预约师傅', '选择师傅达成意向'),
    _FlowStep('2', '平台生成订单', '确认需求生成订单'),
    _FlowStep('3', '业主付款', '支付装修款至监管账户'),
    _FlowStep('4', '进入银行监管账户', '资金由银行监管，平台不碰钱'),
    _FlowStep('5', '师傅施工', '预约施工完成工作'),
    _FlowStep('6', '节点验收', '业主/平台验收确认合格'),
    _FlowStep('7', '银行放款', '银行按节点放款给师傅'),
    _FlowStep('8', '订单完成', '交易完成售后保障'),
  ];

  // 常见问题
  static const List<_Faq> _faqs = [
    _Faq('为什么钱不是直接给师傅？', '为了保障双方权益，施工完成并验收后，银行才按节点放款给师傅。'),
    _Faq('平台能动我的钱吗？', '不能。平台不设资金池，资金由银行监管，平台无法存放或使用装修款。'),
    _Faq('退款怎么办？', '如未放款，业主可按平台规则申请退款，未放款部分由银行退回业主。'),
    _Faq('如果发生纠纷怎么办？', '银行会暂停相应款项的放款，等待平台协调处理，保障双方权益。'),
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
      title: const Text('资金银行托管', style: TextStyle(color: _textDark, fontSize: 17, fontWeight: FontWeight.w600)),
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
            '装修款进入银行监管账户\n平台不设资金池',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.35),
          ),
          const SizedBox(height: 12),
          const Text(
            '平台只负责交易管理、节点验收与放款指令，资金始终由合作银行监管。',
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['银行监管', '安全透明', '资金无忧']
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 13)),
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

  // ── 为什么更安全 ──
  Widget _buildAdvantageSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('为什么更安全？'),
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = 12.0;
              final cardW = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _advantages.map((a) => SizedBox(width: cardW, child: _buildAdvantageCard(a))).toList(),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(a.icon, color: _orange, size: 26),
          const SizedBox(height: 10),
          Text(a.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textDark)),
          const SizedBox(height: 6),
          Text(a.desc, style: const TextStyle(fontSize: 13, color: _textGray, height: 1.5)),
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
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                for (int i = 0; i < _flow.length; i++) ...[
                  _buildFlowRow(_flow[i]),
                  if (i < _flow.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 17),
                      child: Container(width: 2, height: 16, color: ZdColors.divider),
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
          child: Center(child: Text(step.no, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textDark)),
                const SizedBox(height: 3),
                Text(step.desc, style: const TextStyle(fontSize: 13, color: _textGray, height: 1.4)),
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
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                for (int i = 0; i < _faqs.length; i++) ...[
                  _FaqTile(faq: _faqs[i]),
                  if (i < _faqs.length - 1) Divider(height: 1, color: ZdColors.divider, indent: 16, endIndent: 16),
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
                  child: Text(widget.faq.q, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ZdColors.textPrimary)),
                ),
                Icon(_open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: ZdColors.textSecondary, size: 22),
              ],
            ),
            if (_open) ...[
              const SizedBox(height: 8),
              Text(widget.faq.a, style: const TextStyle(fontSize: 14, color: ZdColors.textSecondary, height: 1.6)),
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
