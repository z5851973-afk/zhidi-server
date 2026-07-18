// ============================================================
// 工匠端 — 订单详情页
// 展示订单完整信息 + 根据订单状态动态操作区
// ============================================================

import 'package:flutter/material.dart';

import '../../app/worker_app_scope.dart';
import '../../app/worker_app_state.dart';
import '../../design/tokens.dart';
import '../../design/components.dart';
import '../../services/service_request_api_client.dart';
import '../../services/auth_api_client.dart';
import '../../services/worker_booking_api_client.dart';
import '../../services/chat_api_client.dart';
import '../../models/chat_models.dart';
import 'daily_report_page.dart';
import 'inspection_page.dart';
import 'quotation_form_page.dart';
import 'worker_earnings_page.dart';
import '../chat/chat_detail_page.dart';
import 'worker_settlement_page.dart';

const _primary = ZdColors.primary;
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _divider = ZdColors.divider;
const _success = ZdColors.success;
const _error = ZdColors.error;

class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final state = WorkerAppScope.of(context);
    final order = state.orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => state.orders.first,
    );

    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text('订单详情'),
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _StatusHeader(order: order),
            _OwnerCard(order: order),
            _RequirementCard(order: order),
            if (order.status == WorkerOrderStatus.inProgress ||
                order.status == WorkerOrderStatus.accepted)
              _PhaseCard(order: order),
            _QuotationCard(orderId: orderId),
            const SizedBox(height: ZdSpacing.lg),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(order: order, state: state),
    );
  }
}

// ── 状态头部 ──
class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.order});
  final WorkerOrder order;

  Color get _badgeColor => switch (order.status) {
    WorkerOrderStatus.pending => _primary,
    WorkerOrderStatus.accepted => Colors.blue,
    WorkerOrderStatus.visitProposed => Colors.orange,
    WorkerOrderStatus.visitScheduled => Colors.blue,
    WorkerOrderStatus.arrivalPending => Colors.teal,
    WorkerOrderStatus.onSite => _success,
    WorkerOrderStatus.quotePending => Colors.indigo,
    WorkerOrderStatus.hired => _success,
    WorkerOrderStatus.inProgress => _success,
    WorkerOrderStatus.completed => _textMid,
    WorkerOrderStatus.cancelled => _error,
  };

  Color get _badgeBg => switch (order.status) {
    WorkerOrderStatus.pending => _primary.withValues(alpha: 0.1),
    WorkerOrderStatus.accepted => Colors.blue.withValues(alpha: 0.1),
    WorkerOrderStatus.visitProposed => Colors.orange.withValues(alpha: 0.1),
    WorkerOrderStatus.visitScheduled => Colors.blue.withValues(alpha: 0.1),
    WorkerOrderStatus.arrivalPending => Colors.teal.withValues(alpha: 0.1),
    WorkerOrderStatus.onSite => _success.withValues(alpha: 0.1),
    WorkerOrderStatus.quotePending => Colors.indigo.withValues(alpha: 0.1),
    WorkerOrderStatus.hired => _success.withValues(alpha: 0.1),
    WorkerOrderStatus.inProgress => _success.withValues(alpha: 0.1),
    WorkerOrderStatus.completed => _textMid.withValues(alpha: 0.1),
    WorkerOrderStatus.cancelled => _error.withValues(alpha: 0.1),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZdSpacing.lg),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _badgeBg,
                  borderRadius: BorderRadius.circular(ZdRadius.pill),
                ),
                child: Text(
                  order.statusLabel,
                  style: ZdText.body.copyWith(
                    color: _badgeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text('订单号：${order.id}', style: ZdText.tiny),
            ],
          ),
          const SizedBox(height: ZdSpacing.md),
          Text(order.requirement, style: ZdText.headline),
        ],
      ),
    );
  }
}

// ── 业主信息卡片 ──
class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.order});
  final WorkerOrder order;

  @override
  Widget build(BuildContext context) {
    return ZdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: _primary),
              const SizedBox(width: ZdSpacing.sm),
              Text('业主信息', style: ZdText.subtitle),
            ],
          ),
          const SizedBox(height: ZdSpacing.md),
          _row('姓名', order.ownerName),
          _row('电话', order.ownerPhone),
          _row('地址', order.ownerAddress),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZdSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 48, child: Text(label, style: ZdText.caption)),
          Expanded(child: Text(value, style: ZdText.body)),
        ],
      ),
    );
  }
}

// ── 需求信息卡片 ──
class _RequirementCard extends StatelessWidget {
  const _RequirementCard({required this.order});
  final WorkerOrder order;

