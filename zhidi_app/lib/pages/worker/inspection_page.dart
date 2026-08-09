// ============================================================
// 工匠端 — 节点验收管理页（V14 API）
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/worker_app_scope.dart';
import '../../design/tokens.dart';
import '../../design/components.dart';
import '../../services/inspection_api_client.dart';
import '../../services/inspection_evidence_upload.dart';
import '../../services/auth_api_client.dart';

const _primary = ZdColors.primary;
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _textLight = ZdColors.textHint;
const _success = ZdColors.success;
const _error = ZdColors.error;

class InspectionPage extends StatefulWidget {
  const InspectionPage({
    super.key,
    required this.orderId,
    required this.tradeLabel,
    this.readOnly = false,
    this.initialNodeId,
    this.api,
    this.pickImages,
    this.uploadImage,
  });

  final String orderId;
  final String tradeLabel;
  final bool readOnly;
  final String? initialNodeId;
  final InspectionApi? api;
  final InspectionImagePicker? pickImages;
  final InspectionImageUploader? uploadImage;

  @override
  State<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends State<InspectionPage> {
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
    final state = WorkerAppScope.of(context);
    final token = state.getAccessToken();
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
      final nodes = await api.getNodes(token, widget.orderId);
      final visibleNodes = _nodesForCurrentTrade(nodes);
      if (visibleNodes.isEmpty) {
        if (widget.readOnly) {
          if (mounted) {
            setState(() {
              _nodes = const [];
              _loading = false;
            });
          }
          return;
        }
        final created = await _createDefaultNodes(token);
        if (mounted) {
          setState(() {
            _nodes = _nodesForCurrentTrade(created);
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _nodes = visibleNodes;
            _loading = false;
          });
        }
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

  Future<List<RemoteInspectionNode>> _createDefaultNodes(String token) async {
    final api = widget.api ?? InspectionApiClient();
    final node = _defaultNodeForTrade(widget.tradeLabel);
    return await api.createNodes(token, widget.orderId, [node]);
  }

  List<RemoteInspectionNode> _nodesForCurrentTrade(
    List<RemoteInspectionNode> nodes,
  ) {
    final tradeNodes = inspectionNodesForTrade(nodes, widget.tradeLabel);
    final initialNodeId = widget.initialNodeId?.trim();
    if (initialNodeId == null || initialNodeId.isEmpty) return tradeNodes;
    return tradeNodes
        .where(
          (node) =>
              node.id == initialNodeId && node.bookingId == widget.orderId,
        )
        .toList(growable: false);
  }

  void _openSubmissionForm(RemoteInspectionNode node) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _WorkerInspectionSubmissionPage(
          node: node,
          api: widget.api,
          pickImages: widget.pickImages,
          uploadImage: widget.uploadImage,
          onSubmitted: _loadNodes,
        ),
      ),
    );
  }

  void _openTimeline(RemoteInspectionNode node) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _WorkerInspectionTimelinePage(nodeId: node.id, api: widget.api),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: Text(widget.readOnly ? '验收记录' : '节点验收'),
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
            Text('暂无验收节点', style: ZdText.caption.copyWith(color: _textLight)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(ZdSpacing.md),
      itemCount: _nodes.length,
      itemBuilder: (ctx, i) => _NodeCard(
        node: _nodes[i],
        onRequestInspection: widget.readOnly
            ? null
            : () => _openSubmissionForm(_nodes[i]),
        onViewTimeline: _nodes[i].status == 'PENDING'
            ? null
            : () => _openTimeline(_nodes[i]),
      ),
    );
  }
}

