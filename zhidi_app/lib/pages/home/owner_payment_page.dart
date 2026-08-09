import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../design/tokens.dart';
import '../../models/payment_models.dart';
import '../../services/payment_api_client.dart';
import '../../services/worker_quote_api_client.dart';
import 'owner_after_sale_page.dart';
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

class OwnerPaymentPage extends StatefulWidget {
  const OwnerPaymentPage({
    super.key,
    required this.bookingId,
    this.initialPaymentOrderId,
    this.paymentApi,
    this.quoteApi,
  });

  final String bookingId;
  final String? initialPaymentOrderId;
  final PaymentApiClient? paymentApi;
  final WorkerQuoteApiClient? quoteApi;

  @override
  State<OwnerPaymentPage> createState() => _OwnerPaymentPageState();
}

class _OwnerPaymentPageState extends State<OwnerPaymentPage> {
  PaymentOrderModel? _order;
  bool _loading = true;
  bool _creating = false;
  bool _reporting = false;
  String? _error;
  String? _instructionError;
  bool _loaded = false;
  bool _targetUnavailable = false;
  bool _targetTemporarilyUnavailable = false;
  bool _afterSaleEligible = false;
  OfflinePaymentInstructionsModel? _instructions;
  String _constructionChannel = '银行卡转账';
  String _platformFeeChannel = '对公转账';
  final _constructionReferenceController = TextEditingController();
  final _platformFeeReferenceController = TextEditingController();
  final _splitNoteController = TextEditingController();

