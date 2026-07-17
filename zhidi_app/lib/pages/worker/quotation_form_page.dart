import 'package:flutter/material.dart';

import '../../app/worker_app_scope.dart';
import '../../app/worker_app_state.dart';
import '../../app/quotation_templates.dart';

/// 带全局 index 的模版项（解决分组后 index 错位）
class _IndexedTemplate {
  const _IndexedTemplate(this.index, this.item);
  final int index;
  final QuotationTemplateItem item;
}

class QuotationFormPage extends StatefulWidget {
  const QuotationFormPage({super.key, required this.order});

  final WorkerOrder order;

  @override
  State<QuotationFormPage> createState() => _QuotationFormPageState();
}

class _QuotationFormPageState extends State<QuotationFormPage> {
  late final List<QuotationTemplateItem> _templates;

  /// 选中的项：key = 全局 template index
  final Map<int, _Selection> _selections = {};

  WorkerOrder get _order => widget.order;

  @override
  void initState() {
    super.initState();
    _templates = quotationTemplateForTrade(_order.trade);
  }

  // ── 按 category → phase → [_IndexedTemplate] ──
  Map<String, List<_IndexedTemplate>> _phasesOf(QuotationItemCategory cat) {
    final map = <String, List<_IndexedTemplate>>{};
    for (var i = 0; i < _templates.length; i++) {
      final t = _templates[i];
      if (t.category != cat) continue;
      final phase = t.phase.isEmpty ? '通用' : t.phase;
      map.putIfAbsent(phase, () => []).add(_IndexedTemplate(i, t));
    }
    return map;
  }

  // ── 是否勾选 ──
  bool _isSelected(int idx) => _selections.containsKey(idx);

  _Selection _sel(int idx) =>
      _selections[idx] ?? _Selection(quantity: 1, specIndex: 0);

  // ── 汇总 ──
  double _categoryTotal(QuotationItemCategory cat) {
    double total = 0;
    for (var i = 0; i < _templates.length; i++) {
      if (_templates[i].category == cat && _isSelected(i)) {
        total += _templates[i].unitPrice * _sel(i).quantity;
      }
    }
    return total;
  }

  double get _grandTotal =>
      _categoryTotal(QuotationItemCategory.labor) +
      _categoryTotal(QuotationItemCategory.auxiliary) +
      _categoryTotal(QuotationItemCategory.mainMaterial);

  // ── 提交 ──
  List<QuotationItem> _buildItems() {
    final items = <QuotationItem>[];
    for (var i = 0; i < _templates.length; i++) {
      if (!_isSelected(i)) continue;
      final t = _templates[i];
      final s = _sel(i);
      String spec = '';
      if (t.specs.isNotEmpty && s.specIndex < t.specs.length) {
        spec = t.specs[s.specIndex];
      }
      items.add(QuotationItem(
        name: t.name,
        category: t.category,
        spec: spec,
        unitPrice: t.unitPrice,
        quantity: s.quantity,
        unit: t.unit,
      ));
    }
    return items;
  }

  Future<void> _submit(WorkerAppState app) async {
    final items = _buildItems();
    if (items.isEmpty) return;

    final now = DateTime.now();
    final quotation = Quotation(
      id: 'qt-${now.millisecondsSinceEpoch}',
      orderId: _order.id,
      items: items,
      createdAt: now,
    );

    await app.submitQuotation(quotation);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('报价单已提交')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = WorkerAppScope.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('提交报价单'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: cs.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_order.ownerName} - ${_order.requirement}',
                    style: TextStyle(color: cs.onSurface, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '合计 ¥${_grandTotal.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          _CategorySection(
            title: '人工费',
            icon: Icons.person_outline,
            color: Colors.indigo,
            phases: _phasesOf(QuotationItemCategory.labor),
            isSelected: _isSelected,
            sel: _sel,
            onToggle: _toggle,
            onQtyChanged: _setQty,
            onSpecChanged: _setSpec,
          ),
          _CategorySection(
            title: '辅料',
            icon: Icons.build_outlined,
            color: Colors.amber.shade700,
            phases: _phasesOf(QuotationItemCategory.auxiliary),
            isSelected: _isSelected,
            sel: _sel,
            onToggle: _toggle,
            onQtyChanged: _setQty,
            onSpecChanged: _setSpec,
          ),
          _CategorySection(
            title: '主材',
            icon: Icons.construction_outlined,
            color: Colors.teal,
            phases: _phasesOf(QuotationItemCategory.mainMaterial),
            isSelected: _isSelected,
            sel: _sel,
            onToggle: _toggle,
            onQtyChanged: _setQty,
            onSpecChanged: _setSpec,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _selections.isNotEmpty
                ? () => _submit(app)
                : null,
            icon: const Icon(Icons.send),
            label: Text(
              _selections.isNotEmpty
                  ? '提交报价单（¥${_grandTotal.toStringAsFixed(0)}）'
                  : '请勾选报价项目',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
      ),
    );
  }

  // ── 操作 ──
  void _toggle(int idx) {
    setState(() {
      if (_selections.containsKey(idx)) {
        _selections.remove(idx);
      } else {
        _selections[idx] = _Selection(quantity: 1, specIndex: 0);
      }
    });
  }

  void _setQty(int idx, double qty) {
    setState(() {
      _selections[idx] = _sel(idx).copyWith(quantity: qty);
    });
  }

  void _setSpec(int idx, int specIndex) {
    setState(() {
      _selections[idx] = _sel(idx).copyWith(specIndex: specIndex);
    });
  }
}

