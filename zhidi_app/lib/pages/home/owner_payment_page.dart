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
  const OwnerPaymentPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<OwnerPaymentPage> createState() => _OwnerPaymentPageState();
}

class _OwnerPaymentPageState extends State<OwnerPaymentPage> {
  PaymentOrderModel? _order;
  bool _loading = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = PaymentApiClient();
      final token = (await OwnerAppScope.of(context).getAccessToken())!;
      final orders = await api.listOrders(token);
      _order = orders.cast<PaymentOrderModel?>().firstWhere(
            (o) => o?.bookingId == widget.bookingId,
            orElse: () => null,
          );
    } catch (e) {
      _order = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createOrder() async {
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final api = PaymentApiClient();
      final token = (await OwnerAppScope.of(context).getAccessToken())!;
      _order = await api.createOrder(token, widget.bookingId);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _creating = false);
  }

  Future<void> _handlePay() async {
    if (_order == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认支付'),
        content: Text(
            '支付金额：¥${_order!.amount.toStringAsFixed(2)}\n\nTODO：对接微信/支付宝 SDK'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('支付渠道 SDK 待对接')),
      );
    }
  }

  Future<void> _requestRefund() async {
    if (_order == null) return;
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('申请退款'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            hintText: '请输入退款原因',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text),
            child: const Text('提交'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    try {
      final api = PaymentApiClient();
      final token = (await OwnerAppScope.of(context).getAccessToken())!;
      _order = await api.requestRefund(token, _order!.id, reason);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('退款申请失败: $e')));
      }
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: _creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
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
                Text(order.statusLabel,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(order.status))),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 金额明细
          _infoCard('金额明细', children: [
            _row('报价总价', '¥${order.amount.toStringAsFixed(2)}'),
            _row('平台服务费 (5%)', '¥${order.platformFee.toStringAsFixed(2)}',
                color: _textLight),
            const Divider(height: 16, color: _line),
            _row('应付金额', '¥${order.amount.toStringAsFixed(2)}',
                bold: true),
            _row('工人结算', '¥${order.workerSettlement.toStringAsFixed(2)}',
                color: _textLight, fontSize: 12),
          ]),

          const SizedBox(height: 12),

          // 订单信息
          _infoCard('订单信息', children: [
            _row('订单编号', order.id.substring(0, 8)),
            if (order.transactionId != null)
              _row('交易流水', order.transactionId!),
            if (order.paymentMethod != null)
              _row('支付方式', order.paymentMethod!),
            if (order.paidAt != null) _row('支付时间', order.paidAt!),
            if (order.refundedAt != null) _row('退款时间', order.refundedAt!),
          ]),

          // 退款入口
          if (order.isPaid) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _requestRefund,
                icon: const Icon(Icons.undo),
                label: const Text('申请退款'),
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
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _handlePay,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text('去支付  ¥${_order!.amount.toStringAsFixed(2)}'),
          ),
        ),
      ),
    );
  }

  Widget _statusIcon(String status) {
    return switch (status) {
      'PENDING' => Icon(Icons.hourglass_empty, size: 48, color: _warning),
      'PAID' => Icon(Icons.check_circle, size: 48, color: _success),
      'REFUNDED' => Icon(Icons.undo, size: 48, color: Colors.blue),
      'FAILED' => Icon(Icons.error, size: 48, color: _errorColor),
      _ => Icon(Icons.help_outline, size: 48, color: _textLight),
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'PENDING' => _warning,
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
          Text(title,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: _textDark)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {bool bold = false, Color? color, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: _textMid, fontSize: fontSize)),
          Text(value,
              style: TextStyle(
                  color: color ?? _textDark,
                  fontSize: fontSize,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }
}
