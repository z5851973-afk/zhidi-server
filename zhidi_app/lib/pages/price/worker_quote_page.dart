import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';
import '../../data/price_standards.dart';

/// 师傅报价清单页（业主查看）
/// 展示师傅已填好的项目-单价-数量-小计-合计报价单，纯只读
/// 逻辑：如果工种是"拆除"则只显示人工部分，否则显示人工+辅料+主材（如果有）

class WorkerQuotePage extends StatefulWidget {
  final String workerName;
  final TradePriceData trade;

  const WorkerQuotePage({super.key, required this.workerName, required this.trade});

  @override
  State<WorkerQuotePage> createState() => _WorkerQuotePageState();
}

class _WorkerQuotePageState extends State<WorkerQuotePage> {
  static const _primary = Color(0xFFFF5A00);
  static const _bg = Color(0xFFF8F6F3);

  static double _parsePrice(String p) => double.tryParse(p.replaceFirst('¥', '')) ?? 0;

  /// 模拟数据：师傅报的数量（按项目名返回）
  static double _mockQty(int index, String unit) {
    final qtys = [28.0, 12.0, 5.0, 36.0, 2.0, 4.0, 1.0, 3.0, 15.0, 8.0, 22.0, 6.0, 7.0, 10.0];
    return qtys[index % qtys.length];
  }

  /// 模拟数据：辅料项目（仅当 tradeName != "拆除" 时显示）
  static final _mockMaterialCategories = [
    PriceCategory(
      name: '辅料',
      icon: Icons.inventory,
      description: '电线、管材、胶带等',
      projects: [
        PriceProject(name: '正泰 2.5mm²铜芯电线', price: '¥185', unit: '/卷'),
        PriceProject(name: '正泰 4mm²铜芯电线', price: '¥310', unit: '/卷'),
        PriceProject(name: '联塑 PVC线管', price: '¥9', unit: '/根'),
        PriceProject(name: '公牛 暗装底盒', price: '¥5', unit: '/个'),
        PriceProject(name: '3M 防水胶带', price: '¥12', unit: '/卷'),
      ],
    ),
    PriceCategory(
      name: '主材',
      icon: Icons.hardware,
      description: '开关、面板、灯具等',
      projects: [
        PriceProject(name: '施耐德 断路器/空开', price: '¥85', unit: '/个'),
        PriceProject(name: '西门子 五孔插座', price: '¥28', unit: '/个'),
        PriceProject(name: '欧普 LED筒灯', price: '¥45', unit: '/个'),
        PriceProject(name: '雷士 吸顶灯', price: '¥180', unit: '/套'),
      ],
    ),
  ];

