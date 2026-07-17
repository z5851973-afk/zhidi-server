import 'package:flutter/material.dart';

import '../../data/price_standards.dart';
import '../../design/tokens.dart';
import '../price/price_list_page.dart';

class RenovationBudgetReportPage extends StatelessWidget {
  const RenovationBudgetReportPage({super.key});

  static const _report = _BudgetReportMockData(
    title: '知底装修预算报告',
    houseTags: ['89㎡', '毛坯房', '简约装修', '人工+辅料预估'],
    proofTags: ['平台工价', '人工辅料', '现场核量'],
    totalLabel: '预计装修费用',
    totalAmount: '¥58,260',
    totalScope: '预计人工+辅料费用',
    errorRange: '预计误差约±10%',
    cityNote: '根据成都区域统一施工标准及历史数据测算，实际价格以现场确认结果为准。',
    items: [
      _BudgetTradeItem('拆除工程', '¥3200', '墙体拆除、地面拆除、厨卫拆除', demolitionTrade),
      _BudgetTradeItem(
        '水电工程',
        '¥8500',
        '水路改造、电路改造、基础安装',
        plumbingElectricTrade,
      ),
      _BudgetTradeItem('泥瓦工程', '¥16800', '贴砖、找平、砌墙抹灰', masonryTrade),
      _BudgetTradeItem('防水工程', '¥6500', '厨卫防水、阳台防水、闭水试验', waterproofTrade),
      _BudgetTradeItem('木工工程', '¥12400', '吊顶、基层制作等', carpentryTrade),
      _BudgetTradeItem('油工工程', '¥9600', '基层处理、墙面施工', paintingTrade),
    ],
  );

  void _openTradePrice(BuildContext context, TradePriceData trade) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PriceListPage(trade: trade)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        backgroundColor: ZdColors.background,
        foregroundColor: ZdColors.textPrimary,
        elevation: 0,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: ZdColors.background,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '先了解标准价格，再选择施工师傅',
                style: TextStyle(fontSize: 12, color: ZdColors.textSecondary),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PriceListPage(trade: masonryTrade),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZdColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    '查看施工工价',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 126),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ReportHeader(report: _report),
            const SizedBox(height: 14),
            const _TotalBudgetCard(report: _report),
            const SizedBox(height: 18),
            const _SectionTitle(title: '费用拆分'),
            const SizedBox(height: 10),
            for (final item in _report.items) ...[
              _BudgetTradeCard(
                item: item,
                onTap: () => _openTradePrice(context, item.trade),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            const _SectionTitle(title: '预算说明'),
            const SizedBox(height: 10),
            const _BudgetDescriptionCard(),
            const SizedBox(height: 18),
            const _SectionTitle(title: '为什么是这个价格？'),
            const SizedBox(height: 10),
            const _PriceBasisCard(),
            const SizedBox(height: 18),
            const _SectionTitle(title: '知底保障'),
            const SizedBox(height: 10),
            const _PlatformGuaranteeCard(),
          ],
        ),
      ),
    );
  }
}

class _BudgetReportMockData {
  const _BudgetReportMockData({
    required this.title,
    required this.houseTags,
    required this.proofTags,
    required this.totalLabel,
    required this.totalAmount,
    required this.totalScope,
    required this.errorRange,
    required this.cityNote,
    required this.items,
  });

  final String title;
  final List<String> houseTags;
  final List<String> proofTags;
  final String totalLabel;
  final String totalAmount;
  final String totalScope;
  final String errorRange;
  final String cityNote;
  final List<_BudgetTradeItem> items;
}

class _BudgetTradeItem {
  const _BudgetTradeItem(this.title, this.amount, this.includes, this.trade);

