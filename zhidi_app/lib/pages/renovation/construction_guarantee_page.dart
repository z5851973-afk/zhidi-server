import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import 'trade_select_page.dart';

/// 施工与售后能力说明页。

class ConstructionGuaranteePage extends StatelessWidget {
  const ConstructionGuaranteePage({super.key});

  static const Color _orange = ZdColors.primary;
  static const Color _orangeDark = ZdColors.primaryDark;
  static const Color _textDark = ZdColors.textPrimary;
  static const Color _textGray = ZdColors.textSecondary;
  static const Color _bgLight = ZdColors.cardBg;

  // 当前已接入的 5 项能力
  static const List<_Guarantee> _guarantees = [
    _Guarantee(Icons.engineering_outlined, '服务器资料', [
      '姓名、工种、城市和经验来自服务器',
      '案例数与被选中次数按服务端返回',
      '仅展示已接入的资料字段',
    ]),
    _Guarantee(Icons.monetization_on_outlined, '固定工价目录', [
      '报价项目按服务端目录选择',
      '项目、数量、单价和小计分项展示',
      '最终金额由业主确认报价',
    ]),
    _Guarantee(Icons.rule_outlined, '报价与施工留痕', [
      '报价清单按订单保存',
      '师傅可提交施工日报',
      '施工照片和说明可回看',
    ]),
    _Guarantee(Icons.fact_check_outlined, '验收记录', [
      '师傅按工种发起节点验收',
      '业主提交通过或驳回结果',
      '验收过程按订单留存',
    ]),
    _Guarantee(Icons.headset_mic_outlined, '售后人工协助', [
      '已支付订单可发起售后',
      '申请绑定真实预约编号',
      '处理结果以人工核对记录为准',
    ]),
  ];

  // 标准施工流程（6步横向）
  static const List<_FlowStep> _flow = [
    _FlowStep(Icons.person_search_outlined, '查看资料', '按工种查看服务器资料'),
    _FlowStep(Icons.straighten, '上门测量', '师傅现场确认工程量'),
    _FlowStep(Icons.price_check, '提交报价', '从固定目录生成明细清单'),
    _FlowStep(Icons.how_to_reg_outlined, '确认选人', '只选择师傅和报价'),
    _FlowStep(Icons.construction_outlined, '施工留痕', '日报和图片按订单保存'),
    _FlowStep(Icons.fact_check_outlined, '验收与付款', '验收记录后线下付款确认'),
  ];

  // 订单关键记录（2x2）
  static const List<_Promise> _promises = [
    _Promise(Icons.receipt_long_outlined, '报价记录', '项目与金额\n按订单保存'),
    _Promise(Icons.photo_camera_outlined, '施工记录', '日报与图片\n过程可回看'),
    _Promise(Icons.fact_check_outlined, '验收记录', '节点与结果\n按订单留存'),
    _Promise(Icons.support_agent_outlined, '售后协助', '订单问题\n由人工处理'),
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
      title: const Text(
        '施工与售后说明',
        style: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
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
          const Text(
            '服务能力说明',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '资料、报价、施工、验收按订单留痕',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '只说明当前已接入能力，实际结果以订单记录为准',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: ['服务器资料', '报价清单', '施工留痕', '人工售后']
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, color: Colors.white, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          t,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

  // ── 5大保障体系 ──
  Widget _buildGuaranteeSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('5项可用能力'),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                Text(
                  g.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 6),
                ...g.points.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _orange,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          p,
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
                          decoration: BoxDecoration(
                            color: _orange,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(step.icon, color: _orange, size: 20),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.desc,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textGray,
                        height: 1.4,
                      ),
                    ),
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
          _sectionTitle('关键记录'),
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = 12.0;
              final cardW = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _promises
                    .map(
                      (p) =>
                          SizedBox(width: cardW, child: _buildPromiseCard(p)),
                    )
                    .toList(),
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
          Icon(p.icon, color: _orange, size: 24),
          const SizedBox(height: 10),
          Text(
            p.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            p.desc,
            style: const TextStyle(fontSize: 12, color: _textGray, height: 1.4),
          ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '关键流程按订单留痕',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '问题可从订单发起售后，由人工协助处理',
              style: TextStyle(fontSize: 12, color: _textGray),
            ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
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
