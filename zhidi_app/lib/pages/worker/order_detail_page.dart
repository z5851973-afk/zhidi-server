// ============================================================
// 工匠端 — 订单详情页
// 展示订单完整信息 + 根据订单状态动态操作区
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/worker_app_scope.dart';
import '../../app/worker_app_state.dart';
import '../../design/tokens.dart';
import '../../design/components.dart';
import '../../services/service_request_api_client.dart';
import '../../services/auth_api_client.dart';
import '../../services/worker_booking_api_client.dart';
import '../../services/worker_quote_api_client.dart';
import '../../services/chat_api_client.dart';
import '../../models/chat_models.dart';
import '../shared/quote_detail_page.dart';
import 'daily_report_page.dart';
import 'inspection_page.dart';
import 'quotation_form_page.dart';
import '../chat/chat_detail_page.dart';
import 'worker_settlement_page.dart';

const _primary = ZdColors.primary;
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _divider = ZdColors.divider;
const _success = ZdColors.success;
const _error = ZdColors.error;

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    super.key,
    required this.orderId,
    this.refreshInterval = const Duration(seconds: 8),
    this.quoteApi,
  });

  final String orderId;
  final Duration? refreshInterval;
  final WorkerQuoteApiClient? quoteApi;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    Timer.run(_refreshRemoteOrder);
    final interval = widget.refreshInterval;
    if (interval != null) {
      _refreshTimer = Timer.periodic(interval, (_) => _refreshRemoteOrder());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshRemoteOrder() async {
    if (_refreshing || !mounted) return;
    final state = WorkerAppScope.of(context);
    if (!state.isRemoteOrder(widget.orderId)) return;
    _refreshing = true;
    try {
      await state.fetchRemoteBookings();
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = WorkerAppScope.of(context);
    final matchingOrders = state.orders.where((o) => o.id == widget.orderId);
    final order = matchingOrders.isEmpty ? null : matchingOrders.first;

    if (order == null) {
      return Scaffold(
        backgroundColor: ZdColors.background,
        appBar: AppBar(
          title: const Text('订单详情'),
          backgroundColor: Colors.white,
          foregroundColor: _textDark,
          elevation: 0,
        ),
        body: const Center(child: Text('该订单已更新或不再可用')),
      );
    }

    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: Text(
          order.status == WorkerOrderStatus.completed ? '完工档案' : '订单详情',
        ),
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
            _QuotationCard(
              orderId: widget.orderId,
              quoteApi: widget.quoteApi,
              canViewRemote: switch (order.status) {
                WorkerOrderStatus.quotePending ||
                WorkerOrderStatus.hired ||
                WorkerOrderStatus.inProgress ||
                WorkerOrderStatus.completed => true,
                _ => false,
              },
            ),
            if (order.status == WorkerOrderStatus.completed)
              _CompletedArchiveCard(order: order, quoteApi: widget.quoteApi),
            const SizedBox(height: ZdSpacing.lg),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(order: order, state: state),
    );
  }
}

class _CompletedArchiveCard extends StatefulWidget {
  const _CompletedArchiveCard({required this.order, this.quoteApi});

  final WorkerOrder order;
  final WorkerQuoteApiClient? quoteApi;

  @override
  State<_CompletedArchiveCard> createState() => _CompletedArchiveCardState();
}

