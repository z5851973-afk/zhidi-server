// ============================================================
// 工匠端 — 施工日报提交页（V14 API）
// ============================================================

import 'package:flutter/material.dart';

import '../../app/worker_app_scope.dart';
import '../../design/tokens.dart';
import '../../design/components.dart';
import '../../services/daily_report_api_client.dart';
import '../../services/auth_api_client.dart';

const _primary = ZdColors.primary;
const _textDark = ZdColors.textPrimary;
const _textLight = ZdColors.textHint;
const _divider = ZdColors.divider;

class DailyReportPage extends StatefulWidget {
  const DailyReportPage({super.key, required this.orderId});
  final String orderId;

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  final _contentCtrl = TextEditingController();
  DateTime _reportDate = DateTime.now();
  bool _submitting = false;
  List<RemoteDailyReport> _reports = const [];
  bool _loadingReports = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    final state = WorkerAppScope.of(context);
    final token = state.getAccessToken();
    if (token == null) {
      if (mounted) setState(() => _loadingReports = false);
      return;
    }
    try {
      final api = DailyReportApiClient();
      final list = await api.getReportsByBooking(token, widget.orderId);
      if (mounted) setState(() { _reports = list; _loadingReports = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  Future<void> _submit() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写日报内容')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final state = WorkerAppScope.of(context);
      // ignore: await_only_futures
      final token = await state.getAccessToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登录已过期')),
          );
        }
        return;
      }
      final dateStr = '${_reportDate.year}-${_reportDate.month.toString().padLeft(2, '0')}-${_reportDate.day.toString().padLeft(2, '0')}';
      final api = DailyReportApiClient();
      await api.submitReport(token, widget.orderId, dateStr, content, []);
      _contentCtrl.clear();
      await _loadReports();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日报已提交')),
        );
      }
    } on AuthApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('提交失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            ZdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('提交新日报', style: ZdText.subtitle),
                  const SizedBox(height: ZdSpacing.lg),
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
                  _label('详细内容'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _contentCtrl,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: '请描述今日施工内容、进度、遇到的问题等...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZdRadius.sm)),
                      contentPadding: const EdgeInsets.all(ZdSpacing.md),
                    ),
                  ),
                  const SizedBox(height: ZdSpacing.md),
                  _label('现场照片（最多9张）'),
                  const SizedBox(height: ZdSpacing.sm),
                  Container(
                    height: 80, width: 80,
                    decoration: BoxDecoration(
                      color: ZdColors.background,
                      borderRadius: BorderRadius.circular(ZdRadius.sm),
                      border: Border.all(color: _divider),
                    ),
                    child: const Center(
                      child: Icon(Icons.add_photo_alternate_outlined, color: _textLight, size: 28),
                    ),
                  ),
                  const SizedBox(height: ZdSpacing.lg),
                  ZdPrimaryButton(
                    label: _submitting ? '提交中...' : '提交日报',
                    onTap: _submitting ? null : _submit,
                  ),
                ],
              ),
            ),
            if (_reports.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(ZdSpacing.lg, ZdSpacing.xl, ZdSpacing.lg, ZdSpacing.md),
                child: Text('历史日报（${_reports.length}）', style: ZdText.subtitle),
              ),
            ..._reports.map((r) => _ReportItem(report: r)),
            if (_loadingReports)
              const Padding(padding: EdgeInsets.all(ZdSpacing.lg), child: Center(child: CircularProgressIndicator())),
            if (!_loadingReports && _reports.isEmpty)
              Padding(
                padding: const EdgeInsets.all(ZdSpacing.xl),
                child: Center(child: Text('暂无日报记录', style: ZdText.caption.copyWith(color: _textLight))),
              ),
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

class _ReportItem extends StatelessWidget {
  const _ReportItem({required this.report});
  final RemoteDailyReport report;

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
                Expanded(child: Text(report.reportDate, style: ZdText.subtitle)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ZdRadius.pill),
                  ),
                  child: Text('已提交', style: ZdText.tiny.copyWith(color: _primary)),
                ),
              ],
            ),
            const SizedBox(height: ZdSpacing.sm),
            Text(report.content, style: ZdText.body),
          ],
        ),
      ),
    );
  }
}
