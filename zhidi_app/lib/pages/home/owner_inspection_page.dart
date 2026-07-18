// ============================================================
// 业主端 — 验收页（V14 API）
// 查看所有节点状态、验收通过/不通过、查看历史记录
// ============================================================

import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../design/tokens.dart';
import '../../design/components.dart';
import '../../services/inspection_api_client.dart';
import '../../services/daily_report_api_client.dart';
import '../../services/auth_api_client.dart';

const _primary = ZdColors.primary;
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _textLight = ZdColors.textHint;
const _success = ZdColors.success;
const _error = ZdColors.error;

class OwnerInspectionPage extends StatefulWidget {
  const OwnerInspectionPage({super.key, required this.bookingId});
  final String bookingId;

  @override
  State<OwnerInspectionPage> createState() => _OwnerInspectionPageState();
}

class _OwnerInspectionPageState extends State<OwnerInspectionPage> {
  List<RemoteInspectionNode> _nodes = const [];
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadNodes();
  }

  Future<void> _loadNodes() async {
    final state = OwnerAppScope.of(context);
    final token = await state.getAccessToken();
    if (token == null) {
      if (mounted) setState(() { _loading = false; _errorMsg = '未登录'; });
      return;
    }
    try {
      final api = InspectionApiClient();
      final nodes = await api.getNodes(token, widget.bookingId);
      if (mounted) setState(() { _nodes = nodes; _loading = false; });
    } on AuthApiException catch (e) {
      if (mounted) setState(() { _loading = false; _errorMsg = e.message; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _errorMsg = '加载失败：$e'; });
    }
  }

  void _openInspectForm(RemoteInspectionNode node) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _InspectFormPage(
          node: node,
          onInspectionDone: _loadNodes,
        ),
      ),
    );
  }

  void _openRecords(RemoteInspectionNode node) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _InspectionRecordsPage(nodeId: node.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text('节点验收'),
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMsg!, style: ZdText.caption.copyWith(color: _textLight)),
            const SizedBox(height: ZdSpacing.md),
            ZdPrimaryButton(label: '重试', onTap: () { setState(() { _loading = true; _errorMsg = null; }); _loadNodes(); }),
          ],
        ),
      );
    }
    if (_nodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fact_check_outlined, size: 56, color: _textLight),
            const SizedBox(height: ZdSpacing.md),
            Text('暂无验收节点', style: ZdText.caption.copyWith(color: _textLight)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(ZdSpacing.md),
      itemCount: _nodes.length,
      itemBuilder: (ctx, i) => _OwnerNodeCard(
        node: _nodes[i],
        onInspect: () => _openInspectForm(_nodes[i]),
        onViewRecords: () => _openRecords(_nodes[i]),
      ),
    );
  }
}

class _OwnerNodeCard extends StatelessWidget {
  const _OwnerNodeCard({required this.node, required this.onInspect, required this.onViewRecords});
  final RemoteInspectionNode node;
  final VoidCallback onInspect;
  final VoidCallback onViewRecords;

  Color get _color {
    switch (node.status) {
      case 'PENDING': return _textMid;
      case 'INSPECTING': return _primary;
      case 'PASSED': return _success;
      case 'FAILED': return _error;
      default: return _textMid;
    }
  }

  String get _label {
    switch (node.status) {
      case 'PENDING': return '待验收';
      case 'INSPECTING': return '验收中';
      case 'PASSED': return '已通过';
      case 'FAILED': return '未通过';
      default: return node.status;
    }
  }

