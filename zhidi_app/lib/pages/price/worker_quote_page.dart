import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';
import '../../data/price_standards.dart';
import '../../design/tokens.dart';

class WorkerQuotePage extends StatefulWidget {
  const WorkerQuotePage({
    super.key,
    required this.workerName,
    required this.trade,
  });

  final String workerName;
  final TradePriceData trade;

  @override
  State<WorkerQuotePage> createState() => _WorkerQuotePageState();
}

class _WorkerQuotePageState extends State<WorkerQuotePage> {
  static double _parsePrice(String value) =>
      double.tryParse(value.replaceFirst('¥', '')) ?? 0;

  static double _mockQuantity(int index) {
    const quantities = [28.0, 12.0, 5.0, 36.0, 2.0, 4.0];
    return quantities[index % quantities.length];
  }

  List<QuoteLineItem> _quoteItems() {
    final items = <QuoteLineItem>[];
    var index = 0;
    for (final category in widget.trade.categories) {
      for (final project in category.projects) {
        items.add(
          QuoteLineItem(
            name: project.name,
            categoryName: category.name,
            unitPrice: _parsePrice(project.price),
            unit: project.unit,
            quantity: _mockQuantity(index),
          ),
        );
        index += 1;
      }
    }
    return items;
  }

  double _total(List<QuoteLineItem> items) =>
      items.fold<double>(0, (sum, item) => sum + item.subtotal);

  Future<void> _saveQuote(List<QuoteLineItem> items, double total) async {
    final now = DateTime.now();
    await OwnerAppScope.of(context).addSavedQuote(
      SavedQuote(
        id: 'sq-${now.millisecondsSinceEpoch}',
        workerName: widget.workerName,
        tradeName: widget.trade.tradeName,
        items: items,
        grandTotal: total,
        savedAt: now,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已收藏，可在"我的收藏"页面查看')));
  }

  @override
  Widget build(BuildContext context) {
    final items = _quoteItems();
    final total = _total(items);

    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: Text('${widget.workerName}的报价清单'),
        backgroundColor: Colors.white,
        foregroundColor: ZdColors.textPrimary,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final category in widget.trade.categories) ...[
                  _CategoryHeader(category: category),
                  const SizedBox(height: 8),
                  _QuoteItemsCard(
                    category: category,
                    items: items
                        .where((item) => item.categoryName == category.name)
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          _BottomQuoteBar(
            total: total,
            onBack: () => Navigator.pop(context),
            onSave: () => _saveQuote(items, total),
          ),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final PriceCategory category;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(category.icon, size: 16, color: ZdColors.primary),
        const SizedBox(width: 6),
        Text(
          category.name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            category.description,
            style: const TextStyle(fontSize: 12, color: ZdColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _QuoteItemsCard extends StatelessWidget {
  const _QuoteItemsCard({required this.category, required this.items});

  final PriceCategory category;
  final List<QuoteLineItem> items;

  String _quantityText(double quantity) => quantity == quantity.roundToDouble()
      ? quantity.toStringAsFixed(0)
      : quantity.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final item in items)
            ListTile(
              title: Text(item.name),
              subtitle: Text(
                '${item.unitPrice.toStringAsFixed(0)} 元${item.unit}',
              ),
              trailing: Text(
                '¥${item.subtotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: ZdColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              leading: CircleAvatar(
                backgroundColor: ZdColors.warningSoft,
                child: Text(_quantityText(item.quantity)),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomQuoteBar extends StatelessWidget {
  const _BottomQuoteBar({
    required this.total,
    required this.onBack,
    required this.onSave,
  });

  final double total;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                '总计',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '¥${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: ZdColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  child: const Text('返回'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZdColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('价高再考虑'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
