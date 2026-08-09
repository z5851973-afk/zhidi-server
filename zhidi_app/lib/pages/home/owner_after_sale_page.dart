import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/owner_app_scope.dart';
import '../../app/owner_app_state.dart';
import '../../design/tokens.dart';
import '../../models/payment_models.dart';
import '../../services/auth_api_client.dart';
import '../../services/payment_api_client.dart';
import '../../services/upload_api_client.dart';

const _primary = ZdColors.primary;
const _bg = ZdColors.background;
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _textLight = ZdColors.textHint;
const _success = ZdColors.success;
const _errorColor = ZdColors.error;

typedef AfterSaleTokenProvider = Future<String?> Function();
typedef AfterSaleUserProvider = Future<String?> Function();
typedef AfterSaleImageUploader =
    Future<String> Function(File file, String accessToken);

String _canonicalEvidenceUrl(String value, Uri uploadBaseUrl) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || !uploadBaseUrl.hasScheme) return value;
  final sameOrigin =
      uri.scheme.toLowerCase() == uploadBaseUrl.scheme.toLowerCase() &&
      uri.host.toLowerCase() == uploadBaseUrl.host.toLowerCase() &&
      uri.port == uploadBaseUrl.port;
  if (sameOrigin &&
      uri.query.isEmpty &&
      uri.fragment.isEmpty &&
      uri.path.startsWith('/uploads/after-sales/')) {
    return uri.path;
  }
  return value;
}

class OwnerAfterSalePage extends StatefulWidget {
  const OwnerAfterSalePage({
    super.key,
    this.bookingId,
    this.paymentApi,
    this.uploadApi,
    this.imageUploader,
    this.title = '售后',
  });

  final String? bookingId;
  final PaymentApiClient? paymentApi;
  final UploadApiClient? uploadApi;
  final AfterSaleImageUploader? imageUploader;
  final String title;

  @override
  State<OwnerAfterSalePage> createState() => _OwnerAfterSalePageState();
}

class _OwnerAfterSalePageState extends State<OwnerAfterSalePage> {
  late final PaymentApiClient _defaultApi;
  late final UploadApiClient _defaultUploadApi;
  List<AfterSaleModel> _items = const [];
  Map<String, AfterSaleDetailModel> _details = const {};
  AfterSaleOrderContextModel? _bookingContext;
  bool _loading = true;
  String? _error;
  int _requestEpoch = 0;

  PaymentApiClient get _api => widget.paymentApi ?? _defaultApi;
  UploadApiClient get _uploadApi => widget.uploadApi ?? _defaultUploadApi;

  bool get _hasActiveTicket => _items.any(
    (item) => item.status == 'OPEN' || item.status == 'PLATFORM_PROCESSING',
  );

  bool get _bookingIsEligibleForAfterSale =>
      _bookingContext?.bookingStatus == 'COMPLETED' &&
      _bookingContext?.paymentStatus == 'PAID';

  bool get _canCreateAfterSale =>
      widget.bookingId != null &&
      !_loading &&
      _error == null &&
      _bookingIsEligibleForAfterSale &&
      !_hasActiveTicket;

  String? get _createEligibilityMessage {
    if (widget.bookingId == null || _bookingContext == null) return null;
    if (!_bookingIsEligibleForAfterSale) {
      return '完工验收且付款完成后可申请售后';
    }
    if (_hasActiveTicket) return '当前已有处理中的售后工单';
    return null;
  }

  Future<String> _uploadImage(File file, String token) async {
    final injected = widget.imageUploader;
    final url = injected != null
        ? await injected(file, token)
        : (await _uploadApi.uploadImage(
            file,
            accessToken: token,
            category: 'after-sales',
          )).url;
    return _canonicalEvidenceUrl(url, _uploadApi.baseUrl);
  }