class _CompletedArchiveCardState extends State<_CompletedArchiveCard> {
  double? _expectedSettlement;
  double? _expectedWarranty;
  bool _loadingQuote = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = WorkerAppScope.of(context);
    final hasActualFunds =
        state.remoteSettleableAmountForBooking(widget.order.id) > 0 ||
        state.remoteWarrantyRetentionAmountForBooking(widget.order.id) > 0;
    final payment = state.remotePaymentOrderForBooking(widget.order.id);
    if (!hasActualFunds &&
        payment == null &&
        _expectedSettlement == null &&
        !_loadingQuote) {
      _loadExpectedSplit();
    }
  }

  Future<void> _loadExpectedSplit() async {
    final token = WorkerAppScope.of(context).accessToken;
    if (token == null || token.isEmpty) return;
    _loadingQuote = true;
    try {
      final quotes = await (widget.quoteApi ?? WorkerQuoteApiClient())
          .listQuotesForBooking(token, widget.order.id);
      if (!mounted || quotes.isEmpty) return;
      quotes.sort((a, b) {
        final acceptedA = a.status == 'ACCEPTED' ? 1 : 0;
        final acceptedB = b.status == 'ACCEPTED' ? 1 : 0;
        if (acceptedA != acceptedB) return acceptedB.compareTo(acceptedA);
        return b.updatedAt.compareTo(a.updatedAt);
      });
      final quoteTotal = quotes.first.totalPrice;
      setState(() {
        _expectedSettlement = double.parse(quoteTotal.toStringAsFixed(2));
        _expectedWarranty = null;
      });
    } on Exception {
      // 完工档案仍可查看；报价金额会在下一次页面刷新时继续加载。
    } finally {
      _loadingQuote = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = WorkerAppScope.of(context);
    final actualSettleable = state.remoteSettleableAmountForBooking(
      widget.order.id,
    );
    final actualWarranty = state.remoteWarrantyRetentionAmountForBooking(
      widget.order.id,
    );
    final payment = state.remotePaymentOrderForBooking(widget.order.id);
    final hasActualFunds = actualSettleable > 0 || actualWarranty > 0;
    final isSplit = payment?.isSplitOfflineV2 ?? !hasActualFunds;
    final settleable = isSplit
        ? payment?.quoteAmount ?? _expectedSettlement
        : hasActualFunds
        ? actualSettleable
        : payment?.workerSettlement ?? _expectedSettlement;
    final warranty = isSplit
        ? state.remoteWorkerWarrantyAccount?.effectiveBalance
        : hasActualFunds
        ? actualWarranty
        : payment?.warrantyRetention ?? _expectedWarranty;
    final paymentStatus = isSplit
        ? switch (payment) {
            final value when value?.constructionPaymentStatus == 'REPORTED' =>
              '业主已付工程款，待确认到账',
            final value
                when value?.isConstructionConfirmed == true &&
                    value?.isPaid != true =>
              '工程款已确认，付款状态核验中',
            final value when value?.isPaid == true => '本单款项已核验',
            _ => '等待业主付款',
          }
        : switch (payment?.status) {
            'OWNER_REPORTED_PAID' => '业主已付款，待确认收款',
            'PAID' => '已确认收款',
            _ when hasActualFunds => '已确认收款',
            _ => '等待业主付款',
          };
    final amountPrefix = hasActualFunds || payment != null ? '本单' : '预计';
    final waitingForOwner = paymentStatus == '等待业主付款';
    return ZdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('完工资料', style: ZdText.subtitle),
          const SizedBox(height: ZdSpacing.sm),
          Container(
            key: ValueKey('worker-completed-payment-status-${widget.order.id}'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: ZdSpacing.md,
              vertical: ZdSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: waitingForOwner
                  ? const Color(0xFFFFF3DF)
                  : _success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(ZdRadius.md),
            ),
            child: Text(
              paymentStatus,
              style: ZdText.caption.copyWith(
                color: waitingForOwner ? const Color(0xFFB26A00) : _success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: ZdSpacing.md),
          Container(
            key: ValueKey('worker-completed-fund-summary-${widget.order.id}'),
            padding: const EdgeInsets.all(ZdSpacing.md),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(ZdRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _amountItem(
                    isSplit ? '$amountPrefix工程款' : '$amountPrefix可结算',
                    settleable,
                    _primary,
                  ),
                ),
                Container(width: 1, height: 34, color: _divider),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: ZdSpacing.md),
                    child: _amountItem(
                      isSplit ? '履约质保金余额' : '$amountPrefix质保金',
                      warranty,
                      _textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZdSpacing.sm),
          _archiveEntry(
            icon: Icons.note_alt_outlined,
            title: '施工记录',
            subtitle: '查看日报与现场施工记录',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DailyReportPage(orderId: widget.order.id, readOnly: true),
              ),
            ),
          ),
          const Divider(height: 1),
          _archiveEntry(
            icon: Icons.fact_check_outlined,
            title: '验收记录',
            subtitle: '查看本工种验收结果',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InspectionPage(
                  orderId: widget.order.id,
                  tradeLabel: widget.order.trade,
                  readOnly: true,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          _archiveEntry(
            icon: Icons.account_balance_wallet_outlined,
            title: isSplit ? '收入与履约质保金' : '收入与质保金',
            subtitle: isSplit
                ? waitingForOwner
                      ? '业主付款后可核对本单工程款，质保账户独立管理'
                      : '查看本单工程款和独立履约质保账户'
                : waitingForOwner
                ? '业主付款后生成本单结算与质保记录'
                : '查看本单结算与质保冻结记录',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkerSettlementPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountItem(String label, double? amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ZdText.tiny),
        const SizedBox(height: 2),
        Text(
          amount == null ? '核算中' : '¥${amount.toStringAsFixed(0)}',
          style: ZdText.subtitle.copyWith(color: color),
        ),
      ],
    );
  }

  Widget _archiveEntry({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ZdSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(ZdRadius.sm),
              ),
              child: Icon(icon, size: 18, color: _primary),
            ),
            const SizedBox(width: ZdSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ZdText.body),
                  Text(subtitle, style: ZdText.tiny),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: _textMid),
          ],
        ),
      ),
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
              const SizedBox(width: ZdSpacing.sm),
              Expanded(
                child: Text(
                  '订单号：${order.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: ZdText.tiny,
                ),
              ),
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
          _row('电话', _ownerPhoneForDisplay()),
          _row('地址', order.ownerAddress),
        ],
      ),
    );
  }

  String _ownerPhoneForDisplay() {
    final phone = order.ownerPhone.trim();
    if (order.status != WorkerOrderStatus.completed) return phone;
    if (phone.length < 7) return '已隐藏';
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
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
          if (order.houseInfo case final houseInfo?) ...[
            _item(Icons.square_foot, '面积', houseInfo.areaLabel),
            _item(Icons.home_work_outlined, '户型', houseInfo.layoutLabel),
          ] else
            _item(Icons.home_work_outlined, '房屋信息', order.houseSummary),
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
          if (_showsVisitTimeline(order)) ...[
            _item(
              Icons.event_available_outlined,
              '约定上门时间',
              order.scheduledVisitAt == null
                  ? '待确认'
                  : _formatVisitTime(order.scheduledVisitAt!),
            ),
            _item(
              Icons.location_on_outlined,
              '实际到场时间',
              _actualOnSiteAt(order) == null
                  ? '待到场'
                  : _formatVisitTime(_actualOnSiteAt(order)!),
            ),
          ],
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
          Text(label, style: ZdText.caption),
          Text('：', style: ZdText.caption),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: ZdText.caption.copyWith(color: _textDark),
            ),
          ),
        ],
      ),
    );
  }

  bool _showsVisitTimeline(WorkerOrder order) =>
      order.proposedTime != null ||
      order.scheduledVisitAt != null ||
      _actualOnSiteAt(order) != null ||
      switch (order.status) {
        WorkerOrderStatus.accepted ||
        WorkerOrderStatus.visitProposed ||
        WorkerOrderStatus.visitScheduled ||
        WorkerOrderStatus.arrivalPending ||
        WorkerOrderStatus.onSite ||
        WorkerOrderStatus.quotePending ||
        WorkerOrderStatus.hired ||
        WorkerOrderStatus.inProgress ||
        WorkerOrderStatus.completed => true,
        _ => false,
      };

  DateTime? _actualOnSiteAt(WorkerOrder order) =>
      order.actualOnSiteAt ?? order.onSiteAt;

  String _formatVisitTime(DateTime value) {
    final local = value.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    return '${local.year}年${local.month}月${local.day}日 $hour:$minute';
  }
}

