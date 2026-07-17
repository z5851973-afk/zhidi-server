import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import '../renovation/trade_select_page.dart';

/// 师傅严选说明页
/// 入口：首页「为什么选择知底」区的「师傅严选」卡片
/// 作用：向用户解释平台如何严选师傅，以及 5 重审核机制的具体内容
class MasterSelectionPage extends StatelessWidget {
  const MasterSelectionPage({super.key});

  // ── 5 重审核机制（含右侧配图）──
  static const List<_AuditStep> _steps = [
    _AuditStep(
      icon: Icons.badge_outlined,
      title: '实名认证',
      desc: '身份证 + 人脸识别双重核验，确保师傅本人实名、真实可溯。',
      image: 'assets/images/trades/demolition.jpg',
    ),
    _AuditStep(
      icon: Icons.verified_user_outlined,
      title: '技能资质审核',
      desc: '相关工种证书 / 从业年限核验，无证不上岗，按工种分级定档。',
      image: 'assets/images/trades/masonry.jpg',
    ),
    _AuditStep(
      icon: Icons.work_history_outlined,
      title: '从业经历核查',
      desc: '过往施工案例与接单记录交叉验证，拒绝虚假履历与挂靠。',
      image: 'assets/images/trades/painting.jpg',
    ),
    _AuditStep(
      icon: Icons.star_rate_outlined,
      title: '信用评价筛选',
      desc: '历史业主评分、投诉率、爽约率多维评估，低分师傅自动淘汰。',
      image: 'assets/images/trades/plumbing.jpg',
    ),
    _AuditStep(
      icon: Icons.fact_check_outlined,
      title: '入驻培训考核',
      desc: '平台服务规范与施工标准培训并考核通过，方可接单上线。',
      image: 'assets/images/trades/carpentry.jpg',
    ),
  ];

  // ── 英雄区数据指标 ──
  static const List<_Metric> _metrics = [
    _Metric(icon: Icons.people_alt_outlined, value: '30%', label: '平均通过率'),
    _Metric(icon: Icons.verified_outlined, value: '5重', label: '审核机制'),
    _Metric(icon: Icons.star_outlined, value: '4.9', label: '业主好评'),
    _Metric(icon: Icons.shield_outlined, value: '100%', label: '实名可溯'),
  ];

  // ── 平台保障 4 宫格 ──
  static const List<_Guarantee> _guarantees = [
    _Guarantee(icon: Icons.handshake_outlined, title: '平台担保', desc: '资金托管\n验收满意再付款'),
    _Guarantee(icon: Icons.verified_user_outlined, title: '实名严选', desc: '5重审核\n持证方可接单'),
    _Guarantee(icon: Icons.support_agent_outlined, title: '全程跟进', desc: '专属管家\n进度随时可查'),
    _Guarantee(icon: Icons.replay_outlined, title: '售后无忧', desc: '质保期内\n问题免费返修'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: ZdColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '师傅严选',
          style: TextStyle(
            color: ZdColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 英雄区 ──
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [ZdColors.primary, ZdColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(ZdRadius.card),
                boxShadow: [
                  BoxShadow(
                    color: ZdColors.primary.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(ZdRadius.pill),
                    ),
                    child: const Text(
                      '严苛筛选 · 只为品质施工',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '不是随便一个工人\n都能叫知底师傅',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '每一位上线接单的师傅，都经过平台 5 重审核机制层层筛选。',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  // 数据指标卡（统一描边图标 + 统一字号）
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(ZdRadius.md),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _metrics.map((m) => _MetricItem(metric: m)).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // ── 标题 ──
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Text(
                '5 重审核机制',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ZdColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '从身份到服务，每一关都不放过',
                style: TextStyle(fontSize: 13, color: ZdColors.textSecondary),
              ),
            ),
            const SizedBox(height: 14),

            // ── 5 重机制列表（三栏：序号图标 / 文案 / 配图）──
            ..._steps.asMap().entries.map((e) {
              final index = e.key;
              final step = e.value;
              return _AuditCard(index: index, step: step);
            }),

            const SizedBox(height: 28),

            // ── 平台保障 4 宫格 ──
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '平台保障',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ZdColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: _guarantees.map((g) => _GuaranteeCard(guarantee: g)).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // ── 底部承诺条 ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ZdColors.cardBg,
                borderRadius: BorderRadius.circular(ZdRadius.card),
                border: Border.all(color: const Color(0xFFF0E5DB)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: ZdColors.primary, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '严选只是开始：入驻后平台仍持续监管评价与施工质量，违规即清退。',
                      style: TextStyle(fontSize: 13, color: ZdColors.textPrimary, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 底部 CTA（浅色描边，不抢戏）──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ZdRadius.card),
                border: Border.all(color: ZdColors.primary.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '严选好师傅，装修更省心',
                      style: TextStyle(
                        color: ZdColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TradeSelectPage()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [ZdColors.primary, ZdColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(ZdRadius.pill),
                      ),
                      child: const Row(
                        children: [
                          Text(
                            '立即找师傅',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios, color: Colors.white, size: 13),
                        ],
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

/// 英雄区数据指标
class _MetricItem extends StatelessWidget {
  final _Metric metric;
  const _MetricItem({required this.metric});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Icon(metric.icon, color: Colors.white, size: 20),
          const SizedBox(height: 6),
          Text(
            metric.value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            metric.label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.2),
          ),
        ],
      ),
    );
  }
}

/// 单条审核机制卡片（三栏：序号图标 / 文案 / 配图）
class _AuditCard extends StatelessWidget {
  final int index;
  final _AuditStep step;

  const _AuditCard({required this.index, required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZdRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 左：序号圆圈 + 图标
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: ZdColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(step.icon, color: ZdColors.primary, size: 20),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // 中：文案
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ZdColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  step.desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ZdColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 右：配图
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              step.image,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}

/// 平台保障卡片（图标统一浅橙底方块）
class _GuaranteeCard extends StatelessWidget {
  final _Guarantee guarantee;
  const _GuaranteeCard({required this.guarantee});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZdRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(guarantee.icon, color: ZdColors.primary, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            guarantee.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ZdColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            guarantee.desc,
            style: const TextStyle(
              fontSize: 11,
              color: ZdColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// 审核步骤数据
class _AuditStep {
  final IconData icon;
  final String title;
  final String desc;
  final String image;
  const _AuditStep({
    required this.icon,
    required this.title,
    required this.desc,
    required this.image,
  });
}

/// 英雄区指标数据
class _Metric {
  final IconData icon;
  final String value;
  final String label;
  const _Metric({required this.icon, required this.value, required this.label});
}

/// 平台保障数据
class _Guarantee {
  final IconData icon;
  final String title;
  final String desc;
  const _Guarantee({required this.icon, required this.title, required this.desc});
}
