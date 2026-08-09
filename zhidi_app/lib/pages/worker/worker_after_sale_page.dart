import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/worker_app_scope.dart';
import '../../app/worker_app_state.dart';
import '../../design/tokens.dart';
import '../../models/payment_models.dart';
import '../../services/payment_api_client.dart';
import '../../services/upload_api_client.dart';
import '../home/owner_after_sale_page.dart';

class WorkerAfterSalePage extends StatefulWidget {
  const WorkerAfterSalePage({super.key, this.paymentApi, this.uploadApi});

  final PaymentApiClient? paymentApi;
  final UploadApiClient? uploadApi;

  @override
  State<WorkerAfterSalePage> createState() => _WorkerAfterSalePageState();
}

class _WorkerAfterSalePageState extends State<WorkerAfterSalePage> {
  late final PaymentApiClient _defaultApi;
  late final UploadApiClient _defaultUploadApi;
  List<AfterSaleModel> _items = const [];
  Map<String, AfterSaleDetailModel> _details = const {};
  bool _loading = true;
  String? _error;
  int _epoch = 0;

  PaymentApiClient get _api => widget.paymentApi ?? _defaultApi;
  UploadApiClient get _uploadApi => widget.uploadApi ?? _defaultUploadApi;

  @override
  void initState() {
    super.initState();
    _defaultApi = PaymentApiClient();
    _defaultUploadApi = UploadApiClient();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_load());
  }

  @override
  void dispose() {
    _epoch++;
    super.dispose();
  }

  Future<void> _load() async {
    final requestEpoch = ++_epoch;
    final state = WorkerAppScope.of(context);
    final token = state.getAccessToken();
    final userId = await state.getUserId();
    if (!mounted || requestEpoch != _epoch) return;
    if (token == null || userId == null) {
      setState(() {
        _loading = false;
        _items = const [];
        _details = const {};
        _error = '登录已过期，请重新登录';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.listAfterSales(token);
      final details = <String, AfterSaleDetailModel>{};
      await Future.wait(
        items.map((item) async {
          try {
            details[item.id] = await _api.getAfterSale(token, item.id);
          } catch (_) {
            // Keep the discoverable ticket when a single detail call fails.
          }
        }),
      );
      if (!await _isCurrent(state, token, userId, requestEpoch)) return;
      setState(() {
        _items = items;
        _details = details;
        _loading = false;
      });
    } catch (error) {
      if (!await _isCurrent(state, token, userId, requestEpoch)) return;
      setState(() {
        _items = const [];
        _details = const {};
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<bool> _isCurrent(
    WorkerAppState state,
    String token,
    String userId,
    int requestEpoch,
  ) async {
    if (!mounted || requestEpoch != _epoch || state.getAccessToken() != token) {
      return false;
    }
    return await state.getUserId() == userId;
  }

  Future<void> _open(AfterSaleModel ticket) async {
    final state = WorkerAppScope.of(context);
    final token = state.getAccessToken();
    final userId = await state.getUserId();
    if (!mounted || token == null || userId == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AfterSaleDetailPage(
          afterSaleId: ticket.id,
          paymentApi: _api,
          uploadApi: _uploadApi,
          initialToken: token,
          initialUserId: userId,
          tokenProvider: () async => state.getAccessToken(),
          userProvider: state.getUserId,
          sessionListenable: state,
          currentUserProvider: () => state.sessionUserId,
        ),
      ),
    );
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text('售后协作'),
        backgroundColor: Colors.white,
        foregroundColor: ZdColors.textPrimary,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 54,
              color: ZdColors.textHint,
            ),
            const SizedBox(height: 12),
            const Text(
              '加载失败',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.support_agent_outlined,
              size: 60,
              color: ZdColors.textHint,
            ),
            SizedBox(height: 14),
            Text(
              '暂无相关售后工单',
              style: TextStyle(color: ZdColors.textSecondary, fontSize: 16),
            ),
            SizedBox(height: 6),
            Text(
              '业主发起与您订单相关的售后后会在这里显示',
              style: TextStyle(color: ZdColors.textHint, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final item = _items[index];
          return AfterSaleTicketCard(
            ticket: item,
            context: _details[item.id]?.context,
            onTap: () => _open(item),
          );
        },
      ),
    );
  }
}