// ── 选中状态 ──
class _Selection {
  const _Selection({required this.quantity, required this.specIndex});
  final double quantity;
  final int specIndex;

  _Selection copyWith({double? quantity, int? specIndex}) => _Selection(
        quantity: quantity ?? this.quantity,
        specIndex: specIndex ?? this.specIndex,
      );
}

// ═══════════════════════════════════════════
// 大分类区块
// ═══════════════════════════════════════════
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.icon,
    required this.color,
    required this.phases,
    required this.isSelected,
    required this.sel,
    required this.onToggle,
    required this.onQtyChanged,
    required this.onSpecChanged,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Map<String, List<_IndexedTemplate>> phases;
  final bool Function(int) isSelected;
  final _Selection Function(int) sel;
  final void Function(int) onToggle;
  final void Function(int, double) onQtyChanged;
  final void Function(int, int) onSpecChanged;

  @override
  Widget build(BuildContext context) {
    if (phases.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final catTotal = _calcTotal();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('小计 ¥${catTotal.toStringAsFixed(0)}',
                    style: TextStyle(color: cs.primary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            ...phases.entries.map((e) => _PhaseGroup(
                  phaseName: e.key,
                  items: e.value,
                  isSelected: isSelected,
                  sel: sel,
                  onToggle: onToggle,
                  onQtyChanged: onQtyChanged,
                  onSpecChanged: onSpecChanged,
                )),
          ],
        ),
      ),
    );
  }

  double _calcTotal() {
    double t = 0;
    for (final list in phases.values) {
      for (final it in list) {
        if (isSelected(it.index)) {
          t += it.item.unitPrice * sel(it.index).quantity;
        }
      }
    }
    return t;
  }
}

// ═══════════════════════════════════════════
// 施工步骤分组
// ═══════════════════════════════════════════
class _PhaseGroup extends StatelessWidget {
  const _PhaseGroup({
    required this.phaseName,
    required this.items,
    required this.isSelected,
    required this.sel,
    required this.onToggle,
    required this.onQtyChanged,
    required this.onSpecChanged,
  });

  final String phaseName;
  final List<_IndexedTemplate> items;
  final bool Function(int) isSelected;
  final _Selection Function(int) sel;
  final void Function(int) onToggle;
  final void Function(int, double) onQtyChanged;
  final void Function(int, int) onSpecChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                phaseName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
        ...items.map((it) => _TemplateItemCard(
              index: it.index,
              item: it.item,
              isSelected: isSelected,
              sel: sel,
              onToggle: onToggle,
              onQtyChanged: onQtyChanged,
              onSpecChanged: onSpecChanged,
            )),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// 单条模版项卡片
// ═══════════════════════════════════════════
class _TemplateItemCard extends StatelessWidget {
  const _TemplateItemCard({
    required this.index,
    required this.item,
    required this.isSelected,
    required this.sel,
    required this.onToggle,
    required this.onQtyChanged,
    required this.onSpecChanged,
  });

  final int index;
  final QuotationTemplateItem item;
  final bool Function(int) isSelected;
  final _Selection Function(int) sel;
  final void Function(int) onToggle;
  final void Function(int, double) onQtyChanged;
  final void Function(int, int) onSpecChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final checked = isSelected(index);
    final selection = sel(index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: checked ? cs.primaryContainer.withValues(alpha: 0.15) : cs.surface,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onToggle(index),
          borderRadius: BorderRadius.circular(8),
          splashColor: cs.primary.withValues(alpha: 0.2),
          highlightColor: cs.primary.withValues(alpha: 0.1),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: checked ? cs.primary.withValues(alpha: 0.4) : cs.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              // ── 第一行：勾选 + 名称 + 单价 ──
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: checked,
                      onChanged: (_) => onToggle(index),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: checked ? cs.onSurface : cs.outline,
                        fontWeight:
                            checked ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    '¥${item.unitPrice.toStringAsFixed(0)}/${item.unit}',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              // ── 勾选后展开：规格选择 + 数量 ──
              if (checked) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 32),
                    // 规格选择
                    if (item.specs.isNotEmpty) ...[
                      Expanded(
                        flex: 3,
                        child: _SpecSelector(
                          specs: item.specs,
                          selectedIndex: selection.specIndex.clamp(
                              0, item.specs.length - 1),
                          onChanged: (i) => onSpecChanged(index, i),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // 数量输入
                    Expanded(
                      flex: item.specs.isEmpty ? 3 : 2,
                      child: _QtyStepper(
                        value: selection.quantity,
                        onChanged: (v) => onQtyChanged(index, v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 小计
                    Text(
                      '¥${(item.unitPrice * selection.quantity).toStringAsFixed(0)}',
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    ),
    );
  }
}

// ── 规格下拉 ──
class _SpecSelector extends StatelessWidget {
  const _SpecSelector({
    required this.specs,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> specs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: ValueKey(selectedIndex),
      initialValue: selectedIndex,
      decoration: const InputDecoration(
        labelText: '规格',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13),
      items: List.generate(
          specs.length,
          (i) => DropdownMenuItem(
              value: i, child: Text(specs[i], style: const TextStyle(fontSize: 13))),
        ),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ── 数量步进器 ──
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove, () {
            if (value > 0.5) onChanged(value - 1);
          }),
          Container(
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Text(
              value == value.roundToDouble()
                  ? value.toInt().toString()
                  : value.toStringAsFixed(1),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          _stepBtn(Icons.add, () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 16),
        ),
      );
}