  @override
  void initState() {
    super.initState();
    _defaultApi = PaymentApiClient();
    _defaultUploadApi = UploadApiClient();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_loadList());
  }

  @override
  void didUpdateWidget(covariant OwnerAfterSalePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookingId != widget.bookingId ||
        oldWidget.paymentApi != widget.paymentApi) {
      unawaited(_loadList());
    }
  }

  @override
  void dispose() {
    _requestEpoch++;
    super.dispose();
  }

  Future<void> _loadList() async {
    final epoch = ++_requestEpoch;
    final appState = OwnerAppScope.of(context);
    final sessionUserId = appState.sessionUserId;
    final token = await appState.getAccessToken();
    if (!mounted || epoch != _requestEpoch) return;
    if (sessionUserId == null || token == null) {
      setState(() {
        _items = const [];
        _details = const {};
        _bookingContext = null;
        _loading = false;
        _error = '登录已过期，请重新登录';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var items = await _api.listAfterSales(token);
      if (widget.bookingId != null) {
        items = items
            .where((item) => item.bookingId == widget.bookingId)
            .toList(growable: false);
      }
      final details = <String, AfterSaleDetailModel>{};
      await Future.wait(
        items.map((item) async {
          try {
            details[item.id] = await _api.getAfterSale(token, item.id);
          } catch (_) {
            // A list item is still useful when one detail request is transiently down.
          }
        }),
      );
      AfterSaleOrderContextModel? bookingContext;
      if (widget.bookingId != null) {
        for (final detail in details.values) {
          if (detail.context.bookingId == widget.bookingId) {
            bookingContext = detail.context;
            break;
          }
        }
        bookingContext ??= await _api.getAfterSaleBookingContext(
          token,
          widget.bookingId!,
        );
      }
      if (!await _isCurrentSession(appState, sessionUserId, token, epoch)) {
        return;
      }
      setState(() {
        _items = items;
        _details = details;
        _bookingContext = bookingContext;
        _loading = false;
      });
    } catch (error) {
      if (!await _isCurrentSession(appState, sessionUserId, token, epoch)) {
        return;
      }
      setState(() {
        _items = const [];
        _details = const {};
        _bookingContext = null;
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<bool> _isCurrentSession(
    OwnerAppState appState,
    String userId,
    String token,
    int epoch,
  ) async {
    if (!mounted ||
        epoch != _requestEpoch ||
        appState.sessionUserId != userId) {
      return false;
    }
    return await appState.getAccessToken() == token;
  }

  Future<bool> _isCurrentCreateTarget(
    OwnerAppState appState,
    String userId,
    String token,
    String bookingId,
  ) async {
    if (!mounted ||
        widget.bookingId != bookingId ||
        appState.sessionUserId != userId) {
      return false;
    }
    return await appState.getAccessToken() == token;
  }

  Future<void> _createAfterSale() async {
    final bookingId = widget.bookingId;
    if (bookingId == null) return;
    final appState = OwnerAppScope.of(context);
    final sessionUserId = appState.sessionUserId;
    final token = await appState.getAccessToken();
    if (!mounted || sessionUserId == null || token == null) return;
    final draft = await showDialog<_AfterSaleDraft>(
      context: context,
      builder: (_) => _AfterSaleDraftDialog(
        uploadImage: (file) => _uploadImage(file, token),
        isCurrent: () =>
            _isCurrentCreateTarget(appState, sessionUserId, token, bookingId),
      ),
    );
    if (draft == null ||
        !await _isCurrentCreateTarget(
          appState,
          sessionUserId,
          token,
          bookingId,
        )) {
      return;
    }
    try {
      await _api.createAfterSale(
        token,
        bookingId: bookingId,
        type: draft.type,
        reason: draft.content,
        evidenceUrls: draft.evidenceUrls,
      );
      if (!await _isCurrentCreateTarget(
        appState,
        sessionUserId,
        token,
        bookingId,
      )) {
        return;
      }
      await _loadList();
    } catch (error) {
      if (!await _isCurrentCreateTarget(
        appState,
        sessionUserId,
        token,
        bookingId,
      )) {
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('创建失败：${_friendlyError(error)}')));
    }
  }

  Future<void> _openDetail(AfterSaleModel item) async {
    final appState = OwnerAppScope.of(context);
    final token = await appState.getAccessToken();
    final userId = appState.sessionUserId;
    if (!mounted || token == null || userId == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AfterSaleDetailPage(
          afterSaleId: item.id,
          paymentApi: _api,
          uploadApi: _uploadApi,
          initialToken: token,
          initialUserId: userId,
          tokenProvider: appState.getAccessToken,
          userProvider: () async => appState.sessionUserId,
          sessionListenable: appState,
          currentUserProvider: () => appState.sessionUserId,
        ),
      ),
    );
    if (mounted) unawaited(_loadList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: _buildBody(),
      floatingActionButton: _canCreateAfterSale
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _AfterSaleErrorState(onRetry: _loadList);
    }
    if (_bookingContext != null) {
      return RefreshIndicator(
        onRefresh: _loadList,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            AfterSaleOrderContextCard(context: _bookingContext!),
            if (_createEligibilityMessage != null) ...[
              const SizedBox(height: 12),
              _AfterSaleInlineEmpty(text: _createEligibilityMessage!),
            ],
            const SizedBox(height: 12),
            if (_items.isEmpty)
              const _AfterSaleInlineEmpty(text: '该订单暂无售后工单')
            else
              for (var index = 0; index < _items.length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                AfterSaleTicketCard(
                  ticket: _items[index],
                  context: _details[_items[index].id]?.context,
                  onTap: () => _openDetail(_items[index]),
                ),
              ],
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return _AfterSaleEmptyState(
        text: widget.bookingId == null ? '暂无售后工单' : '该订单暂无售后工单',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadList,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final item = _items[index];
          return AfterSaleTicketCard(
            ticket: item,
            context: _details[item.id]?.context,
            onTap: () => _openDetail(item),
          );
        },
      ),
    );
  }
}

class AfterSaleOrderContextCard extends StatelessWidget {
  const AfterSaleOrderContextCard({super.key, required this.context});

  final AfterSaleOrderContextModel context;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '订单信息',
      child: Column(
        children: [
          _row(Icons.handyman_outlined, '工种', this.context.tradeLabel),
          _row(Icons.person_outline, '业主', this.context.ownerName ?? '-'),
          _row(
            Icons.engineering_outlined,
            '师傅',
            this.context.workerName ?? '-',
          ),
          _row(
            Icons.location_on_outlined,
            '地址',
            [
              this.context.serviceCity,
              this.context.serviceAddress,
            ].whereType<String>().join(' '),
          ),
          _row(
            Icons.receipt_long_outlined,
            '报价',
            this.context.quoteAmount == null
                ? '-'
                : '¥${this.context.quoteAmount!.toStringAsFixed(2)}',
          ),
          _row(Icons.payments_outlined, '付款', this.context.paymentLabel),
          _row(Icons.fact_check_outlined, '验收', this.context.inspection.label),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _textLight),
          const SizedBox(width: 9),
          SizedBox(
            width: 50,
            child: Text(label, style: const TextStyle(color: _textMid)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AfterSaleInlineEmpty extends StatelessWidget {
  const _AfterSaleInlineEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 28),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(text, style: const TextStyle(color: _textMid)),
  );
}

class AfterSaleTicketCard extends StatelessWidget {
  const AfterSaleTicketCard({
    super.key,
    required this.ticket,
    this.context,
    required this.onTap,
  });

  final AfterSaleModel ticket;
  final AfterSaleOrderContextModel? context;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(ticket.status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Pill(text: ticket.typeLabel, color: _primary),
                  const Spacer(),
                  _Pill(text: ticket.statusLabel, color: statusColor),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                ticket.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (this.context != null) ...[
                const SizedBox(height: 10),
                Text(
                  [
                        this.context!.ownerName,
                        this.context!.workerName,
                        this.context!.tradeLabel,
                      ]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' · '),
                  style: const TextStyle(color: _textMid, fontSize: 14),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_outlined,
                    size: 16,
                    color: _textLight,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _formatDateTime(
                        ticket.lastActivityAt ?? ticket.createdAt,
                      ),
                      style: const TextStyle(color: _textLight, fontSize: 12),
                    ),
                  ),
                  const Text('查看详情', style: TextStyle(color: _primary)),
                  const Icon(Icons.chevron_right, size: 18, color: _primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AfterSaleDetailPage extends StatefulWidget {
  const AfterSaleDetailPage({
    super.key,
    required this.afterSaleId,
    required this.paymentApi,
    required this.uploadApi,
    required this.initialToken,
    required this.initialUserId,
    required this.tokenProvider,
    required this.userProvider,
    required this.sessionListenable,
    required this.currentUserProvider,
  });

  final String afterSaleId;
  final PaymentApiClient paymentApi;
  final UploadApiClient uploadApi;
  final String initialToken;
  final String initialUserId;
  final AfterSaleTokenProvider tokenProvider;
  final AfterSaleUserProvider userProvider;
  final Listenable sessionListenable;
  final String? Function() currentUserProvider;

  @override
  State<AfterSaleDetailPage> createState() => _AfterSaleDetailPageState();
}

class _AfterSaleDetailPageState extends State<AfterSaleDetailPage> {
  final _replyController = TextEditingController();
  AfterSaleDetailModel? _detail;
  List<String> _pendingEvidence = const [];
  bool _loading = true;
  bool _sending = false;
  bool _uploading = false;
  String? _loadError;
  String? _sendError;
  String? _draftIdempotencyKey;
  bool _sessionUnavailable = false;
  int _epoch = 0;
  int _actionEpoch = 0;

  @override
  void initState() {
    super.initState();
    _replyController.addListener(_onDraftTextChanged);
    widget.sessionListenable.addListener(_onSessionChanged);
    _sessionUnavailable = !_isSynchronousSessionCurrent;
    if (!_sessionUnavailable) unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant AfterSaleDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionListenable != widget.sessionListenable) {
      oldWidget.sessionListenable.removeListener(_onSessionChanged);
      widget.sessionListenable.addListener(_onSessionChanged);
    }
    _onSessionChanged();
  }

  @override
  void dispose() {
    _epoch++;
    _actionEpoch++;
    widget.sessionListenable.removeListener(_onSessionChanged);
    _replyController.removeListener(_onDraftTextChanged);
    _replyController.dispose();
    super.dispose();
  }

  void _onDraftTextChanged() {
    if (!_sending) _draftIdempotencyKey = null;
  }

  bool get _isSynchronousSessionCurrent =>
      widget.currentUserProvider() == widget.initialUserId;

  void _onSessionChanged() {
    if (!mounted || _sessionUnavailable || _isSynchronousSessionCurrent) {
      return;
    }
    _epoch++;
    _actionEpoch++;
    _replyController.clear();
    setState(() {
      _detail = null;
      _pendingEvidence = const [];
      _loading = false;
      _sending = false;
      _uploading = false;
      _loadError = null;
      _sendError = null;
      _draftIdempotencyKey = null;
      _sessionUnavailable = true;
    });
  }

  Future<bool> _isCurrent(int epoch) async {
    if (!mounted ||
        _sessionUnavailable ||
        !_isSynchronousSessionCurrent ||
        epoch != _epoch) {
      return false;
    }
    return await widget.tokenProvider() == widget.initialToken &&
        await widget.userProvider() == widget.initialUserId;
  }

  Future<bool> _isCurrentAction(int epoch, String targetId) async {
    if (!mounted ||
        _sessionUnavailable ||
        !_isSynchronousSessionCurrent ||
        epoch != _actionEpoch ||
        targetId != widget.afterSaleId) {
      return false;
    }
    if (await widget.tokenProvider() != widget.initialToken) return false;
    return await widget.userProvider() == widget.initialUserId;
  }

  Future<void> _load() async {
    if (_sessionUnavailable || !_isSynchronousSessionCurrent) return;
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final detail = await widget.paymentApi.getAfterSale(
        widget.initialToken,
        widget.afterSaleId,
      );
      if (!await _isCurrent(epoch) || detail.ticket.id != widget.afterSaleId) {
        return;
      }
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (error) {
      if (!await _isCurrent(epoch)) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _pickEvidence() async {
    if (_sessionUnavailable ||
        !_isSynchronousSessionCurrent ||
        _uploading ||
        _pendingEvidence.length >= 9) {
      return;
    }
    final targetId = widget.afterSaleId;
    final actionEpoch = ++_actionEpoch;
    setState(() {
      _uploading = true;
      _sendError = null;
    });
    final uploaded = [..._pendingEvidence];
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 82);
      if (picked.isEmpty || !await _isCurrentAction(actionEpoch, targetId)) {
        return;
      }
      for (final image in picked.take(9 - uploaded.length)) {
        final result = await widget.uploadApi.uploadImage(
          File(image.path),
          accessToken: widget.initialToken,
          category: 'after-sales',
        );
        if (!await _isCurrentAction(actionEpoch, targetId)) {
          return;
        }
        uploaded.add(
          _canonicalEvidenceUrl(result.url, widget.uploadApi.baseUrl),
        );
      }
      if (!await _isCurrentAction(actionEpoch, targetId)) return;
      setState(() {
        _pendingEvidence = uploaded;
        _draftIdempotencyKey = null;
      });
    } catch (error) {
      if (!await _isCurrentAction(actionEpoch, targetId)) return;
      setState(() => _sendError = '图片上传失败：${_friendlyError(error)}');
    } finally {
      if (await _isCurrentAction(actionEpoch, targetId)) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _send() async {
    final content = _replyController.text.trim();
    if (_sessionUnavailable ||
        !_isSynchronousSessionCurrent ||
        _sending ||
        (content.isEmpty && _pendingEvidence.isEmpty)) {
      return;
    }
    final targetId = widget.afterSaleId;
    final actionEpoch = ++_actionEpoch;
    final evidence = List<String>.from(_pendingEvidence);
    final idempotencyKey = _draftIdempotencyKey ??=
        '${widget.initialUserId}-$targetId-${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      await widget.paymentApi.appendAfterSaleEvent(
        widget.initialToken,
        targetId,
        content: content.isEmpty ? null : content,
        evidenceUrls: evidence,
        idempotencyKey: idempotencyKey,
      );
      if (!await _isCurrentAction(actionEpoch, targetId)) {
        return;
      }
      _draftIdempotencyKey = null;
      _replyController.clear();
      setState(() => _pendingEvidence = const []);
      await _load();
    } catch (error) {
      if (!await _isCurrentAction(actionEpoch, targetId)) return;
      setState(() => _sendError = '发送失败：${_friendlyError(error)}');
    } finally {
      if (await _isCurrentAction(actionEpoch, targetId)) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('售后工单'),
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: _sessionUnavailable
          ? const _AfterSaleSessionUnavailable()
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _AfterSaleErrorState(onRetry: _load)
          : _buildDetail(_detail!),
    );
  }

  Widget _buildDetail(AfterSaleDetailModel detail) {
    final ticket = detail.ticket;
    final active =
        ticket.status == 'OPEN' || ticket.status == 'PLATFORM_PROCESSING';
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ticketSummary(ticket),
                const SizedBox(height: 12),
                AfterSaleOrderContextCard(context: detail.context),
                const SizedBox(height: 12),
                _timeline(detail.timeline),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        if (active) _composer(),
      ],
    );
  }

  Widget _ticketSummary(AfterSaleModel ticket) {
    return _SectionCard(
      title: '工单概览',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pill(text: ticket.typeLabel, color: _primary),
              const SizedBox(width: 8),
              _Pill(
                text: ticket.statusLabel,
                color: _statusColor(ticket.status),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            ticket.reason,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          if (ticket.resolution != null && ticket.resolution!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '处理结果：${ticket.resolution}',
              style: const TextStyle(color: _textMid, height: 1.45),
            ),
          ],
          if ((ticket.warrantyDeductionAmount ?? 0) > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ZdColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '本次履约质保扣减 ¥${ticket.warrantyDeductionAmount!.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: ZdColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 18, color: _primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '处理时限：${ticket.dueAt == null ? '待平台生成' : _formatDateTime(ticket.dueAt!)}',
                  style: const TextStyle(color: _textMid),
                ),
              ),
            ],
          ),
          if (ticket.evidenceUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _evidenceGrid(ticket.evidenceUrls),
          ],
        ],
      ),
    );
  }

  Widget _timeline(List<AfterSaleEventModel> timeline) {
    return _SectionCard(
      title: '处理时间线',
      child: timeline.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('暂无处理记录', style: TextStyle(color: _textMid)),
            )
          : Column(
              children: [
                for (var index = 0; index < timeline.length; index++)
                  _timelineItem(
                    timeline[index],
                    isLast: index == timeline.length - 1,
                  ),
              ],
            ),
    );
  }

  Widget _timelineItem(AfterSaleEventModel event, {required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(width: 2, height: 78, color: ZdColors.divider),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      event.typeLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      event.actorLabel,
                      style: const TextStyle(color: _textMid),
                    ),
                    const Spacer(),
                    Text(
                      _formatDateTime(event.createdAt),
                      style: const TextStyle(color: _textLight, fontSize: 11),
                    ),
                  ],
                ),
                if (event.content != null && event.content!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(event.content!, style: const TextStyle(height: 1.45)),
                ],
                if (event.evidenceUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _evidenceGrid(event.evidenceUrls),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _evidenceGrid(List<String> urls) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: urls
          .map(
            (url) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _displayUrl(url),
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 72,
                  height: 72,
                  color: ZdColors.divider,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: _textLight,
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ZdColors.divider)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pendingEvidence.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '已上传 ${_pendingEvidence.length} 张证据图片',
                    style: const TextStyle(color: _success, fontSize: 12),
                  ),
                ),
              ),
            if (_sendError != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _sendError!,
                    style: const TextStyle(color: _errorColor),
                  ),
                ),
              ),
            Row(
              children: [
                IconButton(
                  tooltip: '添加证据图片',
                  onPressed: _uploading || _sending ? null : _pickEvidence,
                  icon: _uploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                ),
                Expanded(
                  child: TextField(
                    key: const Key('after-sale-reply-field'),
                    controller: _replyController,
                    enabled: !_sending,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: '追加说明或补充证据',
                      filled: true,
                      fillColor: _bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('after-sale-reply-submit'),
                  onPressed: _sending || _uploading ? null : _send,
                  style: FilledButton.styleFrom(backgroundColor: _primary),
                  child: Text(_sending ? '发送中…' : '发送'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _displayUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    return Uri.parse(AuthApiClient.configuredBaseUrl).resolve(value).toString();
  }
}

class _AfterSaleDraftDialog extends StatefulWidget {
  const _AfterSaleDraftDialog({
    required this.uploadImage,
    required this.isCurrent,
  });

  final Future<String> Function(File file) uploadImage;
  final Future<bool> Function() isCurrent;

  @override
  State<_AfterSaleDraftDialog> createState() => _AfterSaleDraftDialogState();
}

class _AfterSaleDraftDialogState extends State<_AfterSaleDraftDialog> {
  final _controller = TextEditingController();
  String _type = 'COMPLAINT';
  List<String> _evidence = const [];
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 82);
    if (files.isEmpty || !mounted || !await widget.isCurrent()) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    final urls = [..._evidence];
    try {
      for (final file in files.take(9 - urls.length)) {
        final url = await widget.uploadImage(File(file.path));
        if (!mounted || !await widget.isCurrent()) return;
        urls.add(url);
      }
      if (!mounted || !await widget.isCurrent()) return;
      setState(() => _evidence = urls);
    } catch (error) {
      if (!mounted || !await widget.isCurrent()) return;
      setState(() => _error = '图片上传失败：${_friendlyError(error)}');
    } finally {
      if (mounted && await widget.isCurrent()) {
        setState(() => _uploading = false);
      }
    }
  }

  void _submit() {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      setState(() => _error = '请填写问题描述');
      return;
    }
    Navigator.pop(
      context,
      _AfterSaleDraft(type: _type, content: content, evidenceUrls: _evidence),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('提交售后申请'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '问题类型'),
              items: const [
                DropdownMenuItem(value: 'COMPLAINT', child: Text('施工质量或服务投诉')),
                DropdownMenuItem(value: 'DISPUTE', child: Text('费用或责任争议')),
                DropdownMenuItem(value: 'REFUND', child: Text('退款诉求（平台人工处理）')),
              ],
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '平台将人工核实处理，当前不支持自动退款',
                style: TextStyle(color: _textMid, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: '问题描述',
                hintText: '请写明位置、现象和想要的处理方式',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _uploading ? '上传中…' : '添加证据图片（${_evidence.length}/9）',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: _errorColor)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _uploading ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _primary),
          child: const Text('提交'),
        ),
      ],
    );
  }
}

