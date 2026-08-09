import 'package:flutter/material.dart';

import '../../app/worker_app_scope.dart';
import '../../design/tokens.dart';
import '../../models/payment_models.dart';
import '../../services/payment_api_client.dart';
import '../../services/worker_quote_api_client.dart';
import '../shared/quote_detail_page.dart';

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
  const WorkerSettlementPage({
    super.key,
    this.paymentApi,
    this.quoteApi,
    this.initialPaymentOrderId,
  });

  final PaymentApiClient? paymentApi;
  final WorkerQuoteApiClient? quoteApi;
  final String? initialPaymentOrderId;

  @override
  State<WorkerSettlementPage> createState() => _WorkerSettlementPageState();
}

class _WorkerSettlementPageState extends State<WorkerSettlementPage> {
  List<SettlementModel> _items = const [];
  List<PaymentOrderModel> _pendingReceipts = const [];
  List<PaymentOrderModel> _paymentReviews = const [];
  List<WarrantyRetentionModel> _warrantyRetentions = const [];
  WorkerWarrantyAccountModel? _warrantyAccount;
  List<WorkerWarrantyContributionModel> _warrantyContributions = const [];
  Map<String, RemoteQuote> _quotesById = const {};
  PaymentOrderModel? _exactTargetOrder;
  bool _loading = true;
  String? _confirmingOrderId;
  String? _reportingContributionId;
  String? _error;
  bool _targetUnavailable = false;
  Object? _sessionStateIdentity;
  String? _sessionUserId;
  String? _sessionToken;
  bool _sessionInitialized = false;
  int _sessionGeneration = 0;
  int _loadGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = WorkerAppScope.of(context);
    final token = state.getAccessToken()?.trim();
    final userId = state.sessionUserId;
    final sessionChanged =
        !_sessionInitialized ||
        !identical(_sessionStateIdentity, state) ||
        _sessionUserId != userId ||
        _sessionToken != token;
    if (!sessionChanged) return;

