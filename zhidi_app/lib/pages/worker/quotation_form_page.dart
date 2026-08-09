import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/worker_app_scope.dart';
import '../../app/worker_app_state.dart';
import '../../services/service_catalog_api_client.dart';
import '../../services/worker_quote_api_client.dart';
import '../../services/auth_api_client.dart';

class QuotationFormPage extends StatefulWidget {
  const QuotationFormPage({super.key, required this.order, this.catalogApi});

  final WorkerOrder order;
  final ServiceCatalogApi? catalogApi;

  @override
  State<QuotationFormPage> createState() => _QuotationFormPageState();
}

class _QuotationFormPageState extends State<QuotationFormPage> {
  List<CatalogItem>? _catalog;
  bool _loading = true;
  String? _error;
  bool _catalogLoadStarted = false;

  /// 选中的项：key = catalog item name
  final Map<String, double> _quantities = {};
  final Set<String> _selectedItems = {};

  WorkerOrder get _order => widget.order;

  ServiceCatalogApi get _catalogApi =>
      widget.catalogApi ?? ServiceCatalogApiClient();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startCatalogLoad();
  }

  void _startCatalogLoad() {
    if (_catalogLoadStarted) return;
    _catalogLoadStarted = true;
    _loadCatalog();
  }

  @override
  void didUpdateWidget(covariant QuotationFormPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id == widget.order.id &&
        oldWidget.order.trade == widget.order.trade) {
      return;
    }
    _selectedItems.clear();
    _quantities.clear();
    _catalog = null;
    _loading = true;
    _error = null;
    _catalogLoadStarted = false;
    _startCatalogLoad();
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
    final orderId = _order.id;
    final trade = _order.trade;
    try {
      final items = await _catalogApi.getCatalog(token, trade);
      if (!mounted || _order.id != orderId || _order.trade != trade) return;
      setState(() {
        _catalog = items;
        _loading = false;
      });
    } on AuthApiException catch (e) {
      if (!mounted || _order.id != orderId || _order.trade != trade) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted || _order.id != orderId || _order.trade != trade) return;
      setState(() {
        _loading = false;
        _error = '加载价格目录失败：$e';
      });
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('报价已提交')));
      Navigator.of(context).pop();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('提交失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('提交报价单'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Container(
            color: cs.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_order.ownerName} - ${_order.requirement}',
                        style: TextStyle(color: cs.onSurface, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
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
                Text(
                  _order.houseSummary,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '请按现场实际情况报价',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    final laborItems = _catalog!.where((item) => !item.isMaterial).toList();
    final materialItems = _catalog!.where((item) => item.isMaterial).toList();
    if (laborItems.isEmpty && materialItems.isEmpty) {
      return Center(
        child: Text('该工种暂无价格项目', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        if (laborItems.isNotEmpty)
          _CategoryCard(
            label: '人工费用',
            icon: Icons.engineering_outlined,
            color: cs.primary,
            items: laborItems,
            selectedOf: _selectedItems.contains,
            quantityOf: _quantityOf,
            onSelectionChanged: _setSelected,
            onQtyChanged: _setQty,
          ),
        if (materialItems.isNotEmpty)
          _CategoryCard(
            label: '材料费用',
            icon: Icons.inventory_2_outlined,
            color: Colors.brown,
            items: materialItems,
            selectedOf: _selectedItems.contains,
            quantityOf: _quantityOf,
            onSelectionChanged: _setSelected,
            onQtyChanged: _setQty,
          ),
      ],
    );
  }

  void _setQty(String name, double qty) {
    setState(() {
      _quantities[name] = qty < 0 ? 0 : qty;
    });
  }

  void _setSelected(String name, bool selected) {
    setState(() {
      if (selected) {
        _selectedItems.add(name);
        _quantities[name] = 1;
      } else {
        _selectedItems.remove(name);
        _quantities.remove(name);
      }
    });
  }
}

// ── 分类卡片 ──
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.items,
    required this.selectedOf,
    required this.quantityOf,
    required this.onSelectionChanged,
    required this.onQtyChanged,
  });

  final String label;
  final IconData icon;
  final Color color;
  final List<CatalogItem> items;
  final bool Function(String) selectedOf;
  final double Function(String) quantityOf;
  final void Function(String, bool) onSelectionChanged;
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
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '小计 ¥${_catTotal.toStringAsFixed(0)}',
                  style: TextStyle(color: cs.primary, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => _CatalogItemRow(
                item: item,
                selected: selectedOf(item.name),
                quantity: quantityOf(item.name),
                onSelectionChanged: (selected) =>
                    onSelectionChanged(item.name, selected),
                onQtyChanged: (q) => onQtyChanged(item.name, q),
              ),
            ),
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
    required this.selected,
    required this.quantity,
    required this.onSelectionChanged,
    required this.onQtyChanged,
  });

  final CatalogItem item;
  final bool selected;
  final double quantity;
  final ValueChanged<bool> onSelectionChanged;
  final ValueChanged<double> onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          onTap: () => onSelectionChanged(!selected),
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
                          onChanged: (checked) =>
                              onSelectionChanged(checked == true),
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
                          horizontal: 8,
                          vertical: 3,
                        ),
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
                            itemName: item.name,
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
class _QtyStepper extends StatefulWidget {
  const _QtyStepper({
    required this.itemName,
    required this.value,
    required this.onChanged,
  });

  final String itemName;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_QtyStepper> createState() => _QtyStepperState();
}

class _QtyStepperState extends State<_QtyStepper> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatQuantity(widget.value));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _QtyStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _replaceText(_formatQuantity(widget.value));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  static String _formatQuantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  void _replaceText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _setFromButton(double value) {
    _replaceText(_formatQuantity(value));
    widget.onChanged(value);
  }

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
            if (widget.value > 0.5) _setFromButton(widget.value - 1);
          }),
          SizedBox(
            width: 64,
            child: TextFormField(
              key: ValueKey('quote-qty-${widget.itemName}'),
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (text) => widget.onChanged(double.tryParse(text) ?? 0),
            ),
          ),
          _stepBtn(Icons.add, () => _setFromButton(widget.value + 1)),
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
