// ============================================================
// 工匠端 — 验收请求/响应页
// 两个子Tab：待验收 / 已验收
// ============================================================

import 'package:flutter/material.dart';

import '../../app/worker_app_scope.dart';
import '../../app/worker_models.dart';
import '../../design/tokens.dart';
import '../../design/components.dart';

const _primary = ZdColors.primary;
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _textLight = ZdColors.textHint;
const _success = ZdColors.success;
const _error = ZdColors.error;

class InspectionPage extends StatelessWidget {
  const InspectionPage({super.key, this.orderId});
  final String? orderId;

  @override
  Widget build(BuildContext context) {
    final state = WorkerAppScope.of(context);
    final all = orderId != null
        ? state.inspectionRequests.where((r) => r.orderId == orderId).toList()
        : state.inspectionRequests;

    final pending = all.where((r) => r.status == WorkerInspectionStatus.pending).toList();
    final resolved = all.where((r) => r.status != WorkerInspectionStatus.pending).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: ZdColors.background,
        appBar: AppBar(
          title: const Text('验收管理'),
          backgroundColor: Colors.white,
          foregroundColor: _textDark,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(42),
            child: Container(
              color: Colors.white,
              child: TabBar(
                labelColor: _primary,
                unselectedLabelColor: _textMid,
                indicatorColor: _primary,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 15),
                tabs: [
                  Tab(text: '待验收（${pending.length}）'),
                  Tab(text: '已验收（${resolved.length}）'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            pending.isEmpty ? _empty('暂无待验收请求') : _InspectionList(items: pending, isPending: true),
            resolved.isEmpty ? _empty('暂无已验收记录') : _InspectionList(items: resolved, isPending: false),
          ],
        ),
      ),
    );
  }

  Widget _empty(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fact_check_outlined, size: 56, color: _textLight),
          const SizedBox(height: ZdSpacing.md),
          Text(text, style: ZdText.caption.copyWith(color: _textLight)),
        ],
      ),
    );
  }
}

class _InspectionList extends StatelessWidget {
  const _InspectionList({required this.items, required this.isPending});
  final List<WorkerInspectionRequest> items;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(ZdSpacing.md),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return ZdCard(
          onTap: isPending ? () => _showDetail(context, item) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (isPending ? _primary : _success).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(ZdRadius.sm),
                    ),
                    child: Icon(
                      isPending ? Icons.pending_actions : Icons.check_circle_outline,
                      color: isPending ? _primary : _success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: ZdSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.phaseName, style: ZdText.subtitle),
                        const SizedBox(height: 2),
                        Text('请求时间：${_fmt(item.requestTime)}', style: ZdText.tiny),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(item.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(ZdRadius.pill),
                    ),
                    child: Text(item.statusLabel,
                        style: ZdText.tiny.copyWith(
                            color: _statusColor(item.status),
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
              if (item.comment != null) ...[
                const SizedBox(height: ZdSpacing.md),
                Text('备注：${item.comment}', style: ZdText.caption),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(WorkerInspectionStatus s) => switch (s) {
    WorkerInspectionStatus.pending => _primary,
    WorkerInspectionStatus.passed => _success,
    WorkerInspectionStatus.failed => _error,
  };

  String _fmt(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  void _showDetail(BuildContext context, WorkerInspectionRequest item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ZdRadius.card)),
      ),
      builder: (ctx) => _InspectionSheet(item: item),
    );
  }
}

class _InspectionSheet extends StatelessWidget {
  const _InspectionSheet({required this.item});
  final WorkerInspectionRequest item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: ZdSpacing.lg,
        right: ZdSpacing.lg,
        top: ZdSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + ZdSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _textLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: ZdSpacing.lg),
          Text('验收详情', style: ZdText.title),
          const SizedBox(height: ZdSpacing.lg),
          _detailRow('工序', item.phaseName),
          _detailRow('请求时间', '${item.requestTime.year}-${item.requestTime.month}-${item.requestTime.day}'),
          const SizedBox(height: ZdSpacing.lg),
          if (item.images.isNotEmpty)
            Text('业主提交图片', style: ZdText.caption),
          const SizedBox(height: ZdSpacing.lg),
          ZdPrimaryButton(
            label: '通过验收',
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: ZdSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: _error,
                side: const BorderSide(color: _error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ZdRadius.pill),
                ),
                minimumSize: const Size(0, 52),
              ),
              child: const Text('未通过'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZdSpacing.sm),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: ZdText.caption)),
          Expanded(child: Text(value, style: ZdText.body)),
        ],
      ),
    );
  }
}