  double _grandTotal(List<PriceProject> allProjects) {
    double t = 0;
    int i = 0;
    for (final p in allProjects) {
      t += _parsePrice(p.price) * _mockQty(i, p.unit);
      i++;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final allProjects = <PriceProject>[];
    for (final cat in widget.trade.categories) {
      allProjects.addAll(cat.projects);
    }
    final laborTotal = _grandTotal(allProjects);

    final showMaterial = widget.trade.tradeName != '拆除';
    final materialProjects = <PriceProject>[];
    if (showMaterial) {
      for (final cat in _mockMaterialCategories) {
        materialProjects.addAll(cat.projects);
      }
    }
    final double materialTotal = showMaterial ? _grandTotal(materialProjects) : 0;
    final double grandTotal = laborTotal + materialTotal;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${widget.workerName}的报价清单', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ===== 人工部分（必显） =====
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('项目', style: TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500))),
                        SizedBox(width: 8),
                        SizedBox(width: 56, child: Text('单价', style: TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
                        SizedBox(width: 8),
                        SizedBox(width: 56, child: Text('数量', style: TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
                        SizedBox(width: 8),
                        SizedBox(width: 72, child: Text('小计', style: TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._buildCategories(allProjects, widget.trade.categories),

                  // ===== 辅料/主材（非拆除工种显示） =====
                  if (showMaterial) ...[
                    const SizedBox(height: 24),
                    ..._buildCategories(materialProjects, _mockMaterialCategories),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // 底部合计
          _buildBottomBar(context, laborTotal, materialTotal, grandTotal, showMaterial),
        ],
      ),
    );
  }

  List<Widget> _buildCategories(List<PriceProject> allProjects, List<PriceCategory> categories) {
    int globalIdx = 0;
    final widgets = <Widget>[];
    for (final cat in categories) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(cat.icon, size: 16, color: _primary),
              const SizedBox(width: 6),
              Text(cat.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text(cat.description, style: const TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
        ),
      );
      widgets.add(
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: cat.projects.map((p) {
              final idx = globalIdx++;
              return _ProjectRow(project: p, qty: _mockQty(idx, p.unit));
            }).toList(),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildBottomBar(BuildContext context, double laborTotal, double materialTotal, double grandTotal, bool showMaterial) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 人工合计行
            Row(
              children: [
                const Text('人工合计', style: TextStyle(fontSize: 12, color: Colors.black45)),
                const Spacer(),
                Text('¥${laborTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _primary)),
              ],
            ),
            // 辅料/主材合计行（非拆除时显示）
            if (showMaterial && materialTotal > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('辅料主材合计', style: TextStyle(fontSize: 12, color: Colors.black45)),
                  const Spacer(),
                  Text('¥${materialTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                ],
              ),
            ],
            // 总计行
            const SizedBox(height: 8),
            const Divider(height: 1, color: Colors.grey),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('总计', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
                const Spacer(),
                Text('¥${grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _primary)),
              ],
            ),
            const SizedBox(height: 12),
            // 按钮行
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        elevation: 0,
                      ),
                      child: const Text('返回', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        final allProjects = <PriceProject>[];
                        for (final cat in widget.trade.categories) {
                          allProjects.addAll(cat.projects);
                        }
                        final items = <QuoteLineItem>[];
                        int i = 0;
                        for (final cat in widget.trade.categories) {
                          for (final p in cat.projects) {
                            final qty = _mockQty(i, p.unit);
                            items.add(QuoteLineItem(
                              name: p.name,
                              categoryName: cat.name,
                              unitPrice: _parsePrice(p.price),
                              unit: p.unit,
                              quantity: qty,
                            ));
                            i++;
                          }
                        }
                        final grandTotal = items.fold<double>(0, (sum, it) => sum + it.subtotal);
                        final now = DateTime.now();
                        final quote = SavedQuote(
                          id: 'sq-${now.millisecondsSinceEpoch}',
                          workerName: widget.workerName,
                          tradeName: widget.trade.tradeName,
                          items: items,
                          grandTotal: grandTotal,
                          savedAt: now,
                        );
                        OwnerAppScope.of(context).addSavedQuote(quote);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已收藏，可在"我的收藏"页面查看')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF666666),
                        side: const BorderSide(color: Color(0xFFCCCCCC)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        elevation: 0,
                      ),
                      child: const Text('价高再考虑', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                if (showMaterial) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已为您生成辅料主材采购清单')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          elevation: 0,
                        ),
                        child: const Text('生成采购清单', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final PriceProject project;
  final double qty;

  const _ProjectRow({required this.project, required this.qty});

  static double _parsePrice(String p) => double.tryParse(p.replaceFirst('¥', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final price = _parsePrice(project.price);
    final subtotal = price * qty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100, width: 0.5))),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(project.unit, style: const TextStyle(fontSize: 11, color: Colors.black45)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 56, child: Text(project.price, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333)), textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          SizedBox(width: 56, child: Text(qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1), style: const TextStyle(fontSize: 13, color: Color(0xFF333333)), textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          SizedBox(width: 72, child: Text('¥${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFFF5A00)), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