// ── 报价单卡片 ──
class _QuotationCard extends StatefulWidget {
  const _QuotationCard({
    required this.orderId,
    required this.canViewRemote,
    this.quoteApi,
  });

  final String orderId;
  final bool canViewRemote;
  final WorkerQuoteApiClient? quoteApi;

  @override
  State<_QuotationCard> createState() => _QuotationCardState();
}

class _QuotationCardState extends State<_QuotationCard> {
  bool _loading = false;
  bool _loadFailed = false;

  Future<void> _openRemoteQuote() async {
    if (_loading) return;
    final app = WorkerAppScope.of(context);
    final token = app.accessToken;
    if (token == null || token.isEmpty) {
      setState(() => _loadFailed = true);
      return;
    }
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final quotes = await (widget.quoteApi ?? WorkerQuoteApiClient())
          .listQuotesForBooking(token, widget.orderId);
      if (!mounted) return;
      if (quotes.isEmpty) {
        setState(() => _loadFailed = true);
        return;
      }
      quotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => QuoteDetailPage(quote: quotes.first)),
      );
    } on Exception {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = WorkerAppScope.of(context);
    final quotation = app.getOrderQuotation(widget.orderId);
    if (quotation == null && !widget.canViewRemote) {
      return const SizedBox.shrink();
    }

    if (quotation == null) {
      return ZdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined, color: _primary),
                const SizedBox(width: ZdSpacing.sm),
                Text('已提交报价单', style: ZdText.subtitle),
              ],
            ),
            const SizedBox(height: ZdSpacing.sm),
            const Text('报价已保存到服务器，可随时核对人工和材料明细。', style: ZdText.caption),
            if (_loadFailed) ...[
              const SizedBox(height: ZdSpacing.sm),
              const Text(
                '报价加载失败，请重试',
                style: TextStyle(color: _error, fontSize: 13),
              ),
            ],
            const SizedBox(height: ZdSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _openRemoteQuote,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.visibility_outlined),
                label: Text(
                  _loading
                      ? '正在加载'
                      : _loadFailed
                      ? '重试'
                      : '查看已提交报价单',
                ),
              ),
            ),
          ],
        ),
      );
    }

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
              onTap: () => _prepareVisitProposal(context, order),
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
        final quotation = WorkerAppScope.of(
          context,
        ).getOrderQuotation(order.id);
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已开始施工')));
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
                        builder: (_) => InspectionPage(
                          orderId: order.id,
                          tradeLabel: order.trade,
                        ),
                      ),
                    );
                  }),
                ),
              ],
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
                    MaterialPageRoute(builder: (_) => WorkerSettlementPage()),
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
                        builder: (_) => InspectionPage(
                          orderId: order.id,
                          tradeLabel: order.trade,
                        ),
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
        final payment = state.remotePaymentOrderForBooking(order.id);
        final awaitingReceipt =
            payment?.isAwaitingWorkerReceipt == true ||
            (payment?.isSplitOfflineV2 == true &&
                payment?.constructionPaymentStatus == 'REPORTED');
        final hasIncome =
            state.remoteSettleableAmountForBooking(order.id) > 0 ||
            state.remoteWarrantyRetentionAmountForBooking(order.id) > 0 ||
            payment?.isPaid == true ||
            payment?.isConstructionConfirmed == true;
        if (awaitingReceipt) {
          return ZdPrimaryButton(
            label: payment?.isSplitOfflineV2 == true
                ? '核对工程款并确认到账'
                : '核对明细并确认收款',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkerSettlementPage()),
            ),
          );
        }
        if (payment?.isSplitOfflineV2 == true &&
            payment?.isConstructionConfirmed == true &&
            payment?.isPaid != true) {
          return ZdPrimaryButton(
            label: '查看付款核验进度',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkerSettlementPage()),
            ),
          );
        }
        if (!hasIncome) {
          return Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ZdRadius.pill),
              color: const Color(0xFFFFF3DF),
            ),
            child: const Center(
              child: Text(
                '等待业主付款',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFFB26A00),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }
        return ZdPrimaryButton(
          label: '查看收入明细',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WorkerSettlementPage()),
          ),
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

  Future<void> _prepareVisitProposal(
    BuildContext context,
    WorkerOrder order,
  ) async {
    await state.fetchRemoteBookings();
    if (!context.mounted) return;
    if (!state.isRemoteOrder(order.id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该预约已失效或不属于当前账号，请返回订单列表刷新')));
      return;
    }
    final latest = state.orders
        .where((item) => item.id == order.id)
        .firstOrNull;
    if (latest == null || latest.status != WorkerOrderStatus.accepted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('预约状态已更新，请按当前状态继续操作')));
      return;
    }
    _showProposeVisitTimePicker(context, latest);
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
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(const SnackBar(content: Text('登录已过期')));
                    }
                    return;
                  }
                  final api = ServiceRequestApiClient();
                  final result = await api.proposeVisit(
                    token,
                    order.id,
                    visitTime,
                  );
                  state.updateOrderFromApi(
                    order.id,
                    result.toRemoteWorkerBooking(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } on AuthApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.code == 'BOOKING_NOT_FOUND'
                              ? '该预约已失效或不属于当前账号，请返回订单列表刷新'
                              : e.message,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('登录已过期')));
        }
        return;
      }
      final api = ServiceRequestApiClient();
      final result = await api.workerArrive(token, order.id);
      state.updateOrderFromApi(order.id, result.toRemoteWorkerBooking());
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已标记到达')));
      }
    } on AuthApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    }
  }

  Future<void> _workerConfirmArrival(
    BuildContext context,
    WorkerOrder order,
  ) async {
    try {
      // ignore: await_only_futures
      final token = await state.getAccessToken();
      if (token == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('登录已过期')));
        }
        return;
      }
      final api = ServiceRequestApiClient();
      final result = await api.workerConfirmArrival(token, order.id);
      state.updateOrderFromApi(order.id, result.toRemoteWorkerBooking());
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已确认业主到场')));
      }
    } on AuthApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录已过期，请重新登录')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录已过期，请重新登录')));
      return;
    }

    // get/create chat room by booking ID
    final chatApi = ChatApiClient();
    ChatRoomModel room;
    try {
      room = await chatApi.getOrCreateRoom(accessToken, order.id);
    } on AuthApiException catch (e) {
      if (context.mounted) {
        if (e.statusCode == 401) {
          await state.logout();
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('登录已过期，请重新登录')));
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法创建聊天：${e.message}')));
      }
      return;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法创建聊天：$e')));
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
