import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';

import '../../design/tokens.dart';
import '../../services/worker_quote_api_client.dart';
import '../../services/auth_api_client.dart';

double _platformFeeFor(double quoteTotal) =>
    double.parse((quoteTotal * 0.10).toStringAsFixed(2));

class OwnerQuoteComparePage extends StatefulWidget {
  const OwnerQuoteComparePage({
    super.key,
    required this.serviceRequestId,
    this.quoteApi,
    this.workerNamesById = const {},
  });

  final String serviceRequestId;
  final WorkerQuoteApiClient? quoteApi;
  final Map<String, String> workerNamesById;

  @override
  State<OwnerQuoteComparePage> createState() => _OwnerQuoteComparePageState();
}

class _OwnerQuoteComparePageState extends State<OwnerQuoteComparePage> {
  List<RemoteQuote> _quotes = const [];
  bool _loading = true;
  String? _error;
  bool _accepting = false;
  bool _loaded = false;
  bool _selectionAcknowledged = false;

  WorkerQuoteApiClient get _api => widget.quoteApi ?? WorkerQuoteApiClient();

  Future<String?> _getToken() async {
    final state = OwnerAppScope.of(context);
    final token = await state.getAccessToken();
    if (token == null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录已过期，请重新登录')));
    }
    return token;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
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
    final workerName = _displayWorkerName(quote);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => QuoteSelectionConfirmationDialog(
        workerName: workerName,
        totalPrice: quote.totalPrice,
      ),
    );

    if (confirmed != true) return;

    setState(() => _accepting = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      await _api.acceptQuote(token, quote.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已选定 $workerName 师傅')));
        Navigator.pop(context, true);
      }
    } on AuthApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  String _displayWorkerName(RemoteQuote quote) {
    final fromQuote = quote.workerName?.trim();
    if (fromQuote != null && fromQuote.isNotEmpty) return fromQuote;
    final fromCandidate = widget.workerNamesById[quote.workerUserId]?.trim();
    if (fromCandidate != null && fromCandidate.isNotEmpty) {
      return fromCandidate;
    }
    return '该师傅';
  }

  @override
  Widget build(BuildContext context) {
    final lowest = _quotes.isNotEmpty ? _quotes.first.totalPrice : 0.0;

    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text('报价清单'),
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
                  Text(_error!, style: const TextStyle(color: Colors.red)),
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                if (_quotes.length > 1)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ZdColors.warningSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '多位师傅已报价，你可以逐张核对清单后再最终选人。',
                      style: TextStyle(
                        fontSize: 13,
                        color: ZdColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ..._quotes.map((quote) {
                  final isLowest =
                      quote.totalPrice == lowest && _quotes.length > 1;
                  return _QuoteCard(
                    quote: quote,
                    workerName: _displayWorkerName(quote),
                    isLowest: isLowest,
                    canSelect: _selectionAcknowledged,
                    onSelect: () => _acceptQuote(quote),
                  );
                }),
                _SelectionAgreementCard(
                  value: _selectionAcknowledged,
                  onChanged: (value) {
                    setState(() => _selectionAcknowledged = value);
                  },
                ),
              ],
            ),
    );
  }
}

class QuoteSelectionConfirmationDialog extends StatefulWidget {
  const QuoteSelectionConfirmationDialog({
    super.key,
    required this.workerName,
    required this.totalPrice,
  });

  final String workerName;
  final double totalPrice;

  @override
  State<QuoteSelectionConfirmationDialog> createState() =>
      _QuoteSelectionConfirmationDialogState();
}