class _AfterSaleDraft {
  const _AfterSaleDraft({
    required this.type,
    required this.content,
    required this.evidenceUrls,
  });

  final String type;
  final String content;
  final List<String> evidenceUrls;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AfterSaleErrorState extends StatelessWidget {
  const _AfterSaleErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 54, color: _textLight),
          const SizedBox(height: 12),
          const Text(
            '加载失败',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text('请检查网络后重试', style: TextStyle(color: _textMid)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _AfterSaleSessionUnavailable extends StatelessWidget {
  const _AfterSaleSessionUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 54, color: _textLight),
          SizedBox(height: 12),
          Text(
            '登录状态已变化，售后内容不可用',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _AfterSaleEmptyState extends StatelessWidget {
  const _AfterSaleEmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.support_agent_outlined, size: 60, color: _textLight),
          const SizedBox(height: 14),
          Text(text, style: const TextStyle(color: _textMid, fontSize: 16)),
        ],
      ),
    );
  }
}

Color _statusColor(String status) => switch (status) {
  'OPEN' => Colors.orange,
  'PLATFORM_PROCESSING' => _primary,
  'RESOLVED' => _success,
  'CLOSED' => _textLight,
  _ => _textDark,
};

String _formatDateTime(String value) {
  try {
    final time = DateTime.parse(value).toLocal();
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return value;
  }
}

String _friendlyError(Object error) {
  if (error is PaymentApiException) return error.message;
  if (error is UploadApiException) return error.message;
  return '请稍后重试';
}
