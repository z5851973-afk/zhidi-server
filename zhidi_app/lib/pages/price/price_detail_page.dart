import 'package:flutter/material.dart';
import '../../data/price_standards.dart';

/// 项目详情页 — 单个施工项目的详细信息
/// 通过 [tradeName] + [categoryName] + [project] 参数化

class PriceDetailPage extends StatelessWidget {
  final String tradeName;
  final String categoryName;
  final PriceProject project;

  const PriceDetailPage({
    super.key,
    required this.tradeName,
    required this.categoryName,
    required this.project,
  });

  static const Color brandOrange = Color(0xFFFF7A2F);
  static const Color textDark = Color(0xFF333333);
  static const Color textGray = Color(0xFF808080);
  static const Color bgLight = Color(0xFFF8F8F8);

  /// 根据项目名生成施工内容说明
  List<String> get _constructionContent {
    if (project.name.contains('拆除') || project.name.contains('破除') || project.name.contains('撕除')) {
      return ['现场保护及安全措施布置', '人工+专业工具拆除作业', '拆除后垃圾装袋并清运至指定点'];
    }
    if (project.name.contains('安装') || project.name.contains('铺贴') || project.name.contains('制作')) {
      return ['材料验收及预处理', '按标准工艺进行安装/铺贴', '完工后清洁及成品保护'];
    }
    if (project.name.contains('开槽') || project.name.contains('布线') || project.name.contains('改造')) {
      return ['定位弹线及开槽作业', '管线敷设及固定', '槽口填补及表面恢复'];
    }
    if (project.name.contains('腻子') || project.name.contains('乳胶漆') || project.name.contains('涂刷') || project.name.contains('打磨')) {
      return ['基层检查及局部修补', '按工艺标准分层施工', '表面打磨及清理'];
    }
    if (project.name.contains('保洁') || project.name.contains('清洗') || project.name.contains('清洁')) {
      return ['全屋除尘及地面清扫', '专业工具深度清洁', '垃圾集中清运'];
    }
    if (project.name.contains('防水')) {
      return ['基层清理及裂缝修补', '防水涂料分层涂刷', '闭水试验验证'];
    }
    if (project.name.contains('找平')) {
      return ['地面清理及标高定位', '材料搅拌及摊铺', '养护及平整度检测'];
    }
    return ['现场测量及方案确认', '按行业标准施工作业', '完工验收及现场清理'];
  }

  List<String> get _notIncluded {
    if (project.name.contains('拆除') || project.name.contains('破除')) {
      return ['不含垃圾外运（仅清运至楼下指定点）', '不含建筑垃圾消纳场处理费'];
    }
    return ['不含主材/辅材费用', '不含特殊工具租赁费'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '项目详情',
          style: TextStyle(color: textDark, fontSize: 17, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 顶部施工图示区域 ──
                  _buildHeroSection(),

                  // ── 项目名称 + 价格 ──
                  _buildPriceHeader(),

                  const SizedBox(height: 20),

                  // ── 项目说明 ──
                  _buildSectionContent(),

                  const SizedBox(height: 24),

                  // ── 施工流程 ──
                  _buildWorkflow(),

                  const SizedBox(height: 24),

                  // ── 平台保障 ──
                  _buildGuarantee(),

                  const SizedBox(height: 100), // 留出底部按钮空间
                ],
              ),
            ),
          ),

          // ── 底部预约按钮 ──
          _buildBottomButton(context),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            brandOrange.withValues(alpha: 0.12),
            brandOrange.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _getTradeIcon(),
          size: 72,
          color: brandOrange.withValues(alpha: 0.25),
        ),
      ),
    );
  }

  IconData _getTradeIcon() {
    switch (tradeName) {
      case '拆除':
        return Icons.handyman;
      case '水电':
        return Icons.water_drop;
      case '泥瓦':
        return Icons.format_paint;
      case '木工':
        return Icons.carpenter;
      case '油漆':
        return Icons.brush;
      case '安装':
        return Icons.build;
      case '保洁':
        return Icons.clean_hands;
      default:
        return Icons.home_repair_service;
    }
  }

  Widget _buildPriceHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 面包屑
          Text(
            '$tradeName工价 · $categoryName',
            style: const TextStyle(fontSize: 12, color: textGray),
          ),
          const SizedBox(height: 6),
          // 项目名
          Text(
            project.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: textDark),
          ),
          const SizedBox(height: 10),
          // 价格行
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                project.price,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: brandOrange),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  project.unit,
                  style: const TextStyle(fontSize: 16, color: textGray),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: brandOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '平台固定人工价格',
                  style: TextStyle(fontSize: 11, color: brandOrange, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bgLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 施工内容
            const Row(
              children: [
                Icon(Icons.check_circle, color: brandOrange, size: 18),
                SizedBox(width: 8),
                Text(
                  '施工内容',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._constructionContent.map((item) => Padding(
                  padding: const EdgeInsets.only(left: 26, bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('· ', style: TextStyle(fontSize: 14, color: textGray, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(item, style: const TextStyle(fontSize: 14, color: textDark, height: 1.5)),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE8E8E8)),
            const SizedBox(height: 12),

            // 不包含
            const Row(
              children: [
                Icon(Icons.cancel_outlined, color: textGray, size: 18),
                SizedBox(width: 8),
                Text(
                  '不包含',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._notIncluded.map((item) => Padding(
                  padding: const EdgeInsets.only(left: 26, bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('· ', style: TextStyle(fontSize: 14, color: textGray, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(item, style: const TextStyle(fontSize: 14, color: textGray, height: 1.5)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '施工流程',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textDark),
          ),
          const SizedBox(height: 14),
          ..._buildWorkflowSteps(),
        ],
      ),
    );
  }

  List<Widget> _buildWorkflowSteps() {
    const steps = [
      ('现场保护', '施工区域成品保护，铺设防护垫', Icons.shield),
      ('确认范围', '与业主确认施工范围及要求', Icons.rate_review),
      ('标准施工', '按照行业标准工艺进行施工', Icons.engineering),
      ('完工清理', '施工后清理现场，垃圾装袋', Icons.cleaning_services),
      ('验收交付', '业主验收确认，签字交付', Icons.task_alt),
    ];

    return steps.asMap().entries.map((entry) {
      final index = entry.key;
      final step = entry.value;
      final isLast = index == steps.length - 1;

      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧步骤指示器
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
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
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
            // 右侧内容
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.$1,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.$2,
                      style: const TextStyle(fontSize: 13, color: textGray, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildGuarantee() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '平台保障',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textDark),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildGuaranteeItem(Icons.verified, '工价统一', '平台统一定价\n杜绝随意加价')),
              const SizedBox(width: 10),
              Expanded(child: _buildGuaranteeItem(Icons.description, '标准施工', '规范施工流程\n质量有保障')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildGuaranteeItem(Icons.person_search, '师傅审核', '严选认证师傅\n持证上岗')),
              const SizedBox(width: 10),
              Expanded(child: _buildGuaranteeItem(Icons.assignment_turned_in, '验收保障', '完工验收\n不满意不付款')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuaranteeItem(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: brandOrange, size: 26),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: textGray, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context) {
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已预约「${project.name}」，师傅将尽快联系您'),
                  backgroundColor: brandOrange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: brandOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            child: const Text('立即预约'),
          ),
        ),
      ),
    );
  }
}