Map<String, dynamic> _defaultNodeForTrade(String tradeLabel) {
  final normalized = normalizeInspectionTradeLabel(tradeLabel);
  final description = switch (normalized) {
    '拆除' => '拆除范围、清运和现场安全验收',
    '水电' => '水管、电路布线验收',
    '泥瓦' => '贴砖、砌墙、地面找平验收',
    '防水' => '防水涂刷、闭水和节点验收',
    '木工' => '吊顶、柜体结构验收',
    '油漆' => '墙面平整度、颜色均匀度验收',
    '安装' => '灯具、洁具、五金安装验收',
    '保洁' => '全屋清洁、细节收尾验收',
    _ => '$normalized施工质量验收',
  };
  return {'name': '$normalized验收', 'description': description, 'sortOrder': 1};
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.node,
    required this.onRequestInspection,
    required this.onViewTimeline,
  });
  final RemoteInspectionNode node;
  final VoidCallback? onRequestInspection;
  final VoidCallback? onViewTimeline;

  Color get _statusColor {
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

  String get _statusLabel {
    switch (node.status) {
      case 'PENDING':
        return '待验收';
      case 'INSPECTING':
        return '等待业主验收';
      case 'PASSED':
        return '已通过';
      case 'FAILED':
        return '未通过';
      default:
        return node.status;
    }
  }

  IconData get _statusIcon {
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
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ZdRadius.sm),
                ),
                child: Icon(_statusIcon, color: _statusColor, size: 20),
              ),
              const SizedBox(width: ZdSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node.name, style: ZdText.subtitle),
                    if (node.description != null &&
                        node.description!.isNotEmpty)
                      Text(
                        node.description!,
                        style: ZdText.tiny,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ZdRadius.pill),
                ),
                child: Text(
                  _statusLabel,
                  style: ZdText.tiny.copyWith(
                    color: _statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (node.status == 'PENDING' && onRequestInspection != null) ...[
            const SizedBox(height: ZdSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRequestInspection,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ZdRadius.pill),
                  ),
                ),
                child: const Text('申请验收'),
              ),
            ),
          ],
          if (node.status == 'FAILED') ...[
            const SizedBox(height: ZdSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ZdSpacing.sm),
              decoration: BoxDecoration(
                color: _error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(ZdRadius.sm),
              ),
              child: Text(
                '验收未通过，请整改后重新申请',
                style: ZdText.tiny.copyWith(color: _error),
              ),
            ),
            if (onRequestInspection != null) ...[
              const SizedBox(height: ZdSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onRequestInspection,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ZdRadius.pill),
                    ),
                  ),
                  child: const Text('申请重新验收'),
                ),
              ),
            ],
          ],
          if (onViewTimeline != null) ...[
            const SizedBox(height: ZdSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onViewTimeline,
                icon: const Icon(Icons.timeline_outlined),
                label: const Text('查看验收时间线'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkerInspectionSubmissionPage extends StatefulWidget {
  const _WorkerInspectionSubmissionPage({
    required this.node,
    required this.onSubmitted,
    this.api,
    this.pickImages,
    this.uploadImage,
  });

  final RemoteInspectionNode node;
  final Future<void> Function() onSubmitted;
  final InspectionApi? api;
  final InspectionImagePicker? pickImages;
  final InspectionImageUploader? uploadImage;

  @override
  State<_WorkerInspectionSubmissionPage> createState() =>
      _WorkerInspectionSubmissionPageState();
}

class _WorkerInspectionSubmissionPageState
    extends State<_WorkerInspectionSubmissionPage> {
  final _noteController = TextEditingController();
  final List<File> _selectedImages = [];
  final Map<String, String> _uploadedUrls = {};
  bool _pickingImages = false;
  bool _submitting = false;

  bool get _isReinspection => widget.node.isFailed;
  bool get _canSubmit =>
      !_submitting &&
      (!_isReinspection || _noteController.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_onNoteChanged);
  }

  void _onNoteChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
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
      final state = WorkerAppScope.of(context);
      final token = state.getAccessToken();
      if (token == null) {
        throw const AuthApiException(code: 'UNAUTHORIZED', message: '登录已过期');
      }
      for (final image in _selectedImages) {
        if (_uploadedUrls.containsKey(image.path)) continue;
        final uploader = widget.uploadImage ?? uploadInspectionImage;
        _uploadedUrls[image.path] = await uploader(
          image,
          token,
          widget.node.id,
        );
        if (state.getAccessToken() != token) {
          _uploadedUrls.clear();
          throw const AuthApiException(
            code: 'SESSION_CHANGED',
            message: '登录账号已切换，请重新选择照片并提交',
          );
        }
      }
      final photos = _selectedImages
          .map((image) => _uploadedUrls[image.path]!)
          .toList(growable: false);
      final api = widget.api ?? InspectionApiClient();
      final note = _noteController.text.trim();
      if (state.getAccessToken() != token) {
        _uploadedUrls.clear();
        throw const AuthApiException(
          code: 'SESSION_CHANGED',
          message: '登录账号已切换，请重新提交验收申请',
        );
      }
      await api.requestInspectionWithEvidence(
        token,
        widget.node.id,
        note.isEmpty ? null : note,
        photos,
      );
      await widget.onSubmitted();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isReinspection ? '已提交复验申请' : '已申请验收')),
      );
      Navigator.pop(context);
    } on AuthApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('提交失败：$error')));
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
        title: Text(_isReinspection ? '申请重新验收' : '提交验收申请'),
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZdSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.node.name, style: ZdText.subtitle),
            const SizedBox(height: ZdSpacing.lg),
            Text(
              _isReinspection ? '整改说明' : '完工说明（选填）',
              style: ZdText.caption.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: ZdSpacing.sm),
            TextField(
              controller: _noteController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: _isReinspection ? '请说明已完成的整改内容' : '可说明本次完工内容',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ZdRadius.sm),
                ),
              ),
            ),
            if (_isReinspection && _noteController.text.trim().isEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '重新申请验收时必须填写整改说明',
                style: ZdText.tiny.copyWith(color: _error),
              ),
            ],
            const SizedBox(height: ZdSpacing.lg),
            Text(
              _isReinspection ? '整改照片（选填）' : '现场照片（选填）',
              style: ZdText.caption.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: ZdSpacing.sm),
            Wrap(
              spacing: ZdSpacing.sm,
              runSpacing: ZdSpacing.sm,
              children: [
                for (final image in _selectedImages)
                  _WorkerEvidenceTile(
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
                    onPressed: _pickingImages || _submitting
                        ? null
                        : _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      _pickingImages
                          ? '读取中...'
                          : _isReinspection
                          ? '添加整改照片'
                          : '添加现场照片',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: ZdSpacing.xl),
            ZdPrimaryButton(
              label: _submitting
                  ? '提交中...'
                  : _isReinspection
                  ? '提交复验申请'
                  : '提交验收申请',
              onTap: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerEvidenceTile extends StatelessWidget {
  const _WorkerEvidenceTile({required this.file, this.onRemove});

  final File file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final filename = file.path.split(Platform.pathSeparator).last;
    return Container(
      width: 148,
      padding: const EdgeInsets.all(ZdSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ZdColors.divider),
        borderRadius: BorderRadius.circular(ZdRadius.sm),
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
            InkWell(onTap: onRemove, child: const Icon(Icons.close, size: 18)),
        ],
      ),
    );
  }
}