    _sessionInitialized = true;
    _sessionStateIdentity = state;
    _sessionUserId = userId;
    _sessionToken = token;
    _sessionGeneration += 1;
    _loadGeneration += 1;
    _clearSessionData();
    if (token == null || token.isEmpty) {
      _loading = false;
      _error = '登录已失效，请重新登录';
      return;
    }
    _loadList();
  }

  Future<void> _loadList() async {
    final token = _sessionToken;
    final userId = _sessionUserId;
    final sessionGeneration = _sessionGeneration;
    if (token == null || token.isEmpty) {
      if (_isCurrentSession(sessionGeneration, token, userId)) {
        setState(() {
          _loading = false;
          _error = '登录已失效，请重新登录';
        });
      }
      return;
    }
    final loadGeneration = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
      _exactTargetOrder = null;
      _targetUnavailable = false;
    });
    try {
      final api = widget.paymentApi ?? PaymentApiClient();
      final targetOrderId = widget.initialPaymentOrderId?.trim();
      PaymentOrderModel? targetOrder;
      if (targetOrderId != null && targetOrderId.isNotEmpty) {
        try {
          final candidate = await api.getOrder(token, targetOrderId);
          if (!_isCurrentLoad(
            sessionGeneration,
            loadGeneration,
            token,
            userId,
          )) {
            return;
          }
          if (candidate.id != targetOrderId) {
            setState(() {
              _targetUnavailable = true;
              _loading = false;
            });
            return;
          }
          targetOrder = candidate;
        } on PaymentApiException catch (error) {
          if (!_isCurrentLoad(
            sessionGeneration,
            loadGeneration,
            token,
            userId,
          )) {
            return;
          }
          setState(() {
            if (error.isNotFound) {
              _targetUnavailable = true;
            } else {
              _error = '暂时无法打开订单，请稍后重试';
            }
            _loading = false;
          });
          return;
        } catch (_) {
          if (!_isCurrentLoad(
            sessionGeneration,
            loadGeneration,
            token,
            userId,
          )) {
            return;
          }
          setState(() {
            _error = '暂时无法打开订单，请稍后重试';
            _loading = false;
          });
          return;
        }
      }
      final results = await Future.wait([
        api.listSettlements(token),
        api.listOrders(token),
        api.listWarrantyRetentions(token),
      ]);
      if (!_isCurrentLoad(sessionGeneration, loadGeneration, token, userId)) {
        return;
      }
      final paymentOrders = List<PaymentOrderModel>.from(
        results[1] as List<PaymentOrderModel>,
      );
      if (targetOrder != null) {
        paymentOrders.removeWhere((order) => order.id == targetOrder!.id);
        paymentOrders.insert(0, targetOrder);
      }
      final items = results[0] as List<SettlementModel>;
      final pendingReceipts = paymentOrders
          .where(
            (order) =>
                order.isAwaitingWorkerReceipt ||
                (order.isSplitOfflineV2 &&
                    order.constructionPaymentStatus == 'REPORTED'),
          )
          .toList();
      final paymentReviews = paymentOrders
          .where(
            (order) =>
                order.isSplitOfflineV2 &&
                order.isConstructionConfirmed &&
                !order.isPaid,
          )
          .toList();
      final warrantyRetentions = results[2] as List<WarrantyRetentionModel>;
      WorkerWarrantyAccountModel? warrantyAccount;
      try {
        warrantyAccount = await api.getWorkerWarrantyAccount(token);
        if (!_isCurrentLoad(sessionGeneration, loadGeneration, token, userId)) {
          return;
        }
      } on PaymentApiException catch (error) {
        if (!_isCurrentLoad(sessionGeneration, loadGeneration, token, userId)) {
          return;
        }
        if (!error.isNotFound) rethrow;
      }
      var warrantyContributions = await api.listWorkerWarrantyContributions(
        token,
      );
      if (!_isCurrentLoad(sessionGeneration, loadGeneration, token, userId)) {
        return;
      }
      final hasOutstandingObligation = warrantyContributions.any(
        (item) =>
            item.status == 'DUE' ||
            item.status == 'REPORTED' ||
            item.status == 'REJECTED',
      );
      if (warrantyAccount?.status == 'TOP_UP_REQUIRED' &&
          !hasOutstandingObligation) {
        final obligation = await api.ensureWorkerWarrantyTopUpObligation(token);
        if (!_isCurrentLoad(sessionGeneration, loadGeneration, token, userId)) {
          return;
        }
        warrantyContributions = [
          obligation,
          ...warrantyContributions.where((item) => item.id != obligation.id),
        ];
        warrantyAccount = await api.getWorkerWarrantyAccount(token);
        if (!_isCurrentLoad(sessionGeneration, loadGeneration, token, userId)) {
          return;
        }
      }
      Map<String, RemoteQuote> quotesById;
      try {
        final quotes = await (widget.quoteApi ?? WorkerQuoteApiClient())
            .listWorkerQuotes(token);
        if (!_isCurrentLoad(sessionGeneration, loadGeneration, token, userId)) {
          return;
        }
        quotesById = {for (final quote in quotes) quote.id: quote};
      } catch (_) {
        if (!_isCurrentLoad(sessionGeneration, loadGeneration, token, userId)) {
          return;
        }
        quotesById = const {};
      }
      setState(() {
        _exactTargetOrder = targetOrder;
        _items = items;
        _pendingReceipts = pendingReceipts;
        _paymentReviews = paymentReviews;
        _warrantyRetentions = warrantyRetentions;
        _warrantyAccount = warrantyAccount;
        _warrantyContributions = warrantyContributions;
        _quotesById = quotesById;
        _loading = false;
      });
    } catch (e) {
      if (!_isCurrentLoad(sessionGeneration, loadGeneration, token, userId)) {
        return;
      }
      setState(() {
        _error = _friendlyError(e);
        _loading = false;
      });
    }
  }

  void _clearSessionData() {
    _items = const [];
    _pendingReceipts = const [];
    _paymentReviews = const [];
    _warrantyRetentions = const [];
    _warrantyAccount = null;
    _warrantyContributions = const [];
    _quotesById = const {};
    _exactTargetOrder = null;
    _loading = true;
    _confirmingOrderId = null;
    _reportingContributionId = null;
    _error = null;
    _targetUnavailable = false;
  }

  bool _isCurrentSession(
    int sessionGeneration,
    String? token,
    String? userId,
  ) =>
      mounted &&
      sessionGeneration == _sessionGeneration &&
      token == _sessionToken &&
      userId == _sessionUserId;

  bool _isCurrentLoad(
    int sessionGeneration,
    int loadGeneration,
    String token,
    String? userId,
  ) =>
      _isCurrentSession(sessionGeneration, token, userId) &&
      loadGeneration == _loadGeneration;

  Future<void> _confirmReceipt(PaymentOrderModel order) async {
    final sessionGeneration = _sessionGeneration;
    final token = _sessionToken;
    final userId = _sessionUserId;
    if (token == null || token.isEmpty) {
      if (_isCurrentSession(sessionGeneration, token, userId)) {
        setState(() => _error = '登录已失效，请重新登录');
      }
      return;
    }
    final isSplit = order.isSplitOfflineV2;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认收款信息'),
        content: Text(
          isSplit
              ? '请先核对报价明细和实际到账。本单工程款应全额收到 ¥${order.quoteAmount.toStringAsFixed(2)}，确认后将记录工程款到账状态。'
              : '请先核对业主付款信息与报价明细。工人可结算金额为 ¥${order.workerSettlement.toStringAsFixed(2)}，另有 ¥${order.warrantyRetention.toStringAsFixed(2)} 作为质保金冻结；确认后可结算金额将进入待提现记录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('暂不确认'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认无误'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !_isCurrentSession(sessionGeneration, token, userId)) {
      return;
    }
    setState(() {
      _confirmingOrderId = order.id;
      _error = null;
    });
    try {
      final api = widget.paymentApi ?? PaymentApiClient();
      if (isSplit) {
        await api.confirmConstructionReceipt(token, order.id);
      } else {
        await api.confirmOfflineReceipt(token, order.id);
      }
      if (!mounted || !_isCurrentSession(sessionGeneration, token, userId)) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSplit ? '已确认工程款到账，付款状态核验中' : '已确认收款信息，金额已进入待结算'),
        ),
      );
      await _loadList();
      if (!_isCurrentSession(sessionGeneration, token, userId)) {
        return;
      }
    } catch (e) {
      if (_isCurrentSession(sessionGeneration, token, userId)) {
        setState(() => _error = _friendlyError(e));
      }
    } finally {
      if (_isCurrentSession(sessionGeneration, token, userId)) {
        setState(() => _confirmingOrderId = null);
      }
    }
  }

  Future<void> _reportWarrantyContribution(
    WorkerWarrantyContributionModel contribution,
  ) async {
    final api = widget.paymentApi ?? PaymentApiClient();
    final sessionGeneration = _sessionGeneration;
    final token = _sessionToken;
    final userId = _sessionUserId;
    if (token == null || token.isEmpty) {
      if (_isCurrentSession(sessionGeneration, token, userId)) {
        setState(() => _error = '登录已失效，请重新登录');
      }
      return;
    }
    WorkerWarrantyPaymentInstructionsModel instructions;
    try {
      instructions = await api.getWorkerWarrantyPaymentInstructions(token);
    } catch (error) {
      if (_isCurrentSession(sessionGeneration, token, userId)) {
        setState(() => _error = _friendlyError(error));
      }
      return;
    }
    if (!mounted || !_isCurrentSession(sessionGeneration, token, userId)) {
      return;
    }
    var reference = '';
    String channel = 'WECHAT_TRANSFER';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('补充履约质保金'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本次应补充 ¥${contribution.amountDue.toStringAsFixed(2)}'),
                const SizedBox(height: 12),
                _detailRow('收款户名', instructions.accountName),
                _detailRow('开户银行', instructions.bankName),
                _detailRow('收款账号', instructions.bankAccount),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: channel,
                  decoration: const InputDecoration(labelText: '付款方式'),
                  items: const [
                    DropdownMenuItem(
                      value: 'WECHAT_TRANSFER',
                      child: Text('微信转账'),
                    ),
                    DropdownMenuItem(
                      value: 'BANK_TRANSFER',
                      child: Text('银行转账'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => channel = value);
                  },
                ),
                TextField(
                  onChanged: (value) => reference = value,
                  decoration: const InputDecoration(
                    labelText: '转账单号或凭证编号',
                    hintText: '请填写可核对的真实编号',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (reference.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('提交平台核验'),
            ),
          ],
        ),
      ),
    );
    reference = reference.trim();
    if (confirmed != true ||
        reference.isEmpty ||
        !_isCurrentSession(sessionGeneration, token, userId)) {
      return;
    }
    setState(() {
      _reportingContributionId = contribution.id;
      _error = null;
    });
    try {
      await api.reportWarrantyContribution(
        token,
        contribution.id,
        channel: channel,
        reference: reference,
      );
      if (!mounted || !_isCurrentSession(sessionGeneration, token, userId)) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('补充记录已提交，等待平台核验')));
      await _loadList();
      if (!_isCurrentSession(sessionGeneration, token, userId)) return;
    } catch (error) {
      if (_isCurrentSession(sessionGeneration, token, userId)) {
        setState(() => _error = _friendlyError(error));
      }
    } finally {
      if (_isCurrentSession(sessionGeneration, token, userId)) {
        setState(() => _reportingContributionId = null);
      }
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
          : _targetUnavailable
          ? const Center(child: Text('该订单已更新或不再可用'))
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('加载失败', style: TextStyle(color: _errorColor)),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _textMid, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _loadList, child: const Text('重试')),
                ],
              ),
            )
          : _items.isEmpty &&
                _pendingReceipts.isEmpty &&
                _paymentReviews.isEmpty &&
                _warrantyRetentions.isEmpty &&
                _warrantyAccount == null &&
                _exactTargetOrder == null
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
                  if (_showExactTargetSeparately) ...[
                    Text(
                      '通知对应订单',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildExactTarget(_exactTargetOrder!),
                    const SizedBox(height: 16),
                  ],
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
                  if (_paymentReviews.isNotEmpty) ...[
                    Text(
                      '付款核验进度',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._paymentReviews.map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildPaymentReview(order),
                      ),
                    ),
                  ],
                  if (_warrantyAccount != null) ...[
                    Text(
                      '履约质保金账户',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildWarrantyAccount(_warrantyAccount!),
                    const SizedBox(height: 16),
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

  bool get _showExactTargetSeparately {
    final target = _exactTargetOrder;
    if (target == null) return false;
    return !_pendingReceipts.any((order) => order.id == target.id) &&
        !_paymentReviews.any((order) => order.id == target.id);
  }

  Widget _buildExactTarget(PaymentOrderModel order) {
    final amount = order.isSplitOfflineV2
        ? order.quoteAmount
        : order.workerSettlement;
    return Container(
      key: ValueKey('worker-payment-target-${order.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _success.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '工程款 ¥${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
              ),
              Text(
                order.statusLabel,
                style: const TextStyle(
                  color: _success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '支付订单 ${order.id}',
            style: const TextStyle(fontSize: 12, color: _textMid),
          ),
          if (order.isConstructionConfirmed) ...[
            const SizedBox(height: 6),
            const Text(
              '工程款到账已确认',
              style: TextStyle(fontSize: 13, color: _success),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingReceipt(PaymentOrderModel order) {
    final confirming = _confirmingOrderId == order.id;
    final isSplit = order.isSplitOfflineV2;
    final quoteTotal = isSplit
        ? order.quoteAmount
        : order.amount - order.platformFee;
    return Container(
      key: ValueKey('worker-pending-receipt-${order.id}'),
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
                isSplit
                    ? '本单应收 ¥${order.quoteAmount.toStringAsFixed(2)}'
                    : '待结算 ¥${order.workerSettlement.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              Text(
                isSplit ? '待确认到账' : order.statusLabel,
                style: TextStyle(color: _primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isSplit
                ? '业主已报告通过${_channelLabel(order.constructionPaymentChannel)}支付工程款，请核对实际到账。'
                : '业主已报告通过${order.offlinePaymentChannel ?? '线下方式'}付款。请先查看报价与费用组成，核对无误后确认。',
            style: TextStyle(fontSize: 13, color: _textMid, height: 1.5),
          ),
          if ((isSplit
                  ? order.constructionPaymentReference
                  : order.paymentReference) !=
              null) ...[
            const SizedBox(height: 6),
            _detailRow(
              '付款凭证',
              (isSplit
                  ? order.constructionPaymentReference
                  : order.paymentReference)!,
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            '费用明细',
            style: TextStyle(fontWeight: FontWeight.w700, color: _textDark),
          ),
          const SizedBox(height: 6),
          _detailRow('报价清单总价', '¥${quoteTotal.toStringAsFixed(2)}'),
          if (isSplit) ...[
            _detailRow('本单工程款应收', '¥${order.quoteAmount.toStringAsFixed(2)}'),
          ] else ...[
            _detailRow(
              '可结算 90%',
              '¥${order.workerSettlement.toStringAsFixed(2)}',
            ),
            _detailRow(
              '质保金冻结 10%',
              '¥${order.warrantyRetention.toStringAsFixed(2)}',
            ),
          ],
          if (order.quoteId != null &&
              _quotesById.containsKey(order.quoteId)) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        QuoteDetailPage(quote: _quotesById[order.quoteId]!),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('查看报价明细'),
              ),
            ),
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
                  : const Text('查看无误，确认收款'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentReview(PaymentOrderModel order) {
    return Container(
      key: ValueKey('worker-payment-review-${order.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _warning.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '工程款 ¥${order.quoteAmount.toStringAsFixed(2)} 已确认到账',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '付款状态核验中。核验完成后，本单会进入收款记录并生成履约质保金补充义务。',
            style: TextStyle(fontSize: 13, color: _textMid, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildWarrantyAccount(WorkerWarrantyAccountModel account) {
    final contribution = _warrantyContributions
        .where((item) => item.status == 'DUE' || item.status == 'REJECTED')
        .firstOrNull;
    final reported = _warrantyContributions
        .where((item) => item.status == 'REPORTED')
        .firstOrNull;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: account.canAcceptNewJobs
              ? _success.withValues(alpha: 0.22)
              : _warning.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _accountAmount(
                  '有效余额',
                  account.effectiveBalance,
                  _textDark,
                ),
              ),
              Container(width: 1, height: 38, color: _line),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _accountAmount(
                    '待补金额',
                    account.outstandingAmount,
                    account.outstandingAmount > 0 ? _warning : _success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '目标上限 ¥${account.capAmount.toStringAsFixed(0)}。质保金与单笔工程款分开管理，不从业主支付给您的工程款中直接扣除。',
            style: const TextStyle(fontSize: 12, color: _textMid, height: 1.5),
          ),
          if (contribution != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _reportingContributionId == contribution.id
                    ? null
                    : () => _reportWarrantyContribution(contribution),
                icon: const Icon(Icons.account_balance_outlined),
                label: Text(
                  contribution.status == 'REJECTED' ? '重新补充质保金' : '补充质保金',
                ),
              ),
            ),
            if (contribution.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Text(
                '上次核验未通过：${contribution.rejectionReason}',
                style: const TextStyle(fontSize: 12, color: _errorColor),
              ),
            ],
          ] else if (reported != null) ...[
            const SizedBox(height: 12),
            const Text(
              '补充记录已提交，等待平台核验',
              style: TextStyle(color: _warning, fontWeight: FontWeight.w600),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              account.canAcceptNewJobs ? '账户状态正常，可继续接单' : '账户当前不可接新单，请联系平台核对',
              style: TextStyle(
                color: account.canAcceptNewJobs ? _success : _warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _accountAmount(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _textLight)),
        const SizedBox(height: 3),
        Text(
          '¥${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
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

  String _channelLabel(String? channel) => switch (channel) {
    'WECHAT_TRANSFER' => '微信转账',
    'BANK_TRANSFER' => '银行转账',
    null || '' => '线下方式',
    final value => value,
  };

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('WARRANTY_PAYMENT_INSTRUCTIONS_NOT_CONFIGURED')) {
      return '平台尚未配置质保金收款账户，请联系平台后再补充';
    }
    if (text.contains('WORKER_WARRANTY_TOP_UP_REQUIRED')) {
      return '履约质保金尚有待补充金额，请先完成补充';
    }
    return text.replaceFirst('Exception: ', '');
  }
}