  final String title;
  final String amount;
  final String includes;
  final TradePriceData trade;
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.report});

  final _BudgetReportMockData report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: ZdColors.textPrimary,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in report.houseTags) _InfoPill(label: tag),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in report.proofTags) _SoftTag(label: tag),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.cityNote,
            style: const TextStyle(
              fontSize: 12,
              height: 1.55,
              color: ZdColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalBudgetCard extends StatelessWidget {
  const _TotalBudgetCard({required this.report});

  final _BudgetReportMockData report;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFFFF7F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.totalLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: ZdColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            report.totalAmount,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: ZdColors.primary,
              height: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            report.totalScope,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: ZdColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: ZdColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              report.errorRange,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ZdColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE5DA)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: ZdColors.textPrimary,
        ),
      ),
    );
  }
}

class _SoftTag extends StatelessWidget {
  const _SoftTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZdColors.primary.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: ZdColors.textPrimary,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: ZdColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: ZdColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _BudgetTradeCard extends StatelessWidget {
  const _BudgetTradeCard({required this.item, required this.onTap});

  final _BudgetTradeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: ZdColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.trade.icon, size: 20, color: ZdColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: ZdColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F1EA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '包含',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: ZdColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.includes,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: ZdColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '预计',
                    style: TextStyle(fontSize: 11, color: ZdColors.textHint),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.amount,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: ZdColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F1EA),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: ZdColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetDescriptionCard extends StatelessWidget {
  const _BudgetDescriptionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EEE9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '预算包含',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: ZdColors.textPrimary,
            ),
          ),
          SizedBox(height: 14),
          Text(
            '包含：',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: ZdColors.textPrimary,
            ),
          ),
          SizedBox(height: 10),
          _BudgetExplainLine(mark: '✓', text: '人工费用', positive: true),
          _BudgetExplainLine(mark: '✓', text: '基础辅料费用', positive: true),
          _BudgetExplainLine(mark: '✓', text: '施工费用', positive: true),
          SizedBox(height: 16),
          Text(
            '不包含：',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: ZdColors.textPrimary,
            ),
          ),
          SizedBox(height: 10),
          _BudgetExplainLine(mark: '×', text: '瓷砖', positive: false),
          _BudgetExplainLine(mark: '×', text: '地板', positive: false),
          _BudgetExplainLine(mark: '×', text: '洁具', positive: false),
          _BudgetExplainLine(mark: '×', text: '灯具', positive: false),
          _BudgetExplainLine(mark: '×', text: '家电', positive: false),
        ],
      ),
    );
  }
}

class _PriceBasisCard extends StatelessWidget {
  const _PriceBasisCard();

  @override
  Widget build(BuildContext context) {
    return const _InfoCard(
      children: [
        Text(
          '根据以下条件进行计算：',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: ZdColors.textPrimary,
          ),
        ),
        SizedBox(height: 12),
        _BudgetExplainLine(mark: '•', text: '房屋面积', positive: true),
        _BudgetExplainLine(mark: '•', text: '装修类型', positive: true),
        _BudgetExplainLine(mark: '•', text: '装修档次', positive: true),
        _BudgetExplainLine(mark: '•', text: '成都区域统一人工标准', positive: true),
      ],
    );
  }
}

class _PlatformGuaranteeCard extends StatelessWidget {
  const _PlatformGuaranteeCard();

  @override
  Widget build(BuildContext context) {
    return const _InfoCard(
      children: [
        _BudgetExplainLine(mark: '✓', text: '平台统一人工价格', positive: true),
        _BudgetExplainLine(mark: '✓', text: '避免临时报价上涨', positive: true),
        _BudgetExplainLine(mark: '✓', text: '施工标准透明', positive: true),
        _BudgetExplainLine(mark: '✓', text: '验收标准明确', positive: true),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _BudgetExplainLine extends StatelessWidget {
  const _BudgetExplainLine({
    required this.mark,
    required this.text,
    required this.positive,
  });

  final String mark;
  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              mark,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: positive ? const Color(0xFF00A85A) : Color(0xFFB45A44),
              ),
            ),
          ),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ZdColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
