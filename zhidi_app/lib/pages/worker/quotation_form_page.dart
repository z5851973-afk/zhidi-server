import 'package:flutter/material.dart';

import '../../app/worker_app_scope.dart';
import '../../app/worker_app_state.dart';
import '../../services/service_catalog_api_client.dart';
import '../../services/worker_quote_api_client.dart';
import '../../services/auth_api_client.dart';

class QuotationFormPage extends StatefulWidget {
  const QuotationFormPage({super.key, required this.order});

  final WorkerOrder order;

  @override
  State<QuotationFormPage> createState() => _QuotationFormPageState();
}

class _QuotationFormPageState extends State<QuotationFormPage> {
  List<CatalogItem>? _catalog;
  bool _loading = true;
  String? _error;

  /// 选中的项：key = catalog item name
  final Map<String, double> _quantities = {};

  // 中文分类映射
  static final _catLabel = <String, String>{
    'PLUMBING': '水电',
    'ELECTRICAL': '水电',
    'CARPENTRY': '木工',
    'PAINTING': '油漆',
    'MASONRY': '泥瓦',
    'DEMOLITION': '拆除',
  };

  // 分类图标/颜色
  static const _catMeta = <String, _CatMeta>{
    'PLUMBING': _CatMeta(Icons.water_drop_outlined, Colors.blue),
    'ELECTRICAL': _CatMeta(Icons.bolt_outlined, Colors.amber),
    'CARPENTRY': _CatMeta(Icons.carpenter_outlined, Colors.brown),
    'PAINTING': _CatMeta(Icons.format_paint_outlined, Colors.teal),
    'MASONRY': _CatMeta(Icons.grid_view_outlined, Colors.orange),
    'DEMOLITION': _CatMeta(Icons.delete_outline, Colors.red),
  };

  WorkerOrder get _order => widget.order;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final app = WorkerAppScope.of(context);
    final token = app.accessToken;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = '未登录';
      });
      return;
    }
    try {
      final api = ServiceCatalogApiClient();
      final items = await api.getCatalog(token, _order.trade);
      setState(() {
        _catalog = items;
        _loading = false;
      });
    } on AuthApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '加载价格目录失败：$e';
      });
    }
  }

  // 按 category 分组
  Map<String, List<CatalogItem>> _grouped() {
    final map = <String, List<CatalogItem>>{};
    if (_catalog == null) return map;
    for (final item in _catalog!) {
      map.putIfAbsent(item.category, () => []).add(item);
    }
    return map;
  }

  double _quantityOf(String name) => _quantities[name] ?? 0;

  double get _grandTotal {
    if (_catalog == null) return 0;
    double total = 0;
    for (final item in _catalog!) {
      final qty = _quantityOf(item.name);
      if (qty > 0) total += item.unitPrice * qty;
    }
    return total;
  }

  bool get _hasSelection => _quantities.values.any((q) => q > 0);

  Future<void> _submit() async {
    if (_catalog == null || !_hasSelection) return;

    final items = <CatalogSubmitItem>[];
    for (final item in _catalog!) {
      final qty = _quantityOf(item.name);
      if (qty > 0) {
        items.add(CatalogSubmitItem(name: item.name, quantity: qty));
      }
    }
    if (items.isEmpty) return;

    try {
      final app = WorkerAppScope.of(context);
      await app.submitQuote(_order.id, items);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('报价已提交')),
      );
      Navigator.of(context).pop();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: _buildBody(cs),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _hasSelection ? _submit : null,
            icon: const Icon(Icons.send),
            label: Text(
              _hasSelection
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

  Widget _buildBody(ColorScheme cs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: cs.error)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadCatalog();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final grouped = _grouped();
    if (grouped.isEmpty) {
      return Center(
        child: Text(
          '该工种暂无价格项目',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: grouped.entries.map((e) {
        final meta = _catMeta[e.key] ?? _CatMeta(Icons.build_outlined, cs.primary);
        return _CategoryCard(
          label: _catLabel[e.key] ?? e.key,
          icon: meta.icon,
          color: meta.color,
          items: e.value,
          quantityOf: _quantityOf,
          onQtyChanged: _setQty,
        );
      }).toList(),
    );
  }

  void _setQty(String name, double qty) {
    setState(() {
      if (qty <= 0) {
        _quantities.remove(name);
      } else {
        _quantities[name] = qty;
      }
    });
  }
}

class _CatMeta {
  const _CatMeta(this.icon, this.color);
  final IconData icon;
  final Color color;
}

// ── 分类卡片 ──
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.items,
    required this.quantityOf,
    required this.onQtyChanged,
  });

  final String label;
  final IconData icon;
  final Color color;
  final List<CatalogItem> items;
  final double Function(String) quantityOf;
  final void Function(String, double) onQtyChanged;

  double get _catTotal {
    double t = 0;
    for (final item in items) {
      final q = quantityOf(item.name);
      if (q > 0) t += item.unitPrice * q;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                Text(label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('小计 ¥${_catTotal.toStringAsFixed(0)}',
                    style: TextStyle(color: cs.primary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            ...items.map((item) => _CatalogItemRow(
                  item: item,
                  quantity: quantityOf(item.name),
                  onQtyChanged: (q) => onQtyChanged(item.name, q),
                )),
          ],
        ),
      ),
    );
  }
}

// ── 单行目录项 ──
class _CatalogItemRow extends StatelessWidget {
  const _CatalogItemRow({
    required this.item,
    required this.quantity,
    required this.onQtyChanged,
  });

  final CatalogItem item;
  final double quantity;
  final ValueChanged<double> onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = quantity > 0;
    final subtotal = item.unitPrice * quantity;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? cs.primaryContainer.withValues(alpha: 0.15)
            : cs.surface,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onQtyChanged(selected ? 0 : 1),
          borderRadius: BorderRadius.circular(8),
          splashColor: cs.primary.withValues(alpha: 0.2),
          highlightColor: cs.primary.withValues(alpha: 0.1),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: selected
                    ? cs.primary.withValues(alpha: 0.4)
                    : cs.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: selected,
                          onChanged: (_) =>
                              onQtyChanged(selected ? 0 : 1),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: selected ? cs.onSurface : cs.outline,
                            fontWeight: selected
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '¥${item.unitPrice.toStringAsFixed(0)}/${item.unit}',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (selected) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 32),
                        Expanded(
                          flex: 2,
                          child: _QtyStepper(
                            value: quantity,
                            onChanged: onQtyChanged,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '¥${subtotal.toStringAsFixed(0)}',
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
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500),
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
