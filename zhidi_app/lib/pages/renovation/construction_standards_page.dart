import 'package:flutter/material.dart';
import '../../design/tokens.dart';

// ── 颜色常量（复用 worker_detail_page.dart 体系）──
const _primary = ZdColors.primary;
const _primaryBg = ZdColors.cardBg;
const _textDark = ZdColors.textPrimary;
const _textMid = Color(0xFF666666);
const _textLight = ZdColors.textSecondary;
const _pageBg = ZdColors.background;
const _green = Color(0xFF4CAF50);
const _greenBg = Color(0xFFE8F5E9);

class ConstructionStandardsPage extends StatelessWidget {
  const ConstructionStandardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: 0,
      child: Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: _textDark, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            '施工标准',
            style: TextStyle(color: _textDark, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(24),
            child: Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '知底平台施工标准 · 透明规范 · 安心托付',
                style: TextStyle(fontSize: 13, color: _textLight),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Sticky TabBar
            Container(
              color: Colors.white,
              child: TabBar(
                labelColor: _primary,
                unselectedLabelColor: _textLight,
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(color: _primary, width: 2),
                  insets: EdgeInsets.symmetric(horizontal: 16),
                ),
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: '安全规范'),
                  Tab(text: '工艺标准'),
                  Tab(text: '材料标准'),
                  Tab(text: '验收标准'),
                ],
              ),
            ),
            // Content
            Expanded(
              child: TabBarView(
                children: [
                  _buildSafetyTab(),
                  _buildCraftTab(),
                  _buildMaterialTab(),
                  _buildAcceptanceTab(),
                ],
              ),
            ),
            // Bottom fixed bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ── 底部固定栏 ──
  Widget _buildBottomBar() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '平台承诺：严格执行施工标准，全程监管，如不达标平台负责整改或赔付',
              style: TextStyle(fontSize: 13, color: _primary, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            const Text(
              '知底平台保障您的装修品质与权益',
              style: TextStyle(fontSize: 11, color: _textLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab1: 安全规范 ──
  Widget _buildSafetyTab() {
    final items = [
      _SafetyItem(Icons.health_and_safety, '人员安全', '配备安全帽/防护装备，持证上岗'),
      _SafetyItem(Icons.bolt, '用电安全', '规范用电线路布置，杜绝安全隐患'),
      _SafetyItem(Icons.fire_extinguisher, '消防安全', '现场配备灭火器材，禁止明火'),
      _SafetyItem(Icons.shield, '现场保护', '地面/墙面/家具全面保护覆盖'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: _primaryBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: _primary, size: 26),
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textDark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  item.desc,
                  style: const TextStyle(fontSize: 12, color: _textLight),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Tab2: 工艺标准 ──
  Widget _buildCraftTab() {
    final items = [
      _CraftItem('01', '水电工程', '强弱电分离，水管走顶，打压测试'),
      _CraftItem('02', '防水工程', '卫生间三遍防水，48小时闭水试验'),
      _CraftItem('03', '泥瓦工程', '墙面找平，瓷砖薄贴，空鼓率＜3%'),
      _CraftItem('04', '木工工程', '轻钢龙骨吊顶，防潮处理，收口精细'),
      _CraftItem('05', '油漆工程', '三底两面，环保涂料，无裂缝起皮'),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Left thumbnail placeholder
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image, color: _textLight, size: 24),
              ),
              const SizedBox(width: 12),
              // Right content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _primaryBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.number,
                            style: const TextStyle(fontSize: 11, color: _primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.desc,
                      style: const TextStyle(fontSize: 12, color: _textLight),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab3: 材料标准 ──
  Widget _buildMaterialTab() {
    final items = [
      _MaterialItem(Icons.eco_outlined, '环保合格', '所有材料符合国家环保标准E1/E0级'),
      _MaterialItem(Icons.verified_outlined, '品牌保障', '合作品牌均为平台严选，正品溯源'),
      _MaterialItem(Icons.fact_check_outlined, '材料验收', '进场材料须经业主确认后方可使用'),
      _MaterialItem(Icons.qr_code_scanner_outlined, '可追溯', '每批材料提供质检报告，全程可查'),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: _greenBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: _green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.desc,
                      style: const TextStyle(fontSize: 13, color: _textMid),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab4: 验收标准 ──
  Widget _buildAcceptanceTab() {
    final items = [
      _AcceptanceItem('尺寸规范', '墙面垂直偏差≤3mm，地面水平偏差≤2mm'),
      _AcceptanceItem('表面平整', '瓷砖表面平整度偏差≤2mm，接缝高低差≤0.5mm'),
      _AcceptanceItem('功能验收', '水电通畅，开关插座功能正常，无漏电隐患'),
      _AcceptanceItem('细节检查', '阴阳角顺直，收口严密，无裂缝空鼓'),
      _AcceptanceItem('整体验收', '所有项目达标后，双方签字确认验收合格'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.check_circle, color: _green, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.desc,
                          style: const TextStyle(fontSize: 13, color: _textMid),
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
    );
  }
}

// ── 数据模型 ──
class _SafetyItem {
  final IconData icon;
  final String title;
  final String desc;
  const _SafetyItem(this.icon, this.title, this.desc);
}

class _CraftItem {
  final String number;
  final String title;
  final String desc;
  const _CraftItem(this.number, this.title, this.desc);
}

class _MaterialItem {
  final IconData icon;
  final String title;
  final String desc;
  const _MaterialItem(this.icon, this.title, this.desc);
}

class _AcceptanceItem {
  final String title;
  final String desc;
  const _AcceptanceItem(this.title, this.desc);
}
