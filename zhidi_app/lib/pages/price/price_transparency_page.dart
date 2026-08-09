import 'package:flutter/material.dart';
import '../renovation/trade_select_page.dart';

/// 参考工价与报价流程说明页。
/// 首页「工价透明」入口跳转目标。
/// 展示本地参考工价说明和真实报价流程。

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
            '参考工价说明',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '页面仅说明本地参考口径，最终以服务器报价清单和现场工程量为准',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ['本地参考', '明细报价', '验收留痕']
                .map(
                  (label) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGuaranteeCards() {
    const items = [
      (Icons.visibility_outlined, '参考目录', '本地项目\n示例展示'),
      (Icons.person_search_outlined, '服务器资料', '姓名工种\n按接口返回'),
      (Icons.receipt_long_outlined, '报价清单', '单价数量\n逐项核对'),
      (Icons.assignment_turned_in_outlined, '验收记录', '节点结果\n按订单留痕'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: items.asMap().entries.map((e) {
          final item = e.value;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(
                right: e.key == items.length - 1 ? 0 : 10,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: bgLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(item.$1, color: brandOrange, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$3,
                    style: const TextStyle(
                      fontSize: 10,
                      color: textGray,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 参考价格与报价 ──
  Widget _buildPriceSource() {
    const sources = [
      (Icons.folder_copy_outlined, '本地参考', '页面示例只用于了解计价结构，不代表当前服务端目录'),
      (Icons.straighten_outlined, '现场工程量', '师傅上门测量后填写实际数量和施工说明'),
      (Icons.receipt_long_outlined, '明细留痕', '项目、单价、数量和小计随报价清单保存'),
      (Icons.how_to_reg_outlined, '业主确认', '最终选人前由业主核对师傅、报价明细和总价'),
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
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: brandOrange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '参考价格与报价',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                ),
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
                            Text(
                              item.$2,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.$3,
                              style: const TextStyle(
                                fontSize: 13,
                                color: textGray,
                                height: 1.4,
                              ),
                            ),
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
              '页面参考信息用于提前了解计价结构；最终以师傅提交的服务器报价清单和现场工程量为准。',
              style: TextStyle(fontSize: 12, color: textGray, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflow() {
    const steps = [
      (
        '查看师傅',
        '按工种查看\n服务器资料',
        Icons.person_add_alt_1,
        'assets/images/worker_confident.png',
      ),
      (
        '上门测量',
        '师傅现场勘测\n确认工程量',
        Icons.straighten,
        'assets/images/trades/masonry_banner.jpg',
      ),
      (
        '提交报价',
        '按服务器项目\n生成明细清单',
        Icons.price_check,
        'assets/images/trades/carpentry_banner.jpg',
      ),
      (
        '确认选择',
        '只选师傅报价\n不发起付款',
        Icons.handshake,
        'assets/images/trades/installation_banner.jpg',
      ),
      (
        '施工验收',
        '日报与结果\n按订单留痕',
        Icons.task_alt,
        'assets/images/trades/painting_banner.jpg',
      ),
      (
        '线下付款',
        '提交付款信息\n等待人工确认',
        Icons.payments_outlined,
        'assets/images/trades/cleaning_banner.jpg',
      ),
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
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: brandOrange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '报价流程',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                ),
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
                          decoration: BoxDecoration(
                            color: brandOrange,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              '${e.key + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: brandOrange.withValues(alpha: 0.2),
                            ),
                          ),
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
                              child: Icon(
                                step.$3,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.$1,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    step.$2,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                      height: 1.4,
                                    ),
                                  ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('立即找师傅'),
          ),
        ),
      ),
    );
  }
}
