// ============================================================
// 工匠端 — 施工日报提交页
// 表单提交 + 该订单历史日报列表
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
const _divider = ZdColors.divider;

class DailyReportPage extends StatefulWidget {
  const DailyReportPage({super.key, required this.orderId});
  final String orderId;

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  DateTime _reportDate = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写标题和内容')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final now = DateTime.now();
      final report = WorkerDailyReport(
        id: 'wdr-${now.millisecondsSinceEpoch}',
        orderId: widget.orderId,
        date: _reportDate,
        title: title,
        content: content,
      );
      await WorkerAppScope.of(context).submitDailyReport(report);
      _titleCtrl.clear();
      _contentCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日报已提交')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('提交失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = WorkerAppScope.of(context);
    final reports = state.dailyReports
        .where((r) => r.orderId == widget.orderId)
        .toList();

    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text('施工日报'),
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 提交表单 ──
            ZdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('提交新日报', style: ZdText.subtitle),
                  const SizedBox(height: ZdSpacing.lg),

                  // 日期
                  _label('日期'),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _reportDate,
                        firstDate: DateTime(2025),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setState(() => _reportDate = d);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(ZdSpacing.md),
                      decoration: BoxDecoration(
                        border: Border.all(color: _divider),
                        borderRadius: BorderRadius.circular(ZdRadius.sm),
                      ),
                      child: Text(
                        '${_reportDate.year}年${_reportDate.month}月${_reportDate.day}日',
                        style: ZdText.body,
                      ),
                    ),
                  ),

                  const SizedBox(height: ZdSpacing.md),

                  // 标题
                  _label('标题'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      hintText: '如：水电施工第3天',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ZdRadius.sm),
                      ),
                      contentPadding: const EdgeInsets.all(ZdSpacing.md),
                    ),
                  ),

                  const SizedBox(height: ZdSpacing.md),

                  // 内容
                  _label('详细内容'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _contentCtrl,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: '请描述今日施工内容、进度、遇到的问题等...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ZdRadius.sm),
                      ),
                      contentPadding: const EdgeInsets.all(ZdSpacing.md),
                    ),
                  ),

                  const SizedBox(height: ZdSpacing.md),

                  // 图片占位
                  _label('现场照片（最多9张）'),
                  const SizedBox(height: ZdSpacing.sm),
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: ZdColors.background,
                      borderRadius: BorderRadius.circular(ZdRadius.sm),
                      border: Border.all(color: _divider, style: BorderStyle.solid),
                    ),
                    child: const Center(
                      child: Icon(Icons.add_photo_alternate_outlined, color: _textLight, size: 28),
                    ),
                  ),

                  const SizedBox(height: ZdSpacing.lg),

                  // 提交按钮
                  ZdPrimaryButton(
                    label: _submitting ? '提交中...' : '提交日报',
                    onTap: _submitting ? null : _submit,
                  ),
                ],
              ),
            ),

            // ── 历史日报 ──
            if (reports.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(ZdSpacing.lg, ZdSpacing.xl, ZdSpacing.lg, ZdSpacing.md),
                child: Text('历史日报（${reports.length}）', style: ZdText.subtitle),
              ),
            ...reports.map((r) => _ReportItem(report: r)),
            const SizedBox(height: ZdSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: ZdText.caption.copyWith(fontWeight: FontWeight.w500));
  }
}

// ── 历史日报列表项 ──
class _ReportItem extends StatelessWidget {
  const _ReportItem({required this.report});
  final WorkerDailyReport report;

  @override
  Widget build(BuildContext context) {
    return ZdCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(ZdSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(report.title, style: ZdText.subtitle),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: report.status == WorkerReportStatus.read
                        ? _textMid.withValues(alpha: 0.1)
                        : _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ZdRadius.pill),
                  ),
                  child: Text(report.statusLabel,
                      style: ZdText.tiny.copyWith(
                          color: report.status == WorkerReportStatus.read ? _textMid : _primary)),
                ),
              ],
            ),
            const SizedBox(height: ZdSpacing.sm),
            Text(
              '${report.date.year}年${report.date.month}月${report.date.day}日',
              style: ZdText.tiny,
            ),
            const SizedBox(height: ZdSpacing.sm),
            Text(report.content, style: ZdText.body),
          ],
        ),
      ),
    );
  }
}
