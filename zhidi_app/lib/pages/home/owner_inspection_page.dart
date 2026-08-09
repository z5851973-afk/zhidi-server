// ============================================================
// 业主端 — 验收页（V14 API）
// 查看所有节点状态、验收通过/不通过、查看历史记录
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../design/tokens.dart';
import '../../design/components.dart';
import '../../services/inspection_api_client.dart';
import '../../services/inspection_evidence_upload.dart';
import '../../services/daily_report_api_client.dart';
import '../../services/auth_api_client.dart';

const _primary = ZdColors.primary;
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _textLight = ZdColors.textHint;
const _success = ZdColors.success;
const _error = ZdColors.error;

class OwnerInspectionPage extends StatefulWidget {
  const OwnerInspectionPage({
    super.key,
    required this.bookingId,
    this.initialNodeId,
    this.api,
    this.pickImages,
    this.uploadImage,
  });

  final String bookingId;
  final String? initialNodeId;
  final InspectionApi? api;
  final InspectionImagePicker? pickImages;
  final InspectionImageUploader? uploadImage;

  @override
  State<OwnerInspectionPage> createState() => _OwnerInspectionPageState();
}

class _OwnerInspectionPageState extends State<OwnerInspectionPage> {
  List<RemoteInspectionNode> _nodes = const [];
  bool _loading = true;
  String? _errorMsg;
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) {
      return;
    }
    _loadStarted = true;
    _loadNodes();
  }

  Future<void> _loadNodes() async {
    final state = OwnerAppScope.of(context);
    final token = await state.getAccessToken();
    if (token == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = '未登录';
        });
      }
      return;
    }
    try {
      final api = widget.api ?? InspectionApiClient();
      final nodes = await api.getNodes(token, widget.bookingId);
      if (mounted) {
        setState(() {
          final initialNodeId = widget.initialNodeId?.trim();
          _nodes = initialNodeId == null || initialNodeId.isEmpty
              ? nodes
              : nodes
                    .where(
                      (node) =>
                          node.id == initialNodeId &&
                          node.bookingId == widget.bookingId,
                    )
                    .toList(growable: false);
          _loading = false;
        });
      }
    } on AuthApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = '加载失败：$e';
        });
      }
    }
  }

  void _openInspectForm(RemoteInspectionNode node) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _InspectFormPage(
          node: node,
          api: widget.api,
          pickImages: widget.pickImages,
          uploadImage: widget.uploadImage,
          onInspectionDone: _loadNodes,
        ),
      ),
    );
  }

  void _openRecords(RemoteInspectionNode node) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _InspectionRecordsPage(nodeId: node.id, api: widget.api),
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
            ZdPrimaryButton(
              label: '重试',
              onTap: () {
                setState(() {
                  _loading = true;
                  _errorMsg = null;
                });
                _loadNodes();
              },
            ),
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
            Text('师傅尚未发起验收', style: ZdText.caption.copyWith(color: _textLight)),
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
  const _OwnerNodeCard({
    required this.node,
    required this.onInspect,
    required this.onViewRecords,
  });
  final RemoteInspectionNode node;
  final VoidCallback onInspect;
  final VoidCallback onViewRecords;

  Color get _color {
    switch (node.status) {
      case 'PENDING':
        return _textMid;
      case 'INSPECTING':
        return _primary;
      case 'PASSED':
        return _success;
      case 'FAILED':
        return _error;
      default:
        return _textMid;
    }
  }

  String get _label {
    switch (node.status) {
      case 'PENDING':
        return '等待师傅发起验收';
      case 'INSPECTING':
        return '待您验收';
      case 'PASSED':
        return '验收已通过';
      case 'FAILED':
        return '等待师傅整改并重新发起';
      default:
        return node.status;
    }
  }

  IconData get _icon {
    switch (node.status) {
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'INSPECTING':
        return Icons.pending_actions;
      case 'PASSED':
        return Icons.check_circle_outline;
      case 'FAILED':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ZdRadius.sm),
                ),
                child: Icon(_icon, color: _color, size: 20),
              ),
              const SizedBox(width: ZdSpacing.md),
              Expanded(child: Text(node.name, style: ZdText.subtitle)),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ZdRadius.pill),
                  ),
                  child: Text(
                    _label,
                    textAlign: TextAlign.center,
                    style: ZdText.tiny.copyWith(
                      color: _color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (node.status == 'INSPECTING') ...[
            const SizedBox(height: ZdSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ZdPrimaryButton(label: '去验收', onTap: onInspect),
            ),
            const SizedBox(height: ZdSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onViewRecords,
                icon: const Icon(Icons.timeline_outlined),
                label: const Text('查看验收时间线'),
              ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ZdRadius.pill),
                  ),
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
  const _InspectFormPage({
    required this.node,
    required this.onInspectionDone,
    this.api,
    this.pickImages,
    this.uploadImage,
  });
  final RemoteInspectionNode node;
  final VoidCallback onInspectionDone;
  final InspectionApi? api;
  final InspectionImagePicker? pickImages;
  final InspectionImageUploader? uploadImage;

  @override
  State<_InspectFormPage> createState() => _InspectFormPageState();
}

class _InspectFormPageState extends State<_InspectFormPage> {
  String? _result;
  RemoteInspectionTimelineEvent? _workerSubmission;
  bool _evidenceLoading = true;
  String? _evidenceError;
  bool _evidenceLoadStarted = false;
  final _commentCtrl = TextEditingController();
  final List<File> _selectedImages = [];
  final Map<String, String> _uploadedUrls = {};
  bool _submitting = false;
  bool _pickingImages = false;

  bool get _canSubmit =>
      !_submitting &&
      !_evidenceLoading &&
      _workerSubmission != null &&
      _result != null &&
      (_result != 'FAIL' || _commentCtrl.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    _commentCtrl.addListener(_onCommentChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_evidenceLoadStarted) return;
    _evidenceLoadStarted = true;
    _loadWorkerEvidence();
  }

  Future<void> _loadWorkerEvidence() async {
    if (mounted) {
      setState(() {
        _evidenceLoading = true;
        _evidenceError = null;
        _workerSubmission = null;
        _result = null;
      });
    }
    final state = OwnerAppScope.of(context);
    final token = await state.getAccessToken();
    if (token == null) {
      if (mounted) {
        setState(() {
          _evidenceLoading = false;
          _evidenceError = '登录已过期';
        });
      }
      return;
    }
    try {
      final api = widget.api ?? InspectionApiClient();
      final timeline = await api.getInspectionTimeline(token, widget.node.id);
      final currentToken = await state.getAccessToken();
      if (currentToken != token) {
        throw const AuthApiException(
          code: 'SESSION_CHANGED',
          message: '登录账号已切换，请重新进入验收页面',
        );
      }
      final submissions = timeline
          .where((event) => event.isWorkerSubmission)
          .toList(growable: false);
      final latest = submissions.isEmpty
          ? null
          : submissions.reduce(
              (left, right) => left.version >= right.version ? left : right,
            );
      if (!mounted) return;
      setState(() {
        _workerSubmission = latest;
        _evidenceLoading = false;
        _evidenceError = latest == null ? '未找到师傅本轮验收证据，请刷新后重试' : null;
      });
    } on AuthApiException catch (error) {
      if (mounted) {
        setState(() {
          _evidenceLoading = false;
          _evidenceError = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _evidenceLoading = false;
          _evidenceError = '验收证据加载失败，请稍后重试';
        });
      }
    }
  }

  void _onCommentChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _commentCtrl.removeListener(_onCommentChanged);
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_pickingImages || _selectedImages.length >= 9) return;
    setState(() => _pickingImages = true);
    try {
      final images =
          await (widget.pickImages?.call() ?? pickInspectionImages());
      if (!mounted) return;
      final before = _selectedImages.length;
      setState(() {
        for (final image in images) {
          if (_selectedImages.length >= 9) break;
          if (_selectedImages.every((item) => item.path != image.path)) {
            _selectedImages.add(image);
          }
        }
      });
      if (_selectedImages.length - before < images.length && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('验收照片最多 9 张')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('读取照片失败，请检查相册权限')));
      }
    } finally {
      if (mounted) setState(() => _pickingImages = false);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      final state = OwnerAppScope.of(context);
      final token = await state.getAccessToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('登录已过期')));
        }
        return;
      }
      for (final image in _selectedImages) {
        if (_uploadedUrls.containsKey(image.path)) continue;
        final uploader = widget.uploadImage ?? uploadInspectionImage;
        _uploadedUrls[image.path] = await uploader(
          image,
          token,
          widget.node.id,
        );
        if (await state.getAccessToken() != token) {
          _uploadedUrls.clear();
          throw const AuthApiException(
            code: 'SESSION_CHANGED',
            message: '登录账号已切换，请重新选择照片并提交',
          );
        }
      }
      final photoUrls = _selectedImages
          .map((image) => _uploadedUrls[image.path]!)
          .toList(growable: false);
      final api = widget.api ?? InspectionApiClient();
      if (await state.getAccessToken() != token) {
        _uploadedUrls.clear();
        throw const AuthApiException(
          code: 'SESSION_CHANGED',
          message: '登录账号已切换，请重新提交验收',
        );
      }
      await api.inspect(
        token,
        widget.node.id,
        _result!,
        _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
        photoUrls,
      );
      widget.onInspectionDone();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_result == 'PASS' ? '验收通过' : '已记录整改意见')),
        );
        Navigator.pop(context);
      }
    } on AuthApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
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
            _buildWorkerEvidence(),
            const SizedBox(height: ZdSpacing.xl),
            Text(
              '验收结论',
              style: ZdText.caption.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: ZdSpacing.sm),
            Row(
              children: [
                Expanded(child: _choiceBtn('通过', 'PASS', _success)),
                const SizedBox(width: ZdSpacing.md),
                Expanded(child: _choiceBtn('不通过', 'FAIL', _error)),
              ],
            ),
            if (_result == null) ...[
              const SizedBox(height: ZdSpacing.sm),
              Text('请选择验收结论', style: ZdText.tiny.copyWith(color: _error)),
            ],
            const SizedBox(height: ZdSpacing.lg),
            Text(
              _result == 'FAIL' ? '整改意见（必填）' : '备注（选填）',
              style: ZdText.caption.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _commentCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: _result == 'FAIL' ? '请说明需要整改的内容...' : '可填写验收备注...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ZdRadius.sm),
                ),
              ),
            ),
            const SizedBox(height: ZdSpacing.lg),
            Text(
              '现场照片（选填）',
              style: ZdText.caption.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: ZdSpacing.sm),
            Wrap(
              spacing: ZdSpacing.sm,
              runSpacing: ZdSpacing.sm,
              children: [
                for (final image in _selectedImages)
                  _LocalEvidenceTile(
                    file: image,
                    onRemove: _submitting
                        ? null
                        : () => setState(() {
                            _selectedImages.remove(image);
                            _uploadedUrls.remove(image.path);
                          }),
                  ),
                if (_selectedImages.length < 9)
                  OutlinedButton.icon(
                    key: const Key('owner-inspection-add-photo'),
                    onPressed: _pickingImages || _submitting
                        ? null
                        : _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_pickingImages ? '读取中...' : '添加现场照片'),
                  ),
              ],
            ),
            const SizedBox(height: ZdSpacing.xl),
            ZdPrimaryButton(
              label: _submitting ? '提交中...' : '提交验收',
              onTap: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceBtn(String label, String value, Color color) {
    final selected = _result == value;
    return GestureDetector(
      onTap: _workerSubmission == null || _evidenceLoading
          ? null
          : () => setState(() => _result = value),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.white,
          border: Border.all(
            color: selected ? color : ZdColors.divider,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(ZdRadius.sm),
        ),
        child: Center(
          child: Text(
            label,
            style: ZdText.body.copyWith(
              color: selected ? color : _textMid,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkerEvidence() {
    if (_evidenceLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(ZdSpacing.lg),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: ZdSpacing.sm),
              Text('正在加载师傅本轮验收证据...'),
            ],
          ),
        ),
      );
    }
    if (_evidenceError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(ZdSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _evidenceError!,
                style: ZdText.caption.copyWith(color: _error),
              ),
              TextButton(
                onPressed: _loadWorkerEvidence,
                child: const Text('重新加载证据'),
              ),
            ],
          ),
        ),
      );
    }
    final evidence = _workerSubmission!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZdSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ZdColors.divider),
        borderRadius: BorderRadius.circular(ZdRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, color: _primary),
              const SizedBox(width: ZdSpacing.sm),
              Text(
                '本轮师傅提交',
                style: ZdText.body.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '第 ${evidence.version} 轮',
                style: ZdText.tiny.copyWith(color: _textMid),
              ),
            ],
          ),
          const SizedBox(height: ZdSpacing.sm),
          Text(
            evidence.note?.trim().isNotEmpty == true
                ? evidence.note!
                : '师傅未填写完工说明',
            style: ZdText.caption.copyWith(color: _textMid),
          ),
          const SizedBox(height: ZdSpacing.sm),
          Text(
            '${evidence.photos.length} 张现场照片',
            style: ZdText.tiny.copyWith(color: _textMid),
          ),
          if (evidence.photos.isNotEmpty) ...[
            const SizedBox(height: ZdSpacing.sm),
            Wrap(
              spacing: ZdSpacing.sm,
              runSpacing: ZdSpacing.sm,
              children: evidence.photos
                  .map(
                    (url) => ClipRRect(
                      borderRadius: BorderRadius.circular(ZdRadius.sm),
                      child: Image.network(
                        inspectionEvidenceDisplayUrl(url),
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 88,
                          height: 88,
                          color: ZdColors.background,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: _textLight,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocalEvidenceTile extends StatelessWidget {
  const _LocalEvidenceTile({required this.file, this.onRemove});

  final File file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final filename = file.path.split(Platform.pathSeparator).last;
    return Container(
      key: ValueKey(file.path),
      width: 148,
      padding: const EdgeInsets.all(ZdSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZdRadius.sm),
        border: Border.all(color: ZdColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_outlined, color: _primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              filename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ZdText.tiny,
            ),
          ),
          if (onRemove != null)
            InkWell(
              onTap: onRemove,
              child: const Icon(Icons.close, size: 18, color: _textMid),
            ),
        ],
      ),
    );
  }
}

// ── 验收记录子页 ──
class _InspectionRecordsPage extends StatefulWidget {
  const _InspectionRecordsPage({required this.nodeId, this.api});
  final String nodeId;
  final InspectionApi? api;

  @override
  State<_InspectionRecordsPage> createState() => _InspectionRecordsPageState();
}

class _InspectionRecordsPageState extends State<_InspectionRecordsPage> {
  List<RemoteInspectionTimelineEvent> _timeline = const [];
  bool _loading = true;
  bool _loadStarted = false;
  String? _errorMsg;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMsg = null;
      });
    }
    final state = OwnerAppScope.of(context);
    final token = await state.getAccessToken();
    if (token == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = '未登录';
        });
      }
      return;
    }
    try {
      final api = widget.api ?? InspectionApiClient();
      final timeline = await api.getInspectionTimeline(token, widget.nodeId);
      if (mounted) {
        setState(() {
          _timeline = [...timeline]
            ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
          _loading = false;
        });
      }
    } on AuthApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = '加载失败：$e';
        });
      }
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
          : _errorMsg != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _errorMsg!,
                    style: ZdText.caption.copyWith(color: _textMid),
                  ),
                  const SizedBox(height: ZdSpacing.sm),
                  TextButton(
                    onPressed: _loadRecords,
                    child: const Text('重新加载'),
                  ),
                ],
              ),
            )
          : _timeline.isEmpty
          ? Center(
              child: Text(
                '暂无验收记录',
                style: ZdText.caption.copyWith(color: _textLight),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(ZdSpacing.md),
              itemCount: _timeline.length,
              itemBuilder: (ctx, i) => _TimelineItem(event: _timeline[i]),
            ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.event});
  final RemoteInspectionTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final isWorker = event.isWorkerSubmission;
    final color = isWorker
        ? _primary
        : event.isPassed
        ? _success
        : _error;
    final label = isWorker
        ? '待业主验收'
        : event.isPassed
        ? '已通过'
        : '整改';
    return ZdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ZdRadius.sm),
                ),
                child: Icon(
                  isWorker
                      ? Icons.handyman_outlined
                      : event.isPassed
                      ? Icons.check_circle_outline
                      : Icons.replay_circle_filled_outlined,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: ZdSpacing.md),
              Expanded(
                child: Text(
                  '第 ${event.version} 轮 · ${isWorker ? '师傅提交' : '业主验收'}',
                  style: ZdText.subtitle,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ZdRadius.pill),
                ),
                child: Text(label, style: ZdText.tiny.copyWith(color: color)),
              ),
            ],
          ),
          if (event.note != null && event.note!.trim().isNotEmpty) ...[
            const SizedBox(height: ZdSpacing.sm),
            Text(event.note!, style: ZdText.caption),
          ],
          if (event.photos.isNotEmpty) ...[
            const SizedBox(height: ZdSpacing.sm),
            _RemoteEvidenceGrid(photos: event.photos),
          ],
          const SizedBox(height: 6),
          Text(
            _formatInspectionTime(event.createdAt),
            style: ZdText.tiny.copyWith(color: _textLight),
          ),
        ],
      ),
    );
  }
}