class _WorkerInspectionTimelinePage extends StatefulWidget {
  const _WorkerInspectionTimelinePage({required this.nodeId, this.api});

  final String nodeId;
  final InspectionApi? api;

  @override
  State<_WorkerInspectionTimelinePage> createState() =>
      _WorkerInspectionTimelinePageState();
}

class _WorkerInspectionTimelinePageState
    extends State<_WorkerInspectionTimelinePage> {
  List<RemoteInspectionTimelineEvent> _timeline = const [];
  bool _loading = true;
  String? _errorMessage;
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    _load();
  }

  Future<void> _load() async {
    final token = WorkerAppScope.of(context).getAccessToken();
    if (token == null) {
      if (mounted) setState(() => _errorMessage = '未登录');
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
    } on AuthApiException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = error.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = '加载失败：$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text('验收时间线'),
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _timeline.isEmpty
          ? const Center(child: Text('暂无验收记录'))
          : ListView.builder(
              padding: const EdgeInsets.all(ZdSpacing.md),
              itemCount: _timeline.length,
              itemBuilder: (_, index) =>
                  _WorkerTimelineItem(event: _timeline[index]),
            ),
    );
  }
}

class _WorkerTimelineItem extends StatelessWidget {
  const _WorkerTimelineItem({required this.event});

  final RemoteInspectionTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final worker = event.isWorkerSubmission;
    final color = worker
        ? _primary
        : event.isPassed
        ? _success
        : _error;
    return ZdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                worker ? Icons.handyman_outlined : Icons.fact_check_outlined,
                color: color,
              ),
              const SizedBox(width: ZdSpacing.sm),
              Expanded(
                child: Text(
                  '第 ${event.version} 轮 · ${worker ? '师傅提交' : '业主验收'}',
                  style: ZdText.subtitle,
                ),
              ),
              if (!worker)
                Text(
                  event.isPassed ? '已通过' : '需整改',
                  style: ZdText.tiny.copyWith(color: color),
                ),
            ],
          ),
          if (event.note != null && event.note!.trim().isNotEmpty) ...[
            const SizedBox(height: ZdSpacing.sm),
            Text(event.note!, style: ZdText.caption),
          ],
          if (event.photos.isNotEmpty) ...[
            const SizedBox(height: ZdSpacing.sm),
            Wrap(
              spacing: ZdSpacing.sm,
              runSpacing: ZdSpacing.sm,
              children: event.photos
                  .map(
                    (url) => ClipRRect(
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
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            _formatWorkerInspectionTime(event.createdAt),
            style: ZdText.tiny.copyWith(color: _textLight),
          ),
        ],
      ),
    );
  }
}

String _formatWorkerInspectionTime(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