  @override
  void dispose() {
    _constructionReferenceController.dispose();
    _platformFeeReferenceController.dispose();
    _splitNoteController.dispose();
    super.dispose();
  }

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
      _targetUnavailable = false;
      _targetTemporarilyUnavailable = false;
      _afterSaleEligible = false;
    });
    try {
      final api = widget.paymentApi ?? PaymentApiClient();
      final token = (await OwnerAppScope.of(context).getAccessToken())!;
      final targetOrderId = widget.initialPaymentOrderId?.trim();
      if (targetOrderId != null && targetOrderId.isNotEmpty) {
        try {
          final targetOrder = await api.getOrder(token, targetOrderId);
          if (targetOrder.id != targetOrderId ||
              targetOrder.bookingId != widget.bookingId) {
            _order = null;
            _targetUnavailable = true;
          } else {
            _order = targetOrder;
            _targetUnavailable = false;
          }
        } on PaymentApiException catch (error) {
          _order = null;
          if (error.isNotFound) {
            _targetUnavailable = true;
          } else {
            _targetTemporarilyUnavailable = true;
            _error = '暂时无法打开订单，请稍后重试';
          }
        } catch (_) {
          _order = null;
          _targetTemporarilyUnavailable = true;
          _error = '暂时无法打开订单，请稍后重试';
        }
      } else {
        final orders = await api.listOrders(token);
        _order = orders.cast<PaymentOrderModel?>().firstWhere(
          (o) => o?.bookingId == widget.bookingId,
          orElse: () => null,
        );
      }
      if (_order?.isSplitOfflineV2 == true) {
        await _loadSplitInstructions(api, token, _order!.id);
      }
      await _loadAfterSaleEligibility(api, token);
    } catch (e) {
      _order = null;
      if (widget.initialPaymentOrderId?.trim().isNotEmpty == true) {
        _targetTemporarilyUnavailable = true;
        _error = '暂时无法打开订单，请稍后重试';
      } else {
        _error = e.toString();
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createOrder() async {
    setState(() {
      _creating = true;
      _error = null;
      _afterSaleEligible = false;
    });
    try {
      final api = widget.paymentApi ?? PaymentApiClient();
      final token = (await OwnerAppScope.of(context).getAccessToken())!;
      _order = await api.createOrder(token, widget.bookingId);
      if (_order!.isSplitOfflineV2) {
        await _loadSplitInstructions(api, token, _order!.id);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _creating = false);
  }

  Future<void> _loadSplitInstructions(
    PaymentApiClient api,
    String token,
    String orderId,
  ) async {
    try {
      _instructions = await api.getOfflinePaymentInstructions(token, orderId);
      _instructionError = null;
    } catch (error) {
      _instructions = null;
      _instructionError = _friendlyError(error);
    }
  }

  Future<void> _loadAfterSaleEligibility(
    PaymentApiClient api,
    String token,
  ) async {
    _afterSaleEligible = false;
    if (_order?.isPaid != true) return;
    try {
      final context = await api.getAfterSaleBookingContext(
        token,
        widget.bookingId,
      );
      _afterSaleEligible =
          context.bookingStatus == 'COMPLETED' &&
          context.paymentStatus == 'PAID';
    } catch (_) {
      _afterSaleEligible = false;
    }
  }

  Future<void> _reportSplitOfflinePayments() async {
    final order = _order!;
    final reportConstruction = order.canReportConstructionPayment;
    final reportPlatformFee = order.canReportPlatformFee;
    final constructionReference = _constructionReferenceController.text.trim();
    final platformReference = _platformFeeReferenceController.text.trim();
    if (!reportConstruction && !reportPlatformFee) return;
    if (reportConstruction && constructionReference.isEmpty) {
      setState(() => _error = '请填写工程款交易参考号');
      return;
    }
    if (reportPlatformFee && platformReference.isEmpty) {
      setState(() => _error = '请填写平台服务费交易参考号');
      return;
    }
    final instructions = _instructions;
    if (instructions == null) {
      setState(() => _error = '平台收款账户配置中，请稍后再试');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          reportConstruction && reportPlatformFee
              ? '再次核对两笔付款'
              : reportConstruction
              ? '核对工程款付款信息'
              : '核对平台服务费付款信息',
        ),
        content: Text(
          '${reportConstruction ? '工程款 ¥${instructions.constructionAmount.toStringAsFixed(2)} 已支付给${instructions.workerName}\n' : ''}'
          '${reportPlatformFee ? '平台服务费 ¥${instructions.platformFeeAmount.toStringAsFixed(2)} 已支付给${instructions.companyAccountName}\n' : ''}\n'
          '请确认收款对象和金额无误。',
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('返回核对'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认提交核验'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _reporting = true;
      _error = null;
    });
    try {
      final token = await OwnerAppScope.of(context).getAccessToken();
      if (token == null || token.isEmpty) throw Exception('登录已失效，请重新登录');
      _order = await (widget.paymentApi ?? PaymentApiClient())
          .reportSplitOfflinePayments(
            token,
            _order!.id,
            constructionChannel: reportConstruction
                ? _constructionChannel
                : null,
            constructionReference: reportConstruction
                ? constructionReference
                : null,
            platformFeeChannel: reportPlatformFee ? _platformFeeChannel : null,
            platformFeeReference: reportPlatformFee ? platformReference : null,
            note: _splitNoteController.text.trim().isEmpty
                ? null
                : _splitNoteController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reportConstruction && reportPlatformFee
                  ? '两笔付款信息已提交核验'
                  : reportConstruction
                  ? '工程款信息已提交核验'
                  : '平台服务费信息已提交核验',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
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
      _order = await (widget.paymentApi ?? PaymentApiClient())
          .reportOfflinePayment(
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

  Future<void> _openQuoteDetails() async {
    final order = _order!;
    try {
      final token = await OwnerAppScope.of(context).getAccessToken();
      if (token == null || token.isEmpty) throw Exception('登录已失效，请重新登录');
      final quotes = await (widget.quoteApi ?? WorkerQuoteApiClient())
          .listQuotesForBooking(token, widget.bookingId);
      final quote = quotes.cast<RemoteQuote?>().firstWhere(
        (item) => item?.id == order.quoteId,
        orElse: () => null,
      );
      if (quote == null) throw Exception('未找到已确认的报价单');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QuoteDetailPage(quote: quote)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('报价明细加载失败：$error')));
    }
  }

  void _openAfterSale() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerAfterSalePage(bookingId: _order!.bookingId),
      ),
    );
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
      bottomNavigationBar:
          _order != null &&
              (_order!.isPending ||
                  (_order!.isSplitOfflineV2 &&
                      _order!.status == 'PARTIALLY_REPORTED' &&
                      _order!.hasReportableSplitPaymentComponent))
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildNoOrder() {
    if (_targetUnavailable) {
      return const Center(child: Text('该订单已更新或不再可用'));
    }
    if (_targetTemporarilyUnavailable) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('暂时无法打开订单，请稍后重试'),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadOrder, child: const Text('重试')),
          ],
        ),
      );
    }
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
    final quoteTotal = order.isSplitOfflineV2
        ? order.quoteAmount
        : order.amount - order.platformFee;
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
              _row('报价清单总价', '¥${quoteTotal.toStringAsFixed(2)}'),
              _row(
                '平台服务费（10%）',
                '¥${order.platformFee.toStringAsFixed(2)}',
                color: _textLight,
              ),
              const Divider(height: 16, color: _line),
              _row('应付金额', '¥${order.amount.toStringAsFixed(2)}', bold: true),
              if (order.quoteId != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openQuoteDetails,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('查看报价明细'),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          if (order.isSplitOfflineV2) ...[
            ..._buildSplitPaymentCards(order),
            const SizedBox(height: 12),
          ],

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
              if (order.isSplitOfflineV2) ...[
                _row(
                  '工程款状态',
                  _componentStatus(order.constructionPaymentStatus),
                ),
                _row('平台服务费状态', _componentStatus(order.platformFeeStatus)),
              ],
              if (order.workerConfirmedReceivedAt != null)
                _row('工人确认收款', order.workerConfirmedReceivedAt!),
              if (order.paidAt != null) _row('支付时间', order.paidAt!),
              if (order.refundedAt != null) _row('退款时间', order.refundedAt!),
            ],
          ),

          const SizedBox(height: 12),
          _infoCard(
            '线下付款与人工确认',
            children: [
              Text(
                order.isSplitOfflineV2
                    ? '当前采用线下付款与人工确认：工程款由业主直接支付给师傅，平台服务费单独支付到知底公司账户。工程款由师傅确认到账，服务费由平台人工核验；本页面只提交付款信息，不会直接划转资金。'
                    : '应付金额由工人报价清单总价与 10% 平台服务费组成。当前采用线下付款与人工确认：业主提交付款信息后，由师傅确认实际到账；本页面不会直接划转资金。',
                style: const TextStyle(
                  fontSize: 13,
                  color: _textMid,
                  height: 1.5,
                ),
              ),
            ],
          ),

          // 订单绑定的人工售后入口
          if (_afterSaleEligible) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openAfterSale,
                icon: const Icon(Icons.support_agent_outlined),
                label: const Text('申请售后（人工处理）'),
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
    final split = _order!.isSplitOfflineV2;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (split) ...[
              Text(
                '应付合计 ¥${_order!.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: _textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _reporting || (split && _instructions == null)
                    ? null
                    : split
                    ? _reportSplitOfflinePayments
                    : _reportOfflinePayment,
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
                    : Text(
                        split
                            ? _splitSubmitLabel(_order!)
                            : '我已线下付款  ¥${_order!.amount.toStringAsFixed(2)}',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSplitPaymentCards(PaymentOrderModel order) {
    final instructions = _instructions;
    if (instructions == null) {
      return [
        _infoCard(
          '付款账户',
          children: [
            Text(
              _instructionError ?? '正在读取付款账户…',
              style: TextStyle(
                color: _instructionError == null ? _textMid : _errorColor,
                height: 1.5,
              ),
            ),
            if (_instructionError != null) ...[
              const SizedBox(height: 8),
              const Text(
                '平台收款账户配置中，请稍后再试。当前不会改变订单付款状态。',
                style: TextStyle(color: _textMid, fontSize: 13),
              ),
            ],
          ],
        ),
      ];
    }
    final cards = <Widget>[];
    if (order.canReportConstructionPayment) {
      cards.add(
        _infoCard(
          '支付工程款给${instructions.workerName}',
          children: [
            _row(
              '工程款（报价全额）',
              '¥${instructions.constructionAmount.toStringAsFixed(2)}',
              bold: true,
            ),
            const Text(
              '请先在应用内联系师傅确认其本人收款方式，平台不保存或展示未经核验的工人银行卡。',
              style: TextStyle(fontSize: 13, color: _textMid, height: 1.5),
            ),
            const SizedBox(height: 10),
            _channelField(
              value: _constructionChannel,
              label: '工程款付款方式',
              items: const ['银行卡转账', '微信转账', '支付宝转账', '现金'],
              onChanged: (value) =>
                  setState(() => _constructionChannel = value),
            ),
            TextField(
              key: const Key('construction-payment-reference'),
              controller: _constructionReferenceController,
              maxLength: 128,
              decoration: const InputDecoration(
                labelText: '工程款交易参考号',
                hintText: '转账单号或双方约定凭证',
              ),
            ),
            if (!order.canReportPlatformFee) _splitNoteField(),
          ],
        ),
      );
    } else {
      cards.add(
        _readOnlyPaymentComponentCard(
          title: '工程款付款记录',
          amountLabel: '工程款（报价全额）',
          amount: instructions.constructionAmount,
          status: order.constructionPaymentStatus,
          message: order.constructionPaymentStatus == 'CONFIRMED'
              ? '已确认的工程款不需要重新转账'
              : '工程款已提交核验，请勿重复转账',
        ),
      );
    }
    cards.add(const SizedBox(height: 12));
    if (order.canReportPlatformFee) {
      cards.add(
        _infoCard(
          '支付平台服务费给知底',
          children: [
            _row(
              '平台服务费（10%）',
              '¥${instructions.platformFeeAmount.toStringAsFixed(2)}',
              bold: true,
            ),
            _row('收款户名', instructions.companyAccountName),
            _row('开户银行', instructions.companyBankName),
            _row('收款账号', instructions.companyBankAccount),
            if (order.platformFeeStatus == 'REJECTED' &&
                order.platformFeeRejectionReason != null)
              _row('上次驳回原因', order.platformFeeRejectionReason!),
            const SizedBox(height: 10),
            _channelField(
              value: _platformFeeChannel,
              label: '平台服务费付款方式',
              items: const ['对公转账', '银行柜台转账'],
              onChanged: (value) => setState(() => _platformFeeChannel = value),
            ),
            TextField(
              key: const Key('platform-fee-reference'),
              controller: _platformFeeReferenceController,
              maxLength: 128,
              decoration: const InputDecoration(
                labelText: '平台服务费交易参考号',
                hintText: '对公转账流水号',
              ),
            ),
            _splitNoteField(),
          ],
        ),
      );
    } else {
      cards.add(
        _readOnlyPaymentComponentCard(
          title: '平台服务费付款记录',
          amountLabel: '平台服务费（10%）',
          amount: instructions.platformFeeAmount,
          status: order.platformFeeStatus,
          message: order.platformFeeStatus == 'VERIFIED'
              ? '已核验的平台服务费不需要重新转账'
              : '平台服务费已提交核验，请勿重复转账',
        ),
      );
    }
    return cards;
  }

  Widget _splitNoteField() => TextField(
    controller: _splitNoteController,
    maxLength: 300,
    decoration: const InputDecoration(labelText: '备注（选填）'),
  );

  Widget _readOnlyPaymentComponentCard({
    required String title,
    required String amountLabel,
    required double amount,
    required String status,
    required String message,
  }) => _infoCard(
    title,
    children: [
      _row(amountLabel, '¥${amount.toStringAsFixed(2)}', bold: true),
      _row('当前状态', _componentStatus(status)),
      const SizedBox(height: 8),
      Text(message, style: const TextStyle(color: _textMid, height: 1.5)),
    ],
  );

  String _splitSubmitLabel(PaymentOrderModel order) {
    if (order.canReportConstructionPayment && order.canReportPlatformFee) {
      return '提交付款核验';
    }
    if (order.canReportConstructionPayment) {
      return order.constructionPaymentStatus == 'REJECTED'
          ? '重新提交工程款核验'
          : '提交工程款核验';
    }
    return order.platformFeeStatus == 'REJECTED' ? '重新提交平台服务费核验' : '提交平台服务费核验';
  }

  Widget _channelField({
    required String value,
    required String label,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  String _componentStatus(String status) => switch (status) {
    'NOT_REPORTED' => '未报备',
    'REPORTED' => '核验中',
    'CONFIRMED' => '师傅已确认',
    'VERIFIED' => '平台已核验',
    'REJECTED' => '已驳回',
    _ => status,
  };

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('OFFLINE_PAYMENT_INSTRUCTIONS_NOT_CONFIGURED')) {
      return '平台收款账户配置中，请稍后再试';
    }
    if (text.contains('NETWORK_UNAVAILABLE')) return '网络不可用，请检查网络后重试';
    return text.replaceFirst('Exception: ', '');
  }

  Widget _statusIcon(String status) {
    return switch (status) {
      'PENDING' => Icon(Icons.hourglass_empty, size: 48, color: _warning),
      'OWNER_REPORTED_PAID' => Icon(
        Icons.pending_actions,
        size: 48,
        color: _primary,
      ),
      'PARTIALLY_REPORTED' => Icon(
        Icons.pending_actions,
        size: 48,
        color: _warning,
      ),
      'UNDER_REVIEW' => Icon(
        Icons.fact_check_outlined,
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
      'PARTIALLY_REPORTED' => _warning,
      'UNDER_REVIEW' => _primary,
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
