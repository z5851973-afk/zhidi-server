// ============================================================
// 工匠端 — 收入明细页
// 顶部统计卡片 + 收入记录列表 + 按月筛选
// ============================================================

import 'package:flutter/material.dart';

import '../../app/worker_app_scope.dart';
import '../../app/worker_models.dart';
import '../../design/tokens.dart';
import '../../design/components.dart';

const _primary = ZdColors.primary;
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _textLight = ZdColors.textHint;
const _success = ZdColors.success;

class WorkerEarningsPage extends StatefulWidget {
  const WorkerEarningsPage({super.key});

  @override
  State<WorkerEarningsPage> createState() => _WorkerEarningsPageState();
}

class _WorkerEarningsPageState extends State<WorkerEarningsPage> {
  int? _selectedMonth; // 1-12，null 表示全部

  @override
  Widget build(BuildContext context) {
    final state = WorkerAppScope.of(context);
    final total = state.totalEarnings;
    final pendingAmount = state.earnings
        .where((e) => e.status == EarningSettlementStatus.pending)
        .fold<double>(0, (s, e) => s + e.amount);

    // 按月筛选
    final filtered = _selectedMonth == null
        ? state.earnings
        : state.earnings.where((e) => e.time.month == _selectedMonth).toList();

    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text('收入明细'),
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── 统计卡片 ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(ZdSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(ZdSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: ZdColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(ZdRadius.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('累计收入', style: ZdText.tiny.copyWith(color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text('¥${total.toStringAsFixed(0)}',
                            style: ZdText.headline.copyWith(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: ZdSpacing.md),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(ZdSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(ZdRadius.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('待结算', style: ZdText.tiny.copyWith(color: _primary)),
                        const SizedBox(height: 4),
                        Text('¥${pendingAmount.toStringAsFixed(0)}',
                            style: ZdText.headline.copyWith(color: _primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 月份筛选 ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(left: ZdSpacing.lg, right: ZdSpacing.lg, bottom: ZdSpacing.md),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _monthChip(null, '全部'),
                  for (int m = 1; m <= 12; m++)
                    _monthChip(m, '$m月'),
                ],
              ),
            ),
          ),

          // ── 记录列表 ──
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payments_outlined, size: 56, color: _textLight),
                        const SizedBox(height: ZdSpacing.md),
                        Text('暂无收入记录', style: ZdText.caption.copyWith(color: _textLight)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(ZdSpacing.md),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final e = filtered[i];
                      return _EarningItem(record: e);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _monthChip(int? month, String label) {
    final selected = _selectedMonth == month;
    return Padding(
      padding: const EdgeInsets.only(right: ZdSpacing.sm),
      child: GestureDetector(
        onTap: () => setState(() => _selectedMonth = month),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: ZdSpacing.lg, vertical: ZdSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? _primary : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(ZdRadius.pill),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: selected ? Colors.white : _textMid,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
        ),
      ),
    );
  }
}

class _EarningItem extends StatelessWidget {
  const _EarningItem({required this.record});
  final EarningRecord record;

  Color get _typeColor => record.type == EarningType.deposit
      ? Colors.blue
      : record.type == EarningType.balance
          ? _primary
          : Colors.amber.shade700;

  @override
  Widget build(BuildContext context) {
    return ZdCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(ZdSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ZdRadius.sm),
              ),
              child: Icon(
                record.type == EarningType.deposit
                    ? Icons.payment
                    : record.type == EarningType.balance
                        ? Icons.check_circle_outline
                        : Icons.card_giftcard,
                color: _typeColor,
                size: 22,
              ),
            ),
            const SizedBox(width: ZdSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.orderTitle, style: ZdText.body,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(ZdRadius.pill),
                        ),
                        child: Text(record.typeLabel,
                            style: ZdText.tiny.copyWith(color: _typeColor)),
                      ),
                      const SizedBox(width: ZdSpacing.sm),
                      Text(_fmt(record.time), style: ZdText.tiny),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('¥${record.amount.toStringAsFixed(0)}',
                    style: ZdText.subtitle.copyWith(color: _textDark)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: record.status == EarningSettlementStatus.settled
                        ? _success.withValues(alpha: 0.1)
                        : _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ZdRadius.pill),
                  ),
                  child: Text(record.statusLabel,
                      style: ZdText.tiny.copyWith(
                          color: record.status == EarningSettlementStatus.settled
                              ? _success
                              : _primary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}