class _QuoteSelectionConfirmationDialogState
    extends State<QuoteSelectionConfirmationDialog> {
  Timer? _holdTimer;
  bool _acknowledged = false;
  bool _holding = false;

  void _startHold(PointerDownEvent event) {
    if (!_acknowledged || _holdTimer != null) return;
    setState(() => _holding = true);
    _holdTimer = Timer(const Duration(seconds: 2), () {
      _holdTimer = null;
      if (mounted) Navigator.pop(context, true);
    });
  }

  void _cancelHold([PointerEvent? event]) {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (mounted && _holding) setState(() => _holding = false);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platformFee = _platformFeeFor(widget.totalPrice);
    final payableTotal = widget.totalPrice + platformFee;
    return AlertDialog(
      title: const Text('确认选人'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('师傅：${widget.workerName}'),
          const SizedBox(height: 6),
          _AmountRow(label: '报价总价', amount: widget.totalPrice),
          const SizedBox(height: 6),
          _AmountRow(label: '平台服务费（10%）', amount: platformFee),
          const Divider(height: 18),
          _AmountRow(label: '业主应付', amount: payableTotal, emphasized: true),
          const SizedBox(height: 12),
          const Text(
            '平台服务费在师傅报价之外另行收取，不从师傅报价中扣除。',
            style: TextStyle(fontSize: 13, color: ZdColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            '本次操作只选择师傅和报价，不会发起付款或划转资金。',
            style: TextStyle(fontSize: 13, color: ZdColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            '选定后，其他候选预约和待处理报价将关闭。',
            style: TextStyle(fontSize: 13, color: ZdColors.textSecondary),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _acknowledged,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('我已核对师傅、报价明细和总价'),
            onChanged: (value) {
              _cancelHold();
              setState(() => _acknowledged = value == true);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        Listener(
          onPointerDown: _startHold,
          onPointerUp: _cancelHold,
          onPointerCancel: _cancelHold,
          child: ElevatedButton(
            key: const Key('quote-hold-confirm'),
            onPressed: _acknowledged ? () {} : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: ZdColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(_holding ? '继续按住…' : '按住 2 秒确认选择'),
          ),
        ),
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.workerName,
    required this.isLowest,
    required this.canSelect,
    required this.onSelect,
  });

  final RemoteQuote quote;
  final String workerName;
  final bool isLowest;
  final bool canSelect;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final laborItems = quote.items.where((item) => !item.isMaterial).toList();
    final materialItems = quote.items.where((item) => item.isMaterial).toList();
    final platformFee = _platformFeeFor(quote.totalPrice);
    final payableTotal = quote.totalPrice + platformFee;
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
                backgroundColor: ZdColors.primary.withValues(alpha: 0.12),
                child: Text(
                  workerName.isNotEmpty ? workerName[0] : '师',
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
                      workerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ZdColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '报价清单 · 按实际测量后结算',
                      style: TextStyle(
                        fontSize: 12,
                        color: ZdColors.textSecondary,
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
                          color: ZdColors.success.withValues(alpha: 0.1),
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
                  color: isLowest ? ZdColors.success : ZdColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          if (quote.items.isNotEmpty) ...[
            if (laborItems.isNotEmpty)
              _QuoteItemsSection(title: '人工明细', items: laborItems),
            if (materialItems.isNotEmpty) ...[
              if (laborItems.isNotEmpty) const SizedBox(height: 12),
              _QuoteItemsSection(title: '材料明细', items: materialItems),
            ],
            const Divider(height: 16),
            _AmountRow(label: '报价总价', amount: quote.totalPrice),
            const SizedBox(height: 6),
            _AmountRow(label: '平台服务费（10%）', amount: platformFee),
            const Divider(height: 16),
            _AmountRow(
              label: '业主应付',
              amount: payableTotal,
              emphasized: true,
              amountColor: isLowest ? ZdColors.success : ZdColors.primary,
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSelect ? onSelect : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLowest ? ZdColors.success : ZdColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                '确认选择该师傅',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteItemsSection extends StatelessWidget {
  const _QuoteItemsSection({required this.title, required this.items});

  final String title;
  final List<RemoteQuoteItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: ZdColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2.5),
            1: FlexColumnWidth(1.25),
            2: FlexColumnWidth(1.25),
            3: FlexColumnWidth(1.5),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            const TableRow(
              children: [
                _QuoteTableHeader('项目'),
                _QuoteTableHeader('单价'),
                _QuoteTableHeader('数量'),
                _QuoteTableHeader('小计', alignEnd: true),
              ],
            ),
            ...items.map(
              (item) => TableRow(
                children: [
                  _QuoteTableCell(item.name ?? ''),
                  _QuoteTableCell(
                    '¥${(item.unitPrice ?? 0).toStringAsFixed(0)}',
                    secondary: true,
                  ),
                  _QuoteTableCell(
                    '${(item.quantity ?? 0).toStringAsFixed(0)}${item.unit ?? ''}',
                  ),
                  _QuoteTableCell(
                    '¥${(item.subtotal ?? 0).toStringAsFixed(2)}',
                    alignEnd: true,
                    bold: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuoteTableHeader extends StatelessWidget {
  const _QuoteTableHeader(this.text, {this.alignEnd = false});

  final String text;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: ZdColors.textSecondary,
      ),
    ),
  );
}

class _QuoteTableCell extends StatelessWidget {
  const _QuoteTableCell(
    this.text, {
    this.secondary = false,
    this.alignEnd = false,
    this.bold = false,
  });

  final String text;
  final bool secondary;
  final bool alignEnd;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(
      text,
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        color: secondary ? ZdColors.textSecondary : ZdColors.textPrimary,
      ),
    ),
  );
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
    this.amountColor,
  });

  final String label;
  final double amount;
  final bool emphasized;
  final Color? amountColor;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: emphasized ? 15 : 13,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            color: emphasized ? ZdColors.textPrimary : ZdColors.textSecondary,
          ),
        ),
      ),
      Text(
        '¥${amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: emphasized ? 19 : 14,
          fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
          color: amountColor ?? ZdColors.textPrimary,
        ),
      ),
    ],
  );
}

class _SelectionAgreementCard extends StatelessWidget {
  const _SelectionAgreementCard({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0E4D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选人确认',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: ZdColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '确认后将选定该师傅和对应报价。此操作不会发起付款或划转资金。',
            style: TextStyle(fontSize: 14, color: ZdColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: value,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                '我已核对师傅、报价明细和总价',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ZdColors.textPrimary,
                ),
              ),
              onChanged: (checked) => onChanged(checked == true),
            ),
          ),
          const Text(
            '确认后仍会弹出二次核对，需要长按 2 秒，防止误触。',
            style: TextStyle(fontSize: 12, color: ZdColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
