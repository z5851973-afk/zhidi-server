import 'package:flutter/material.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';

import '../../design/tokens.dart';
import '../../services/worker_quote_api_client.dart';
import '../../services/auth_api_client.dart';

class OwnerQuoteComparePage extends StatefulWidget {
  const OwnerQuoteComparePage({super.key, required this.serviceRequestId});

  final String serviceRequestId;

  @override
  State<OwnerQuoteComparePage> createState() => _OwnerQuoteComparePageState();
}

class _OwnerQuoteComparePageState extends State<OwnerQuoteComparePage> {
  final WorkerQuoteApiClient _api = WorkerQuoteApiClient();
  List<RemoteQuote> _quotes = const [];
  bool _loading = true;
  String? _error;
  bool _accepting = false;

  Future<String?> _getToken() async {
    final state = OwnerAppScope.of(context);
    final token = await state.getAccessToken();
    if (token == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录已过期，请重新登录')),
      );
    }
    return token;
  }

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _getToken();
      if (token == null) {
        setState(() {
          _loading = false;
          _error = '登录已过期';
        });
        return;
      }
      final quotes = await _api.listQuotesForServiceRequest(
        token,
        widget.serviceRequestId,
      );
      // Sort by total price ascending
      quotes.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
      if (mounted) {
        setState(() {
          _quotes = quotes;
          _loading = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e is AuthApiException ? e.message : '加载失败：$e';
        });
      }
    }
  }

  Future<void> _acceptQuote(RemoteQuote quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认选人'),
        content: Text(
          '确定选 ${quote.workerName ?? "该"} 师傅？选定后其他候选人的预约将自动关闭。',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ZdColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认选择'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _accepting = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      await _api.acceptQuote(token, quote.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已选定 ${quote.workerName ?? ""} 师傅'),
          ),
        );
        Navigator.pop(context);
      }
    } on AuthApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowest = _quotes.isNotEmpty ? _quotes.first.totalPrice : 0.0;

    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text('报价对比'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: ZdColors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      body: _accepting
          ? const Center(child: CircularProgressIndicator())
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadQuotes,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : _quotes.isEmpty
                      ? const Center(child: Text('暂无报价'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _quotes.length,
                          itemBuilder: (context, index) {
                            final quote = _quotes[index];
                            final isLowest = quote.totalPrice == lowest &&
                                _quotes.length > 1;
                            return _QuoteCard(
                              quote: quote,
                              isLowest: isLowest,
                              onSelect: () => _acceptQuote(quote),
                            );
                          },
                        ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.isLowest,
    required this.onSelect,
  });

  final RemoteQuote quote;
  final bool isLowest;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLowest ? ZdColors.success : const Color(0xFFF0E4D8),
          width: isLowest ? 2 : 1,
        ),
        boxShadow: isLowest
            ? [
                BoxShadow(
                  color: ZdColors.success.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    ZdColors.primary.withValues(alpha: 0.12),
                child: Text(
                  (quote.workerName ?? '师').isNotEmpty
                      ? (quote.workerName ?? '师')[0]
                      : '师',
                  style: const TextStyle(
                    color: ZdColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote.workerName ?? '未知师傅',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ZdColors.textPrimary,
                      ),
                    ),
                    if (isLowest)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              ZdColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '最低价',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ZdColors.success,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '¥${quote.totalPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isLowest
                      ? ZdColors.success
                      : ZdColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          if (quote.items.isNotEmpty) ...[
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1.5),
              },
              defaultVerticalAlignment:
                  TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                      ),
                    ),
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('项目',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ZdColors.textSecondary,
                          )),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('数量',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ZdColors.textSecondary,
                          )),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('单价',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ZdColors.textSecondary,
                          )),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('小计',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ZdColors.textSecondary,
                          )),
                    ),
                  ],
                ),
                ...quote.items.map(
                  (item) => TableRow(
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          item.name ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: ZdColors.textPrimary,
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${item.quantity ?? 0}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: ZdColors.textPrimary,
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '¥${(item.unitPrice ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: ZdColors.textSecondary,
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '¥${(item.subtotal ?? 0).toStringAsFixed(2)}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: ZdColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  '合计 ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ZdColors.textSecondary,
                  ),
                ),
                Text(
                  '¥${quote.totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isLowest
                        ? ZdColors.success
                        : ZdColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLowest
                    ? ZdColors.success
                    : ZdColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                '选择',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
