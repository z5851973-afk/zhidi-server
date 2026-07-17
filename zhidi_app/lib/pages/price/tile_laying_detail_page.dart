import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../models/renovation.dart';
import '../home/worker/worker_list_page.dart';

class TileLayingDetailPage extends StatefulWidget {
  const TileLayingDetailPage({super.key});

  @override
  State<TileLayingDetailPage> createState() => _TileLayingDetailPageState();
}

class _TileLayingDetailPageState extends State<TileLayingDetailPage> {
  int _selectedSpec = 0;

  static const _specs = [
    _TileSpec('普通地砖', '800×800以内', '¥55/㎡'),
    _TileSpec('大规格瓷砖', '800×800以上', '¥75/㎡'),
    _TileSpec('小规格砖', '300×300以内', '¥80/㎡'),
  ];

  void _openMasonryWorkers() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const WorkerListPage(trade: Trade.masonry, categoryName: '泥瓦'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text('地砖铺贴'),
        backgroundColor: ZdColors.background,
        foregroundColor: ZdColors.textPrimary,
        elevation: 0,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _openMasonryWorkers,
            style: ElevatedButton.styleFrom(
              backgroundColor: ZdColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              '查看可接单泥瓦师傅',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TileHeroCard(),
            const SizedBox(height: 18),
            const _SectionTitle(title: '选择铺贴规格'),
            const SizedBox(height: 10),
            for (int i = 0; i < _specs.length; i++) ...[
              _TileSpecCard(
                spec: _specs[i],
                selected: _selectedSpec == i,
                onTap: () => setState(() => _selectedSpec = i),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            const _SectionTitle(title: '施工包含'),
            const SizedBox(height: 10),
            const _IncludedCard(),
            const SizedBox(height: 14),
            const _SectionTitle(title: '不包含'),
            const SizedBox(height: 10),
            const _ExcludedCard(),
            const SizedBox(height: 14),
            const _SectionTitle(title: '为什么是这个价格？'),
            const SizedBox(height: 10),
            const _PricingReasonCard(),
          ],
        ),
      ),
    );
  }
}

class _TileSpec {
  const _TileSpec(this.title, this.size, this.price);

  final String title;
  final String size;
  final String price;
}

class _TileHeroCard extends StatelessWidget {
  const _TileHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.asset(
                'assets/images/trades/masonry.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '地砖铺贴',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: ZdColors.textPrimary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '专业施工标准 · 平台统一人工价',
            style: TextStyle(fontSize: 14, color: ZdColors.textSecondary),
          ),
          const SizedBox(height: 12),
          const Text(
            '¥55/㎡ 起',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: ZdColors.primary,
              height: 1,
            ),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SoftTag(label: '透明报价'),
              _SoftTag(label: '平台标准'),
              _SoftTag(label: '验收保障'),
            ],
          ),
        ],
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

class _SoftTag extends StatelessWidget {
  const _SoftTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: ZdColors.primary,
        ),
      ),
    );
  }
}

class _TileSpecCard extends StatelessWidget {
  const _TileSpecCard({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _TileSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFFFF0E5) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? ZdColors.primary
                  : ZdColors.textSecondary.withValues(alpha: 0.1),
              width: selected ? 1.4 : 1,
            ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: ZdColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      spec.size,
                      style: const TextStyle(
                        fontSize: 13,
                        color: ZdColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '人工费：',
                    style: TextStyle(
                      fontSize: 12,
                      color: ZdColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    spec.price,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: selected ? ZdColors.primary : ZdColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncludedCard extends StatelessWidget {
  const _IncludedCard();

  @override
  Widget build(BuildContext context) {
    return const _StandardCard(
      children: [
        _ExplainLine(mark: '✓', text: '基层处理', positive: true),
        _ExplainLine(mark: '✓', text: '水平调整', positive: true),
        _ExplainLine(mark: '✓', text: '铺贴施工', positive: true),
        _ExplainLine(mark: '✓', text: '空鼓检查', positive: true),
      ],
    );
  }
}

class _ExcludedCard extends StatelessWidget {
  const _ExcludedCard();

  @override
  Widget build(BuildContext context) {
    return const _StandardCard(
      muted: true,
      children: [
        _ExplainLine(mark: '×', text: '瓷砖材料', positive: false),
        _ExplainLine(mark: '×', text: '美缝', positive: false),
        _ExplainLine(mark: '×', text: '特殊造型施工', positive: false),
      ],
    );
  }
}

class _PricingReasonCard extends StatelessWidget {
  const _PricingReasonCard();

  @override
  Widget build(BuildContext context) {
    return const _StandardCard(
      children: [
        Text(
          '成都区域统一人工标准，根据施工难度、瓷砖规格、工艺要求制定。',
          style: TextStyle(
            fontSize: 14,
            height: 1.55,
            color: ZdColors.textSecondary,
          ),
        ),
        SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ReasonChip(label: '施工难度'),
            _ReasonChip(label: '瓷砖规格'),
            _ReasonChip(label: '工艺要求'),
          ],
        ),
      ],
    );
  }
}

class _StandardCard extends StatelessWidget {
  const _StandardCard({required this.children, this.muted = false});

  final List<Widget> children;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFF1EEE9) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: muted
            ? null
            : const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
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

class _ExplainLine extends StatelessWidget {
  const _ExplainLine({
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
      padding: const EdgeInsets.only(bottom: 10),
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

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: ZdColors.primary,
        ),
      ),
    );
  }
}