  IconData get _icon {
    switch (node.status) {
      case 'PENDING': return Icons.hourglass_empty;
      case 'INSPECTING': return Icons.pending_actions;
      case 'PASSED': return Icons.check_circle_outline;
      case 'FAILED': return Icons.cancel_outlined;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ZdRadius.sm),
                ),
                child: Icon(_icon, color: _color, size: 20),
              ),
              const SizedBox(width: ZdSpacing.md),
              Expanded(
                child: Text(node.name, style: ZdText.subtitle),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ZdRadius.pill),
                ),
                child: Text(_label, style: ZdText.tiny.copyWith(color: _color, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          if (node.status == 'INSPECTING') ...[
            const SizedBox(height: ZdSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ZdPrimaryButton(label: '去验收', onTap: onInspect),
            ),
          ] else if (node.status == 'PASSED' || node.status == 'FAILED') ...[
            const SizedBox(height: ZdSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onViewRecords,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZdRadius.pill)),
                ),
                child: const Text('查看验收记录'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 验收表单子页 ──
class _InspectFormPage extends StatefulWidget {
  const _InspectFormPage({required this.node, required this.onInspectionDone});
  final RemoteInspectionNode node;
  final VoidCallback onInspectionDone;

  @override
  State<_InspectFormPage> createState() => _InspectFormPageState();
}

class _InspectFormPageState extends State<_InspectFormPage> {
  String _result = 'PASS';
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final state = OwnerAppScope.of(context);
      final token = await state.getAccessToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('登录已过期')));
        }
        return;
      }
      final api = InspectionApiClient();
      await api.inspect(token, widget.node.id, _result, _commentCtrl.text.trim(), []);
      widget.onInspectionDone();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_result == 'PASS' ? '验收通过' : '已记录整改意见')),
        );
        Navigator.pop(context);
      }
    } on AuthApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e')));
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
        title: const Text('验收'),
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZdSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('节点：${widget.node.name}', style: ZdText.subtitle),
            const SizedBox(height: ZdSpacing.xl),
            Text('验收结论', style: ZdText.caption.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: ZdSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _choiceBtn('通过', 'PASS', _success),
                ),
                const SizedBox(width: ZdSpacing.md),
                Expanded(
                  child: _choiceBtn('不通过', 'FAIL', _error),
                ),
              ],
            ),
            const SizedBox(height: ZdSpacing.lg),
            Text(_result == 'PASS' ? '备注（选填）' : '整改意见', style: ZdText.caption.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            TextField(
              controller: _commentCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: _result == 'PASS' ? '可填写验收备注...' : '请说明需要整改的内容...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZdRadius.sm)),
              ),
            ),
            const SizedBox(height: ZdSpacing.lg),
            Text('现场照片（选填）', style: ZdText.caption.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: ZdSpacing.sm),
            Container(
              height: 80, width: 80,
              decoration: BoxDecoration(
                color: ZdColors.background,
                borderRadius: BorderRadius.circular(ZdRadius.sm),
                border: Border.all(color: ZdColors.divider),
              ),
              child: const Center(
                child: Icon(Icons.add_photo_alternate_outlined, color: _textLight, size: 28),
              ),
            ),
            const SizedBox(height: ZdSpacing.xl),
            ZdPrimaryButton(
              label: _submitting ? '提交中...' : '提交验收',
              onTap: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceBtn(String label, String value, Color color) {
    final selected = _result == value;
    return GestureDetector(
      onTap: () => setState(() => _result = value),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.white,
          border: Border.all(color: selected ? color : ZdColors.divider, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(ZdRadius.sm),
        ),
        child: Center(
          child: Text(label, style: ZdText.body.copyWith(color: selected ? color : _textMid, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

// ── 验收记录子页 ──
class _InspectionRecordsPage extends StatefulWidget {
  const _InspectionRecordsPage({required this.nodeId});
  final String nodeId;

  @override
  State<_InspectionRecordsPage> createState() => _InspectionRecordsPageState();
}

class _InspectionRecordsPageState extends State<_InspectionRecordsPage> {
  List<RemoteInspectionRecord> _records = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final state = OwnerAppScope.of(context);
    final token = await state.getAccessToken();
    if (token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final api = InspectionApiClient();
      final records = await api.getRecords(token, widget.nodeId);
      if (mounted) setState(() { _records = records; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text('验收记录'),
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(child: Text('暂无验收记录', style: ZdText.caption.copyWith(color: _textLight)))
              : ListView.builder(
                  padding: const EdgeInsets.all(ZdSpacing.md),
                  itemCount: _records.length,
                  itemBuilder: (ctx, i) => _RecordItem(record: _records[i]),
                ),
    );
  }
}

class _RecordItem extends StatelessWidget {
  const _RecordItem({required this.record});
  final RemoteInspectionRecord record;

  @override
  Widget build(BuildContext context) {
    final passed = record.result == 'PASS';
    return ZdCard(
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (passed ? _success : _error).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ZdRadius.sm),
            ),
            child: Icon(passed ? Icons.check_circle : Icons.cancel, color: passed ? _success : _error, size: 20),
          ),
          const SizedBox(width: ZdSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('第 ${record.version} 次验收', style: ZdText.subtitle),
                    const SizedBox(width: ZdSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (passed ? _success : _error).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(record.result, style: ZdText.tiny.copyWith(color: passed ? _success : _error)),
                    ),
                  ],
                ),
                if (record.comment != null && record.comment!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(record.comment!, style: ZdText.caption),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 业主端 — 施工日报查看页
// ============================================================

class OwnerDailyReportViewPage extends StatefulWidget {
  const OwnerDailyReportViewPage({super.key, required this.bookingId});
  final String bookingId;

  @override
  State<OwnerDailyReportViewPage> createState() => _OwnerDailyReportViewPageState();
}

class _OwnerDailyReportViewPageState extends State<OwnerDailyReportViewPage> {
  final _api = DailyReportApiClient();
  List<RemoteDailyReport> _reports = const [];
  bool _loading = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _errorText = null; });
    try {
      final state = OwnerAppScope.of(context);
      final token = await state.getAccessToken();
      if (token == null) {
        if (mounted) setState(() { _errorText = '未登录'; _loading = false; });
        return;
      }
      final list = await _api.getReportsByBooking(token, widget.bookingId);
      if (mounted) setState(() { _reports = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _errorText = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('施工日报'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorText != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorText!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : _reports.isEmpty
                  ? const Center(child: Text('暂无施工日报', style: TextStyle(color: _textMid, fontSize: 15)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reports.length,
                      itemBuilder: (_, i) {
                        final r = _reports[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.article_outlined, size: 16, color: _primary),
                                  const SizedBox(width: 6),
                                  Text(r.reportDate, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  if (r.photos.isNotEmpty)
                                    const Icon(Icons.photo_library_outlined, size: 14, color: _textMid),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(r.content, style: const TextStyle(fontSize: 14, color: _textDark)),
                              if (r.photos.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: r.photos.map((url) => ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      url,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        width: 72,
                                        height: 72,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.broken_image, color: _textMid),
                                      ),
                                    ),
                                  )).toList(),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