  @override
  Widget build(BuildContext context) {
    return ZdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, size: 16, color: _primary),
              const SizedBox(width: ZdSpacing.sm),
              Text('需求详情', style: ZdText.subtitle),
            ],
          ),
          const SizedBox(height: ZdSpacing.md),
          _item(Icons.build, '工种', order.trade),
          _item(Icons.square_foot, '面积', order.area),
          if (order.quotedPrice != null)
            _item(
              Icons.attach_money,
              '报价',
              '¥${order.quotedPrice!.toStringAsFixed(0)}',
            ),
          if (order.visitTime != null)
            _item(
              Icons.event,
              '预约时间',
              '${order.visitTime!.year}年${order.visitTime!.month}月${order.visitTime!.day}日',
            ),
          const SizedBox(height: ZdSpacing.sm),
          Text(order.description, style: ZdText.body),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _textMid),
          const SizedBox(width: 6),
          Text('$label：', style: ZdText.caption),
          const SizedBox(width: 4),
          Text(value, style: ZdText.caption.copyWith(color: _textDark)),
        ],
      ),
    );
  }
}

// ── 报价单卡片 ──
class _QuotationCard extends StatelessWidget {
  const _QuotationCard({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final app = WorkerAppScope.of(context);
    final quotation = app.getOrderQuotation(orderId);
    if (quotation == null) return const SizedBox.shrink();

    return ZdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 16,
                color: _primary,
              ),
              const SizedBox(width: ZdSpacing.sm),
              Text('报价单', style: ZdText.subtitle),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: quotation.isConfirmed
                      ? _success.withValues(alpha: 0.1)
                      : _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ZdRadius.pill),
                ),
                child: Text(
                  quotation.isConfirmed ? '已确认' : '待确认',
                  style: ZdText.tiny.copyWith(
                    color: quotation.isConfirmed ? _success : _primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZdSpacing.md),
          if (quotation.laborTotal > 0)
            _sectionRow('人工费', quotation.laborTotal),
          if (quotation.auxiliaryTotal > 0)
            _sectionRow('辅料', quotation.auxiliaryTotal),
          if (quotation.mainMaterialTotal > 0)
            _sectionRow('主材', quotation.mainMaterialTotal),
          const Divider(height: 24),
          Row(
            children: [
              const Text('合计', style: ZdText.subtitle),
              const Spacer(),
              Text(
                '¥${quotation.grandTotal.toStringAsFixed(0)}',
                style: ZdText.headline.copyWith(
                  color: _primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZdSpacing.sm),
          Text(
            '提交于 ${quotation.createdAt.year}年${quotation.createdAt.month}月${quotation.createdAt.day}日',
            style: ZdText.tiny,
          ),
        ],
      ),
    );
  }

  Widget _sectionRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: ZdText.caption)),
          Expanded(
            child: Text(
              '¥${amount.toStringAsFixed(0)}',
              style: ZdText.body.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 工序进度卡片 ──
class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.order});
  final WorkerOrder order;

  @override
  Widget build(BuildContext context) {
    final phaseIndex = order.phaseIndex ?? 0;
    // 模拟工序进度
    final phases = const ['拆除', '水电', '防水', '泥瓦', '木工', '油漆', '安装', '清洁'];

    return ZdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, size: 16, color: _primary),
              const SizedBox(width: ZdSpacing.sm),
              Text('工序进度', style: ZdText.subtitle),
            ],
          ),
          const SizedBox(height: ZdSpacing.md),
          ...List.generate(phases.length, (i) {
            final isCurrent = i == phaseIndex;
            final isDone = i < phaseIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? _success
                          : (isCurrent ? _primary : _divider),
                    ),
                    child: isDone
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Center(
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isCurrent ? Colors.white : _textMid,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: ZdSpacing.md),
                  Text(
                    phases[i],
                    style: (isCurrent || isDone)
                        ? ZdText.body.copyWith(fontWeight: FontWeight.w500)
                        : ZdText.caption,
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: ZdSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(ZdRadius.pill),
                      ),
                      child: Text(
                        '进行中',
                        style: ZdText.tiny.copyWith(color: _primary),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── 底部固定操作栏 ──
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.order, required this.state});
  final WorkerOrder order;
  final WorkerAppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZdSpacing.lg),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 8,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(child: _buildActions(context)),
    );
  }

  Widget _buildActions(BuildContext context) {
    switch (order.status) {
      case WorkerOrderStatus.pending:
        if (state.isRemoteOrder(order.id)) {
          return Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ZdColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      foregroundColor: ZdColors.primary,
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    onPressed: () => state.rejectRemoteBooking(order.id),
                    child: const Text('拒绝'),
                  ),
                ),
              ),
              const SizedBox(width: ZdSpacing.md),
              Expanded(
                child: ZdPrimaryButton(
                  label: '立即接单',
                  onTap: () => state.acceptRemoteBooking(order.id),
                ),
              ),
            ],
          );
        }
        return ZdPrimaryButton(
          label: '立即接单',
          onTap: () => _showAcceptDialog(context, order),
        );

      case WorkerOrderStatus.accepted:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ZdPrimaryButton(
              label: '提出上门时间',
              onTap: () => _showProposeVisitTimePicker(context, order),
            ),
            const SizedBox(height: ZdSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: _outlineBtn(
                '联系业主',
                () => _openWorkerChat(context, order, state),
              ),
            ),
          ],
        );

      case WorkerOrderStatus.visitProposed:
        return Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZdRadius.pill),
            color: Colors.orange.shade50,
          ),
          child: const Center(
            child: Text(
              '等待业主确认上门时间',
              style: TextStyle(fontSize: 15, color: ZdColors.textSecondary),
            ),
          ),
        );

      case WorkerOrderStatus.visitScheduled:
        return ZdPrimaryButton(
          label: '我已到达',
          onTap: () => _workerArrive(context, order),
        );

      case WorkerOrderStatus.arrivalPending:
        return ZdPrimaryButton(
          label: '确认业主已到场',
          onTap: () => _workerConfirmArrival(context, order),
        );

      case WorkerOrderStatus.onSite:
        final quotation = WorkerAppScope.of(context).getOrderQuotation(order.id);
        if (quotation == null) {
          return ZdPrimaryButton(
            label: '提交报价单',
            onTap: () => _openQuotation(context, order),
          );
        }
        return ZdPrimaryButton(
          label: '开始施工',
          onTap: () async {
            await WorkerAppScope.of(context).startOrder(order.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已开始施工')),
              );
            }
          },
        );

      case WorkerOrderStatus.quotePending:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_empty, size: 18, color: Colors.indigo),
              SizedBox(width: 8),
              Text(
                '报价已提交，等待业主确认',
                style: TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );

      case WorkerOrderStatus.hired:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 18, color: _success),
                  SizedBox(width: 8),
                  Text(
                    '已被选中',
                    style: TextStyle(
                      color: _success,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZdSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openWorkerChat(context, order, state),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('联系业主'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ZdRadius.md),
                  ),
                ),
              ),
            ),
            const SizedBox(height: ZdSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkerSettlementPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('查看结算'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ZdRadius.md),
                  ),
                ),
              ),
            ),
          ],
        );

      case WorkerOrderStatus.inProgress:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _outlineBtn('提交日报', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DailyReportPage(orderId: order.id),
                      ),
                    );
                  }),
                ),
                const SizedBox(width: ZdSpacing.md),
                Expanded(
                  child: _outlineBtn('发起验收', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InspectionPage(orderId: order.id),
                      ),
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: ZdSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _outlineBtn(
                    '报价单',
                    () => _openQuotation(context, order),
                  ),
                ),
                const SizedBox(width: ZdSpacing.md),
                Expanded(
                  child: _outlineBtn(
                    '联系业主',
                    () => _openWorkerChat(context, order, state),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZdSpacing.md),
            ZdPrimaryButton(
              label: '完成施工',
              onTap: () async {
                await WorkerAppScope.of(context).completeOrder(order.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('施工已完成')));
                }
              },
            ),
          ],
        );

      case WorkerOrderStatus.completed:
        return ZdPrimaryButton(
          label: '查看收入详情',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const WorkerEarningsPage())),
        );

      case WorkerOrderStatus.cancelled:
        return Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZdRadius.pill),
            color: Colors.grey.shade100,
          ),
          child: const Center(
            child: Text(
              '该订单已取消',
              style: TextStyle(color: ZdColors.textSecondary),
            ),
          ),
        );
    }
  }

  Widget _outlineBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          border: Border.all(color: _primary),
          borderRadius: BorderRadius.circular(21),
        ),
        child: Center(
          child: Text(
            label,
            style: ZdText.body.copyWith(
              color: _primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _showAcceptDialog(BuildContext context, WorkerOrder order) {
    final priceCtrl = TextEditingController();
    var visitTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day + 1,
      9,
      0,
    );
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZdRadius.card),
          ),
          title: Text('确认接单', style: ZdText.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${order.ownerName} — ${order.requirement}',
                style: ZdText.caption,
              ),
              const SizedBox(height: ZdSpacing.lg),
              Text(
                '约定上门时间',
                style: ZdText.caption.copyWith(
                  color: _textDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: ZdSpacing.sm),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: visitTime,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 180)),
                    locale: const Locale('zh'),
                  );
                  if (date == null || !ctx.mounted) return;
                  final time = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(visitTime),
                  );
                  if (time == null) return;
                  setDialogState(() {
                    visitTime = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    );
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: _divider),
                    borderRadius: BorderRadius.circular(ZdRadius.sm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 18, color: _primary),
                      const SizedBox(width: ZdSpacing.sm),
                      Text(
                        '${visitTime.month}月${visitTime.day}日 ${visitTime.hour.toString().padLeft(2, '0')}:${visitTime.minute.toString().padLeft(2, '0')}',
                        style: ZdText.body,
                      ),
                      const Spacer(),
                      Text('修改', style: ZdText.tiny.copyWith(color: _primary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: ZdSpacing.lg),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '报价（选填）',
                  hintText: '请输入报价金额',
                  prefixText: '¥ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ZdRadius.sm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: ZdText.body.copyWith(color: _textMid)),
            ),
            ZdPrimaryButton(
              label: '确认接单',
              height: 40,
              onTap: () async {
                final p = double.tryParse(priceCtrl.text);
                await WorkerAppScope.of(
                  context,
                ).acceptOrder(order.id, quotedPrice: p, visitTime: visitTime);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProposeVisitTimePicker(BuildContext context, WorkerOrder order) {
    var visitTime =
        order.proposedTime ??
        DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day + 1,
          9,
          0,
        );
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZdRadius.card),
          ),
          title: Text('提出上门时间', style: ZdText.title),
          content: GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: ctx,
                initialDate: visitTime,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 180)),
                locale: const Locale('zh'),
              );
              if (date == null || !ctx.mounted) return;
              final time = await showTimePicker(
                context: ctx,
                initialTime: TimeOfDay.fromDateTime(visitTime),
              );
              if (time == null) return;
              setDialogState(() {
                visitTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: _divider),
                borderRadius: BorderRadius.circular(ZdRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 20, color: _primary),
                  const SizedBox(width: ZdSpacing.sm),
                  Text(
                    '${visitTime.month}月${visitTime.day}日 ${visitTime.hour.toString().padLeft(2, '0')}:${visitTime.minute.toString().padLeft(2, '0')}',
                    style: ZdText.subtitle,
                  ),
                  const Spacer(),
                  Text('点击修改', style: ZdText.tiny.copyWith(color: _primary)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: ZdText.body.copyWith(color: _textMid)),
            ),
            ZdPrimaryButton(
              label: '确认',
              height: 40,
              onTap: () async {
                try {
                  final token = state.getAccessToken();
                  if (token == null) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('登录已过期')),
                      );
                    }
                    return;
                  }
                  final api = ServiceRequestApiClient();
                  final result = await api.proposeVisit(token, order.id, visitTime);
                  state.updateOrderFromApi(order.id, result.toRemoteWorkerBooking());
                  if (ctx.mounted) Navigator.pop(ctx);
                } on AuthApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.message)),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('操作失败：$e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _workerArrive(BuildContext context, WorkerOrder order) async {
    try {
      final token = state.getAccessToken();
      if (token == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登录已过期')),
          );
        }
        return;
      }
      final api = ServiceRequestApiClient();
      final result = await api.workerArrive(token, order.id);
      state.updateOrderFromApi(order.id, result.toRemoteWorkerBooking());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已标记到达')),
        );
      }
    } on AuthApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e')),
        );
      }
    }
  }

  Future<void> _workerConfirmArrival(BuildContext context, WorkerOrder order) async {
    try {
      // ignore: await_only_futures
      final token = await state.getAccessToken();
      if (token == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登录已过期')),
          );
        }
        return;
      }
      final api = ServiceRequestApiClient();
      final result = await api.workerConfirmArrival(token, order.id);
      state.updateOrderFromApi(order.id, result.toRemoteWorkerBooking());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已确认业主到场')),
        );
      }
    } on AuthApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e')),
        );
      }
    }
  }

  static void _openQuotation(BuildContext context, WorkerOrder order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuotationFormPage(order: order)),
    );
  }

  static void _openWorkerChat(
    BuildContext context,
    WorkerOrder order,
    WorkerAppState state,
  ) async {
    final accessToken = state.getAccessToken();
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录已过期，请重新登录')),
      );
      return;
    }

    RemoteWorkerBooking? remote;
    try {
      remote = state.remoteBookings.firstWhere((b) => b.id == order.id);
    } catch (_) {
      // remote booking not found in local cache
    }

    final currentUserId = remote?.workerUserId ?? await state.getUserId();
    if (currentUserId == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录已过期，请重新登录')),
      );
      return;
    }

    // get/create chat room by booking ID
    final chatApi = ChatApiClient();
    ChatRoomModel room;
    try {
      room = await chatApi.getOrCreateRoom(accessToken, order.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法创建聊天：$e')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          roomId: room.id,
          otherUserName: order.ownerName,
          accessToken: accessToken,
          currentUserId: currentUserId,
        ),
      ),
    );
  }
}