class _RemoteEvidenceGrid extends StatelessWidget {
  const _RemoteEvidenceGrid({required this.photos});

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ZdSpacing.sm,
      runSpacing: ZdSpacing.sm,
      children: photos
          .map(
            (url) => GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  child: InteractiveViewer(
                    child: Image.network(
                      inspectionEvidenceDisplayUrl(url),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox(
                        width: 240,
                        height: 180,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ZdRadius.sm),
                child: Image.network(
                  inspectionEvidenceDisplayUrl(url),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 72,
                    height: 72,
                    color: ZdColors.background,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

String _formatInspectionTime(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

// ============================================================
// 业主端 — 施工日报查看页
// ============================================================

class OwnerDailyReportViewPage extends StatefulWidget {
  const OwnerDailyReportViewPage({
    super.key,
    required this.bookingId,
    this.initialReportId,
    this.api,
  });
  final String bookingId;
  final String? initialReportId;
  final DailyReportApi? api;

  @override
  State<OwnerDailyReportViewPage> createState() =>
      _OwnerDailyReportViewPageState();
}

class _OwnerDailyReportViewPageState extends State<OwnerDailyReportViewPage> {
  late final DailyReportApi _api;
  List<RemoteDailyReport> _reports = const [];
  bool _loading = true;
  String? _errorText;
  bool _loadStarted = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? DailyReportApiClient();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final state = OwnerAppScope.of(context);
      final token = await state.getAccessToken();
      if (token == null) {
        if (mounted) {
          setState(() {
            _errorText = '未登录';
            _loading = false;
          });
        }
        return;
      }
      final list = await _api.getReportsByBooking(token, widget.bookingId);
      if (mounted) {
        setState(() {
          final initialReportId = widget.initialReportId?.trim();
          _reports = initialReportId == null || initialReportId.isEmpty
              ? list
              : list
                    .where(
                      (report) =>
                          report.id == initialReportId &&
                          report.bookingId == widget.bookingId,
                    )
                    .toList(growable: false);
          if (initialReportId != null &&
              initialReportId.isNotEmpty &&
              _reports.isEmpty) {
            _errorText = '该记录已更新或不再可用';
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('施工日报'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
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
          ? const Center(
              child: Text(
                '暂无施工日报',
                style: TextStyle(color: _textMid, fontSize: 15),
              ),
            )
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
                          const Icon(
                            Icons.article_outlined,
                            size: 16,
                            color: _primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            r.reportDate,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (r.photos.isNotEmpty)
                            const Icon(
                              Icons.photo_library_outlined,
                              size: 14,
                              color: _textMid,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        r.content,
                        style: const TextStyle(fontSize: 14, color: _textDark),
                      ),
                      if (r.photos.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: r.photos
                              .map(
                                (url) => ClipRRect(
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
                                      child: const Icon(
                                        Icons.broken_image,
                                        color: _textMid,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
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
