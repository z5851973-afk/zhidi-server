import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../services/worker_quote_api_client.dart';

class QuoteDetailPage extends StatelessWidget {
  const QuoteDetailPage({super.key, required this.quote});

  final RemoteQuote quote;

  @override
  Widget build(BuildContext context) {
    final laborItems = quote.items.where((item) => !item.isMaterial).toList();
    final materialItems = quote.items.where((item) => item.isMaterial).toList();
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text('报价明细'),
        backgroundColor: Colors.white,
        foregroundColor: ZdColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _QuoteSection(title: '人工明细', items: laborItems),
          const SizedBox(height: 12),
          _QuoteSection(title: '材料明细', items: materialItems),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '报价清单总价',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '¥${quote.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: ZdColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteSection extends StatelessWidget {
  const _QuoteSection({required this.title, required this.items});

  final String title;
  final List<RemoteQuoteItem> items;

  @override
  Widget build(BuildContext context) {
    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + (item.subtotal ?? 0),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ZdColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '小计 ¥${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: ZdColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text(
              '无此类费用',
              style: TextStyle(color: ZdColors.textHint, fontSize: 13),
            )
          else
            ...items.map(_QuoteItemRow.new),
        ],
      ),
    );
  }
}

class _QuoteItemRow extends StatelessWidget {
  const _QuoteItemRow(this.item);

  final RemoteQuoteItem item;

  @override
  Widget build(BuildContext context) {
    final quantity = item.quantity ?? 0;
    final quantityText = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name ?? '报价项目',
                  style: const TextStyle(
                    color: ZdColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '¥${(item.unitPrice ?? 0).toStringAsFixed(2)}/${item.unit ?? ''} × $quantityText',
                  style: const TextStyle(
                    color: ZdColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '¥${(item.subtotal ?? 0).toStringAsFixed(2)}',
            style: const TextStyle(
              color: ZdColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
