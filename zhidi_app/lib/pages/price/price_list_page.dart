import 'package:flutter/material.dart';

import '../../data/price_standards.dart';

class PriceListPage extends StatelessWidget {
  const PriceListPage({super.key, required this.trade});

  final TradePriceData trade;

  static const _brandOrange = Color(0xFFFF7A2F);
  static const _textDark = Color(0xFF1F2933);
  static const _textMuted = Color(0xFF697386);
  static const _pageBg = Color(0xFFF7F8FA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        title: Text(trade.pageTitle),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _TradeHeader(trade: trade),
          const SizedBox(height: 16),
          for (final category in trade.categories) ...[
            _CategorySection(category: category),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _TradeHeader extends StatelessWidget {
  const _TradeHeader({required this.trade});

  final TradePriceData trade;

  @override
  Widget build(BuildContext context) {
    final projectCount = trade.categories.fold<int>(
      0,
      (total, category) => total + category.projects.length,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8A3D), Color(0xFFFF6B2B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(trade.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trade.tradeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$projectCount 个报价项目 · 实际工程量结算',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            trade.bannerTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '以下为平台统一人工参考价，材料、垃圾清运、特殊施工等费用会在报价单中单独列明。',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category});

  final PriceCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: PriceListPage._brandOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category.icon,
                    color: PriceListPage._brandOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          color: PriceListPage._textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.description,
                        style: const TextStyle(
                          color: PriceListPage._textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${category.projectCount}项',
                  style: const TextStyle(
                    color: PriceListPage._brandOrange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8ECF2)),
          for (final project in category.projects) _ProjectPriceRow(project),
        ],
      ),
    );
  }
}

class _ProjectPriceRow extends StatelessWidget {
  const _ProjectPriceRow(this.project);

  final PriceProject project;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              project.name,
              style: const TextStyle(
                color: PriceListPage._textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${project.price}${project.unit}',
            style: const TextStyle(
              color: PriceListPage._brandOrange,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
