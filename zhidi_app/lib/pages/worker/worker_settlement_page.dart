import 'package:flutter/material.dart';

import '../../app/worker_app_scope.dart';
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

class WorkerSettlementPage extends StatefulWidget {
  const WorkerSettlementPage({super.key});

  @override
  State<WorkerSettlementPage> createState() => _WorkerSettlementPageState();
}

class _WorkerSettlementPageState extends State<WorkerSettlementPage> {
  List<SettlementModel> _items = const [];
  List<PaymentOrderModel> _pendingReceipts = const [];
  List<WarrantyRetentionModel> _warrantyRetentions = const [];
  bool _loading = true;
  String? _confirmingOrderId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = PaymentApiClient();
      final token = WorkerAppScope.of(context).getAccessToken()!;
      final results = await Future.wait([
        api.listSettlements(token),
        api.listOrders(token),
        api.listWarrantyRetentions(token),
      ]);
      _items = results[0] as List<SettlementModel>;
      _pendingReceipts = (results[1] as List<PaymentOrderModel>)
          .where((order) => order.isAwaitingWorkerReceipt)
          .toList();
      _warrantyRetentions = results[2] as List<WarrantyRetentionModel>;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _confirmReceipt(PaymentOrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认实际收到款项'),
        content: Text(
          '请先核对您的银行卡、微信、支付宝或现金，确认实际收到 ¥${order.amount.toStringAsFixed(2)} 后再操作。确认后将生成已收款记录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('尚未收到'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认已收到'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _confirmingOrderId = order.id;
      _error = null;
    });
    try {
      final token = WorkerAppScope.of(context).getAccessToken();
      if (token == null || token.isEmpty) throw Exception('登录已失效，请重新登录');
      await PaymentApiClient().confirmOfflineReceipt(token, order.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('收款已确认，已生成收款记录')));
      }
      await _loadList();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _confirmingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('结算'),
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('加载失败', style: TextStyle(color: _errorColor)),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _loadList, child: const Text('重试')),
                ],
              ),
            )
          : _items.isEmpty && _pendingReceipts.isEmpty
                && _warrantyRetentions.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 64,
                    color: _textLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无结算记录',
                    style: TextStyle(fontSize: 16, color: _textMid),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadList,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_pendingReceipts.isNotEmpty) ...[
                    Text(
                      '待确认收款',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._pendingReceipts.map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildPendingReceipt(order),
                      ),
                    ),
                  ],
                  if (_items.isNotEmpty) ...[
                    Text(
                      '收款记录',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildItem(item),
                      ),
                    ),
                  ],
                  if (_warrantyRetentions.isNotEmpty) ...[
                    Text(
                      '质保金',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._warrantyRetentions.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildWarrantyRetention(item),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPendingReceipt(PaymentOrderModel order) {
    final confirming = _confirmingOrderId == order.id;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '¥${order.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              Text(
                order.statusLabel,
                style: TextStyle(color: _primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '业主报告通过${order.offlinePaymentChannel ?? '线下方式'}付款。请核对实际到账，未到账不要确认。',
            style: TextStyle(fontSize: 13, color: _textMid, height: 1.5),
          ),
          if (order.paymentReference != null) ...[
            const SizedBox(height: 6),
            _detailRow('付款凭证', order.paymentReference!),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: confirming ? null : () => _confirmReceipt(order),
              child: confirming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('我已实际收到款项'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(SettlementModel item) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '¥${item.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              _statusChip(item),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _line),
          const SizedBox(height: 12),
          _detailRow('结算编号', item.id.substring(0, 8)),
          _detailRow('关联订单', item.paymentOrderId.substring(0, 8)),
          if (item.frozenReason != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _errorColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: _errorColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.frozenReason!,
                      style: TextStyle(color: _errorColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (item.settledAt != null) ...[
            const SizedBox(height: 8),
            _detailRow('结算时间', _formatTime(item.settledAt!)),
          ],
          const SizedBox(height: 4),
          _detailRow('创建时间', _formatTime(item.createdAt)),
        ],
      ),
    );
  }

  Widget _buildWarrantyRetention(WarrantyRetentionModel item) {
    final (color, icon) = switch (item.status) {
      'HELD' => (_warning, Icons.lock_clock_outlined),
      'RELEASED' => (_success, Icons.lock_open_outlined),
      'DEDUCTED' => (_errorColor, Icons.remove_circle_outline),
      _ => (_textLight, Icons.help_outline),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '¥${item.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      item.statusLabel,
                      style: TextStyle(color: color, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _line),
          const SizedBox(height: 12),
          _detailRow('剩余冻结', '¥${item.remainingAmount.toStringAsFixed(2)}'),
          _detailRow('已释放', '¥${item.releasedAmount.toStringAsFixed(2)}'),
          _detailRow('已扣减', '¥${item.deductedAmount.toStringAsFixed(2)}'),
          _detailRow('关联订单', item.paymentOrderId.substring(0, 8)),
          if (item.deductionReason != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _errorColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: _errorColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.deductionReason!,
                      style: TextStyle(color: _errorColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (item.releasedAt != null) ...[
            const SizedBox(height: 8),
            _detailRow('释放时间', _formatTime(item.releasedAt!)),
          ],
          const SizedBox(height: 4),
          _detailRow('创建时间', _formatTime(item.createdAt)),
        ],
      ),
    );
  }

  Widget _statusChip(SettlementModel item) {
    final (color, icon) = switch (item.status) {
      'PENDING' => (_warning, Icons.hourglass_empty),
      'SETTLEABLE' => (_primary, Icons.credit_card),
      'SETTLED' => (_success, Icons.check_circle),
      'FROZEN' => (_errorColor, Icons.block),
      _ => (_textLight, Icons.help_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(item.statusLabel, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: _textLight, fontSize: 13),
            textWidthBasis: TextWidthBasis.longestLine,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, style: TextStyle(color: _textMid, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
