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
  bool _loading = true;
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
      _items = await api.listSettlements(token);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
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
                      TextButton(
                          onPressed: _loadList, child: const Text('重试')),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_balance_wallet,
                              size: 64, color: _textLight),
                          const SizedBox(height: 16),
                          Text('暂无结算记录',
                              style:
                                  TextStyle(fontSize: 16, color: _textMid)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadList,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => _buildItem(_items[i]),
                      ),
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
              Text('¥${item.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _textDark)),
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
                color: _errorColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: _errorColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(item.frozenReason!,
                        style: TextStyle(color: _errorColor, fontSize: 13)),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(item.statusLabel,
              style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(color: _textLight, fontSize: 13),
              textWidthBasis: TextWidthBasis.longestLine),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                style: TextStyle(color: _textMid, fontSize: 13)),
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
