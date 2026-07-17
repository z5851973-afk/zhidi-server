import 'package:flutter/material.dart';
import '../../data/price_standards.dart';
import 'construction_project_detail_page.dart';
import 'price_detail_page.dart';
import 'tile_laying_detail_page.dart';

/// 项目列表页 — 某个分类下所有项目的价格列表
/// 通过 [tradeName] + [category] 参数化

class PriceItemListPage extends StatelessWidget {
  final String tradeName;
  final PriceCategory category;

  const PriceItemListPage({
    super.key,
    required this.tradeName,
    required this.category,
  });

  static const Color brandOrange = Color(0xFFFF7A2F);
  static const Color textDark = Color(0xFF333333);
  static const Color textGray = Color(0xFF808080);

  bool get _usesTileLayingStandardPage =>
      tradeName == '泥瓦' && category.name == '地砖铺贴';

  bool get _usesWallDemolitionProjectPage =>
      tradeName == '拆除' && category.name == '墙体拆除';

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
        title: Text(
          category.name,
          style: const TextStyle(
            color: textDark,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 顶部施工 Banner ──
            _buildBanner(),

            const SizedBox(height: 8),

            // ── 项目列表 ──
            _buildProjectList(context),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            brandOrange.withValues(alpha: 0.08),
            brandOrange.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: brandOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(category.icon, color: brandOrange, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.description,
                    style: const TextStyle(fontSize: 13, color: textGray),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: brandOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${category.projectCount}项',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: category.projects.asMap().entries.map((entry) {
          final index = entry.key;
          final project = entry.value;
          final isLast = index == category.projects.length - 1;

          return GestureDetector(
            onTap: () {
              if (_usesWallDemolitionProjectPage) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ConstructionProjectDetailPage.wallDemolition(),
                  ),
                );
                return;
              }

              if (_usesTileLayingStandardPage) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TileLayingDetailPage(),
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PriceDetailPage(
                    tradeName: tradeName,
                    categoryName: category.name,
                    project: project,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(
                          color: Color(0xFFF0F0F0),
                          width: 0.5,
                        ),
                      ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              child: Row(
                children: [
                  // 左侧序号
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: textGray,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // 项目名
                  Expanded(
                    child: Text(
                      project.name,
                      style: const TextStyle(
                        fontSize: 15,
                        color: textDark,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  // 价格
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: project.price,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: brandOrange,
                          ),
                        ),
                        TextSpan(
                          text: project.unit,
                          style: const TextStyle(fontSize: 13, color: textGray),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Color(0xFFCCCCCC),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
