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
const _success = ZdColors.success;
const _errorColor = ZdColors.error;

class OwnerAfterSalePage extends StatefulWidget {
  const OwnerAfterSalePage({super.key, this.bookingId});

  final String? bookingId;

  @override
  State<OwnerAfterSalePage> createState() => _OwnerAfterSalePageState();
}

class _OwnerAfterSalePageState extends State<OwnerAfterSalePage> {
  List<AfterSaleModel> _items = const [];
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
      final token = (await OwnerAppScope.of(context).getAccessToken())!;
      _items = await api.listAfterSales(token);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createAfterSale() async {
    final type = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择售后类型'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'REFUND'),
            child: const Text('退款'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'COMPLAINT'),
            child: const Text('投诉'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'DISPUTE'),
            child: const Text('争议'),
          ),
        ],
      ),
    );
    if (type == null) return;

    final reasonCtrl = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('创建${_typeLabel(type)}申请'),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(
            hintText: '请描述${_typeLabel(type)}原因',
            border: const OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, {
              'type': type,
              'reason': reasonCtrl.text,
            }),
            child: const Text('提交'),
          ),
        ],
      ),
    );
    if (result == null || result['reason']!.isEmpty) return;

    try {
      final api = PaymentApiClient();
      final token = (await OwnerAppScope.of(context).getAccessToken())!;
      await api.createAfterSale(token,
        bookingId: widget.bookingId ?? '',
        type: result['type']!,
        reason: result['reason']!,
      );
      await _loadList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('创建失败: $e')));
      }
    }
  }

  String _typeLabel(String type) {
    return switch (type) {
      'REFUND' => '退款',
      'COMPLAINT' => '投诉',
      'DISPUTE' => '争议',
      _ => type,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('售后'),
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
                          Icon(Icons.support_agent,
                              size: 64, color: _textLight),
                          const SizedBox(height: 16),
                          Text('暂无售后记录',
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
      floatingActionButton: widget.bookingId != null
          ? FloatingActionButton.extended(
              onPressed: _createAfterSale,
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('申请售后'),
            )
          : null,
    );
  }

  Widget _buildItem(AfterSaleModel item) {
    return GestureDetector(
      onTap: () => _showDetail(item),
      child: Container(
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusBadgeColor(item.type),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(item.typeLabel,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(item.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(item.statusLabel,
                      style: TextStyle(
                          color: _statusColor(item.status), fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(item.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _textDark)),
            if (item.resolution != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('处理结果：',
                        style: TextStyle(
                            color: _textMid,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    Expanded(
                      child: Text(item.resolution!,
                          style: TextStyle(color: _textDark, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(_formatTime(item.createdAt),
                style: TextStyle(color: _textLight, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showDetail(AfterSaleModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _textLight, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _badge(item.typeLabel, _statusBadgeColor(item.type)),
                const SizedBox(width: 8),
                _badge(item.statusLabel, _statusColor(item.status)),
              ],
            ),
            const SizedBox(height: 16),
            Text('原因',
                style: TextStyle(
                    color: _textMid, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(item.reason, style: TextStyle(color: _textDark, fontSize: 15)),
            if (item.resolution != null) ...[
              const SizedBox(height: 16),
              Text('处理结果',
                  style: TextStyle(
                      color: _textMid,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(item.resolution!,
                  style: TextStyle(color: _textDark, fontSize: 15)),
            ],
            const SizedBox(height: 16),
            Text('创建时间: ${_formatTime(item.createdAt)}',
                style: TextStyle(color: _textLight, fontSize: 13)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child:
          Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Color _statusBadgeColor(String type) {
    return switch (type) {
      'REFUND' => Colors.orange,
      'COMPLAINT' => _errorColor,
      'DISPUTE' => Colors.purple,
      _ => _primary,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'OPEN' => Colors.orange,
      'PLATFORM_PROCESSING' => _primary,
      'RESOLVED' => _success,
      'CLOSED' => _textLight,
      _ => _textDark,
    };
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
