import 'package:flutter/material.dart';

import '../../data/price_standards.dart';
import 'price_list_page.dart';

class PriceTransparencyPage extends StatelessWidget {
  const PriceTransparencyPage({super.key});

  static const _brandOrange = Color(0xFFFF7A2F);
  static const _textDark = Color(0xFF1F2933);
  static const _textMuted = Color(0xFF697386);
  static const _pageBg = Color(0xFFF7F8FA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        title: const Text('工价透明'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const _HeroCard(),
          const SizedBox(height: 16),
          const Text(
            '选择工种查看标准',
            style: TextStyle(
              color: _textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final trade in allTrades) ...[
            _TradeCard(trade: trade),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '平台统一人工参考价',
            style: TextStyle(
              color: PriceTransparencyPage._textDark,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '先看标准，再看师傅报价。人工单价公开，按实际工程量结算，减少临场加价和口头报价。',
            style: TextStyle(
              color: PriceTransparencyPage._textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeCard extends StatelessWidget {
  const _TradeCard({required this.trade});

  final TradePriceData trade;

  @override
  Widget build(BuildContext context) {
    final projectCount = trade.categories.fold<int>(
      0,
      (total, category) => total + category.projects.length,
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PriceListPage(trade: trade),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8ECF2)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: PriceTransparencyPage._brandOrange.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  trade.icon,
                  color: PriceTransparencyPage._brandOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trade.tradeName,
                      style: const TextStyle(
                        color: PriceTransparencyPage._textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${trade.categories.length} 个分类 · $projectCount 个项目',
                      style: const TextStyle(
                        color: PriceTransparencyPage._textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9AA4B2)),
            ],
          ),
        ),
      ),
    );
  }
}
