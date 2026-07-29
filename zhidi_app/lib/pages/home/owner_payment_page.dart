import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../design/tokens.dart';
import '../../models/payment_models.dart';
import '../../services/payment_api_client.dart';

const _primary = ZdColors.primary;
const _bg = ZdColors.background;
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _textLight = Color(0xFF9B8F86);
const _line = Color(0xFFF0E4D8);
const _success = ZdColors.success;
const _errorColor = ZdColors.error;
const _warning = Color(0xFFE6A817);

class OwnerPaymentPage extends StatefulWidget {
  const OwnerPaymentPage({
    super.key,
    required this.bookingId,
    this.paymentApi,
  });

  final String bookingId;
  final PaymentApiClient? paymentApi;

  @override
  State<OwnerPaymentPage> createState() => _OwnerPaymentPageState();
}

class _OwnerPaymentPageState extends State<OwnerPaymentPage> {
  PaymentOrderModel? _order;
  bool _loading = true;
  bool _creating = false;
  bool _reporting = false;
  String? _error;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadOrder();
    }
  }

  Future<void> _loadOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = widget.paymentApi ?? PaymentApiClient();
      final token = (await OwnerAppScope.of(context).getAccessToken())!;
      final orders = await api.listOrders(token);
      _order = orders.cast<PaymentOrderModel?>().firstWhere(
        (o) => o?.bookingId == widget.bookingId,
        orElse: () => null,
      );
    } catch (e) {
      _order = null;
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createOrder() async {
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final api = widget.paymentApi ?? PaymentApiClient();
      final token = (await OwnerAppScope.of(context).getAccessToken())!;
      _order = await api.createOrder(token, widget.bookingId);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _creating = false);
  }

  Future<void> _reportOfflinePayment() async {
    String channel = '银行卡转账';
    final referenceController = TextEditingController();
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('确认已线下付款'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '平台不会扣款或代转资金。请只在您已实际向工人付款后继续，工人确认到账后才会完结。',
                  style: TextStyle(fontSize: 13, color: _textMid, height: 1.5),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: channel,
                  decoration: const InputDecoration(labelText: '付款方式'),
                  items: const [
                    DropdownMenuItem(value: '银行卡转账', child: Text('银行卡转账')),
                    DropdownMenuItem(value: '微信转账', child: Text('微信转账')),
                    DropdownMenuItem(value: '支付宝转账', child: Text('支付宝转账')),
                    DropdownMenuItem(value: '现金', child: Text('现金')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => channel = value ?? channel),
                ),
                TextField(
                  controller: referenceController,
                  maxLength: 128,
                  decoration: const InputDecoration(
                    labelText: '付款凭证号（选填）',
                    hintText: '例如转账单号或银行卡尾号',
                  ),
                ),
                TextField(
                  controller: noteController,
                  maxLength: 300,
                  decoration: const InputDecoration(labelText: '备注（选填）'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('返回核对'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认我已付款'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      referenceController.dispose();
      noteController.dispose();
      return;
    }
    final reference = referenceController.text.trim();
    final note = noteController.text.trim();
    referenceController.dispose();
    noteController.dispose();
    setState(() {
      _reporting = true;
      _error = null;
    });
    try {
      final token = await OwnerAppScope.of(context).getAccessToken();
      if (token == null || token.isEmpty) throw Exception('登录已失效，请重新登录');
      _order = await (widget.paymentApi ?? PaymentApiClient()).reportOfflinePayment(
        token,
        _order!.id,
        channel: channel,
        reference: reference.isEmpty ? null : reference,
        note: note.isEmpty ? null : note,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已通知工人，请等待对方确认实际收款')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('支付'),
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
          ? _buildNoOrder()
          : _buildOrderDetail(),
      bottomNavigationBar: _order != null && _order!.isPending
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildNoOrder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 64, color: _textLight),
            const SizedBox(height: 16),
            Text('暂无支付订单', style: TextStyle(fontSize: 16, color: _textMid)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: _errorColor, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _creating ? null : _createOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              child: _creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('生成支付订单'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetail() {
    final order = _order!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态卡片
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _statusIcon(order.status),
                const SizedBox(height: 12),
                Text(
                  order.statusLabel,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(order.status),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 金额明细
          _infoCard(
            '金额明细',
            children: [
              _row('报价总价', '¥${order.amount.toStringAsFixed(2)}'),
              _row(
                '平台服务费',
                '¥${order.platformFee.toStringAsFixed(2)}',
                color: _textLight,
              ),
              const Divider(height: 16, color: _line),
              _row('应付金额', '¥${order.amount.toStringAsFixed(2)}', bold: true),
              _row(
                '工人结算',
                '¥${order.workerSettlement.toStringAsFixed(2)}',
                color: _textLight,
                fontSize: 12,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 订单信息
          _infoCard(
            '订单信息',
            children: [
              _row('订单编号', order.id.substring(0, 8)),
              if (order.transactionId != null)
                _row('交易流水', order.transactionId!),
              if (order.paymentMethod != null)
                _row(
                  '订单模式',
                  order.paymentMethod == 'OFFLINE'
                      ? '线下付款'
                      : order.paymentMethod!,
                ),
              if (order.offlinePaymentChannel != null)
                _row('线下付款方式', order.offlinePaymentChannel!),
              if (order.paymentReference != null)
                _row('付款凭证', order.paymentReference!),
              if (order.ownerReportedPaidAt != null)
                _row('业主报告付款', order.ownerReportedPaidAt!),
              if (order.workerConfirmedReceivedAt != null)
                _row('工人确认收款', order.workerConfirmedReceivedAt!),
              if (order.paidAt != null) _row('支付时间', order.paidAt!),
              if (order.refundedAt != null) _row('退款时间', order.refundedAt!),
            ],
          ),

          const SizedBox(height: 12),
          _infoCard(
            '付款说明',
            children: const [
              Text(
                '在线支付与退款渠道尚未开通。当前采用线下付款、双方确认模式：平台不经手资金，不收取平台服务费；工人确认实际到账后订单才算已付款。',
                style: TextStyle(fontSize: 13, color: _textMid, height: 1.5),
              ),
            ],
          ),

          // 退款入口
          if (order.isPaid) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.undo),
                label: const Text('退款渠道尚未开通'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _errorColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _reporting ? null : _reportOfflinePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _reporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('我已线下付款  ¥${_order!.amount.toStringAsFixed(2)}'),
          ),
        ),
      ),
    );
  }

  Widget _statusIcon(String status) {
    return switch (status) {
      'PENDING' => Icon(Icons.hourglass_empty, size: 48, color: _warning),
      'OWNER_REPORTED_PAID' => Icon(
        Icons.pending_actions,
        size: 48,
        color: _primary,
      ),
      'PAID' => Icon(Icons.check_circle, size: 48, color: _success),
      'REFUNDED' => Icon(Icons.undo, size: 48, color: Colors.blue),
      'FAILED' => Icon(Icons.error, size: 48, color: _errorColor),
      _ => Icon(Icons.help_outline, size: 48, color: _textLight),
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'PENDING' => _warning,
      'OWNER_REPORTED_PAID' => _primary,
      'PAID' => _success,
      'REFUNDED' => Colors.blue,
      'FAILED' => _errorColor,
      _ => _textDark,
    };
  }

  Widget _infoCard(String title, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? color,
    double fontSize = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: _textMid, fontSize: fontSize),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? _textDark,
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
