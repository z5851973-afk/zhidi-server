// ============================================================
// 工匠端 — 施工日报提交页（V14 API）
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/worker_app_scope.dart';
import '../../app/worker_app_state.dart';
import '../../design/tokens.dart';
import '../../design/components.dart';
import '../../services/daily_report_api_client.dart';
import '../../services/auth_api_client.dart';
import '../../services/upload_api_client.dart';

const _primary = ZdColors.primary;
const _textDark = ZdColors.textPrimary;
const _textLight = ZdColors.textHint;
const _divider = ZdColors.divider;

Future<List<String>> uploadDailyReportImages(
  List<XFile> images,
  Future<String> Function(File file) upload,
) async {
  final urls = <String>[];
  for (final image in images) {
    urls.add(await upload(File(image.path)));
  }
  return urls;
}

final class DailyReportImageUploadBatch {
  const DailyReportImageUploadBatch({
    required this.uploadedUrls,
    required this.errors,
  });

  final Map<String, String> uploadedUrls;
  final Map<String, Object> errors;

  Set<String> get failedPaths => errors.keys.toSet();

  List<String> orderedUrls(List<XFile> images) => [
    for (final image in images) uploadedUrls[image.path]!,
  ];
}

Future<DailyReportImageUploadBatch> uploadPendingDailyReportImages(
  List<XFile> images,
  Map<String, String> existingUrls,
  Future<String> Function(File file) upload,
) async {
  final uploaded = <String, String>{};
  final errors = <String, Object>{};
  for (final image in images) {
    final existing = existingUrls[image.path];
    if (existing != null && existing.isNotEmpty) {
      uploaded[image.path] = existing;
      continue;
    }
    try {
      uploaded[image.path] = await upload(File(image.path));
    } catch (error) {
      errors[image.path] = error;
    }
  }
  return DailyReportImageUploadBatch(
    uploadedUrls: Map.unmodifiable(uploaded),
    errors: Map.unmodifiable(errors),
  );
}

class DailyReportPage extends StatefulWidget {
  const DailyReportPage({
    super.key,
    required this.orderId,
    this.readOnly = false,
    this.api,
    this.pickImages,
    this.uploadImage,
  });
  final String orderId;
  final bool readOnly;
  final DailyReportApi? api;
  final Future<List<XFile>> Function()? pickImages;
  final Future<String> Function(File file, String accessToken)? uploadImage;

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  final _contentCtrl = TextEditingController();
  DateTime _reportDate = DateTime.now();
  bool _submitting = false;
  bool _pickingImages = false;
  final List<XFile> _selectedImages = [];
  Map<String, String> _uploadedUrlsByPath = const {};
  Set<String> _failedUploadPaths = const {};
  List<RemoteDailyReport> _reports = const [];
  bool _loadingReports = true;
  String? _reportsError;
  bool _didLoadReports = false;
  String? _observedAccessToken;
  int _reportLoadEpoch = 0;
  String? _uploadCacheToken;
  String? _uploadCacheBookingId;
  int _submitEpoch = 0;
  int _draftEpoch = 0;
  int _pickEpoch = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final accessToken = WorkerAppScope.of(context).getAccessToken();
    if (_observedAccessToken != accessToken) {
      final hadObservedSession = _didLoadReports;
      _observedAccessToken = accessToken;
      _reportLoadEpoch += 1;
      _submitEpoch += 1;
      _draftEpoch += 1;
      _pickEpoch += 1;
      _submitting = false;
      _pickingImages = false;
      _reports = const [];
      _reportsError = null;
      _loadingReports = true;
      _uploadedUrlsByPath = const {};
      _failedUploadPaths = const {};
      _uploadCacheToken = null;
      _uploadCacheBookingId = null;
      if (hadObservedSession) {
        _selectedImages.clear();
        _contentCtrl.clear();
      }
      _didLoadReports = true;
      _loadReports();
      return;
    }
    if (_didLoadReports) return;
    _didLoadReports = true;
    _loadReports();
  }

  @override
  void didUpdateWidget(covariant DailyReportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId == widget.orderId && oldWidget.api == widget.api) {
      return;
    }
    _reportLoadEpoch += 1;
    _submitEpoch += 1;
    _draftEpoch += 1;
    _pickEpoch += 1;
    _submitting = false;
    _pickingImages = false;
    _reports = const [];
    _reportsError = null;
    _loadingReports = true;
    _selectedImages.clear();
    _contentCtrl.clear();
    _uploadedUrlsByPath = const {};
    _failedUploadPaths = const {};
    _uploadCacheToken = null;
    _uploadCacheBookingId = null;
    _loadReports();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    final loadEpoch = ++_reportLoadEpoch;
    final requestBookingId = widget.orderId;
    if (mounted) {
      setState(() {
        _loadingReports = true;
        _reportsError = null;
      });
    }
    final state = WorkerAppScope.of(context);
    final token = state.getAccessToken();
    if (token == null) {
      if (mounted) {
        setState(() {
          _loadingReports = false;
          _reportsError = '登录已过期，请重新登录';
        });
      }
      return;
    }
    try {
      final api = widget.api ?? DailyReportApiClient();
      final list = await api.getReportsByBooking(token, requestBookingId);
      if (widget.orderId != requestBookingId || loadEpoch != _reportLoadEpoch) {
        return;
      }
      if (state.getAccessToken() != token) {
        if (mounted) {
          setState(() {
            _reports = const [];
            _loadingReports = false;
            _reportsError = '登录账号已切换，请重新加载';
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _reports = list;
          _loadingReports = false;
          _reportsError = null;
        });
      }
    } catch (_) {
      if (loadEpoch != _reportLoadEpoch || widget.orderId != requestBookingId) {
        return;
      }
      if (mounted) {
        setState(() {
          if (state.getAccessToken() != token) _reports = const [];
          _loadingReports = false;
          _reportsError = state.getAccessToken() == token
              ? '施工记录加载失败'
              : '登录账号已切换，请重新加载';
        });
      }
    }
  }

  Future<void> _pickImages() async {
    if (_pickingImages || _selectedImages.length >= 9) return;
    final state = WorkerAppScope.of(context);
    final accessToken = state.getAccessToken();
    final bookingId = widget.orderId;
    final draftEpoch = _draftEpoch;
    final pickEpoch = ++_pickEpoch;
    setState(() => _pickingImages = true);
    try {
      final images =
          await (widget.pickImages?.call() ??
              ImagePicker().pickMultiImage(imageQuality: 82));
      if (!_isCurrentPicker(
        pickEpoch,
        draftEpoch,
        state,
        accessToken,
        bookingId,
      )) {
        return;
      }
      setState(() {
        for (final image in images) {
          if (_selectedImages.length >= 9) break;
          if (_selectedImages.every(
            (existing) => existing.path != image.path,
          )) {
            _selectedImages.add(image);
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      if (!_isCurrentPicker(
        pickEpoch,
        draftEpoch,
        state,
        accessToken,
        bookingId,
      )) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('读取照片失败，请检查相册权限')));
    } finally {
      if (_isCurrentPicker(
        pickEpoch,
        draftEpoch,
        state,
        accessToken,
        bookingId,
      )) {
        setState(() => _pickingImages = false);
      }
    }
  }

  bool _isCurrentPicker(
    int pickEpoch,
    int draftEpoch,
    WorkerAppState state,
    String? accessToken,
    String bookingId,
  ) =>
      mounted &&
      pickEpoch == _pickEpoch &&
      draftEpoch == _draftEpoch &&
      widget.orderId == bookingId &&
      state.getAccessToken() == accessToken;

  Future<String> _uploadImage(File file, String accessToken) async {
    final injected = widget.uploadImage;
    if (injected != null) return injected(file, accessToken);
    final result = await UploadApiClient().uploadImage(
      file,
      accessToken: accessToken,
      category: 'daily-reports',
    );
    return result.url;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写日报内容')));
      return;
    }
    final state = WorkerAppScope.of(context);
    final token = state.getAccessToken();
    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录已过期')));
      return;
    }
    final orderId = widget.orderId;
    final selectedImages = List<XFile>.unmodifiable(_selectedImages);
    final reportDate = _reportDate;
    final submitEpoch = ++_submitEpoch;
    setState(() => _submitting = true);
    try {
      final reusableUploads =
          _uploadCacheToken == token && _uploadCacheBookingId == orderId
          ? _uploadedUrlsByPath
          : const <String, String>{};
      final uploadBatch = await uploadPendingDailyReportImages(
        selectedImages,
        reusableUploads,
        (file) => _uploadImage(file, token),
      );
      if (!_isCurrentSubmission(submitEpoch, state, token, orderId)) return;
      if (mounted) {
        setState(() {
          _uploadedUrlsByPath = uploadBatch.uploadedUrls;
          _failedUploadPaths = uploadBatch.failedPaths;
          _uploadCacheToken = token;
          _uploadCacheBookingId = orderId;
        });
      }
      if (uploadBatch.failedPaths.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${uploadBatch.failedPaths.length} 张照片上传失败，请点击提交重试',
              ),
            ),
          );
        }
        return;
      }
      final photoUrls = uploadBatch.orderedUrls(selectedImages);
      final dateStr =
          '${reportDate.year}-${reportDate.month.toString().padLeft(2, '0')}-${reportDate.day.toString().padLeft(2, '0')}';
      final api = widget.api ?? DailyReportApiClient();
      await api.submitReport(token, orderId, dateStr, content, photoUrls);
      if (!_isCurrentSubmission(submitEpoch, state, token, orderId)) return;
      if (_contentCtrl.text.trim() == content) _contentCtrl.clear();
      final submittedPaths = selectedImages.map((image) => image.path).toSet();
      _selectedImages.removeWhere(
        (image) => submittedPaths.contains(image.path),
      );
      _uploadedUrlsByPath = Map.of(_uploadedUrlsByPath)
        ..removeWhere((path, _) => submittedPaths.contains(path));
      _failedUploadPaths = Set.of(_failedUploadPaths)
        ..removeWhere(submittedPaths.contains);
      _uploadCacheToken = null;
      _uploadCacheBookingId = null;
      await _loadReports();
      if (mounted && _isCurrentSubmission(submitEpoch, state, token, orderId)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('日报已提交')));
      }
    } on AuthApiException catch (e) {
      if (mounted && _isCurrentSubmission(submitEpoch, state, token, orderId)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted && _isCurrentSubmission(submitEpoch, state, token, orderId)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('提交失败：$e')));
      }
    } finally {
      if (mounted && _isCurrentSubmission(submitEpoch, state, token, orderId)) {
        setState(() => _submitting = false);
      }
    }
  }

  bool _isCurrentSubmission(
    int submitEpoch,
    WorkerAppState state,
    String accessToken,
    String bookingId,
  ) {
    return mounted &&
        submitEpoch == _submitEpoch &&
        widget.orderId == bookingId &&
        state.getAccessToken() == accessToken;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: Text(widget.readOnly ? '施工记录' : '施工日报'),
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.readOnly)
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(ZdRadius.sm),
                        ),
                        contentPadding: const EdgeInsets.all(ZdSpacing.md),
                      ),
                    ),
                    const SizedBox(height: ZdSpacing.md),
                    _label('现场照片（最多9张）'),
                    const SizedBox(height: ZdSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (
                          var index = 0;
                          index < _selectedImages.length;
                          index++
                        )
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  ZdRadius.sm,
                                ),
                                child: Image.file(
                                  File(_selectedImages[index].path),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 2,
                                top: 2,
                                child: GestureDetector(
                                  key: Key('remove-report-photo-$index'),
                                  onTap: () => setState(() {
                                    final removed = _selectedImages.removeAt(
                                      index,
                                    );
                                    _uploadedUrlsByPath = Map.of(
                                      _uploadedUrlsByPath,
                                    )..remove(removed.path);
                                    _failedUploadPaths = Set.of(
                                      _failedUploadPaths,
                                    )..remove(removed.path);
                                  }),
                                  child: const CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.black54,
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              if (_uploadedUrlsByPath.containsKey(
                                _selectedImages[index].path,
                              ))
                                const Positioned(
                                  left: 3,
                                  bottom: 3,
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: ZdColors.success,
                                    child: Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              else if (_failedUploadPaths.contains(
                                _selectedImages[index].path,
                              ))
                                const Positioned(
                                  left: 3,
                                  bottom: 3,
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: ZdColors.error,
                                    child: Icon(
                                      Icons.priority_high,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        if (_selectedImages.length < 9)
                          GestureDetector(
                            key: const Key('add-report-photos'),
                            onTap: _pickingImages ? null : _pickImages,
                            child: Container(
                              height: 80,
                              width: 80,
                              decoration: BoxDecoration(
                                color: ZdColors.background,
                                borderRadius: BorderRadius.circular(
                                  ZdRadius.sm,
                                ),
                                border: Border.all(color: _divider),
                              ),
                              child: Center(
                                child: _pickingImages
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: _textLight,
                                        size: 28,
                                      ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_failedUploadPaths.isNotEmpty) ...[
                      const SizedBox(height: ZdSpacing.sm),
                      Text(
                        '${_failedUploadPaths.length} 张照片未上传成功；再次提交只重试失败照片。',
                        style: ZdText.tiny.copyWith(color: ZdColors.error),
                      ),
                    ],
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
                padding: const EdgeInsets.fromLTRB(
                  ZdSpacing.lg,
                  ZdSpacing.xl,
                  ZdSpacing.lg,
                  ZdSpacing.md,
                ),
                child: Text(
                  widget.readOnly
                      ? '施工记录（${_reports.length}）'
                      : '历史日报（${_reports.length}）',
                  style: ZdText.subtitle,
                ),
              ),
            ..._reports.map((r) => _ReportItem(report: r)),
            if (_reportsError != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZdSpacing.lg,
                  vertical: ZdSpacing.sm,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(ZdSpacing.md),
                  decoration: BoxDecoration(
                    color: ZdColors.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(ZdRadius.sm),
                    border: Border.all(
                      color: ZdColors.error.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 20,
                        color: ZdColors.error,
                      ),
                      const SizedBox(width: ZdSpacing.sm),
                      Expanded(
                        child: Text(_reportsError!, style: ZdText.caption),
                      ),
                      TextButton(
                        onPressed: _loadReports,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_loadingReports && _reports.isEmpty)
              const Padding(
                padding: EdgeInsets.all(ZdSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_loadingReports && _reports.isEmpty && _reportsError == null)
              Padding(
                padding: const EdgeInsets.all(ZdSpacing.xl),
                child: Center(
                  child: Text(
                    widget.readOnly ? '暂无施工记录' : '暂无日报记录',
                    style: ZdText.caption.copyWith(color: _textLight),
                  ),
                ),
              ),
            const SizedBox(height: ZdSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: ZdText.caption.copyWith(fontWeight: FontWeight.w500),
    );
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
                Expanded(
                  child: Text(
                    '${report.reportDate} · 第${report.reportRevision}版',
                    style: ZdText.subtitle,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ZdRadius.pill),
                  ),
                  child: Text(
                    '已提交',
                    style: ZdText.tiny.copyWith(color: _primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZdSpacing.sm),
            Text(report.content, style: ZdText.body),
            const SizedBox(height: 4),
            Text(
              '提交于 ${_formatReportTime(report.createdAt)}',
              style: ZdText.tiny.copyWith(color: _textLight),
            ),
            if (report.photos.isNotEmpty) ...[
              const SizedBox(height: ZdSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < report.photos.length; index++)
                    _ReportPhoto(
                      key: Key('worker-report-photo-${report.id}-$index'),
                      reportId: report.id,
                      index: index,
                      url: report.photos[index],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportPhoto extends StatefulWidget {
  const _ReportPhoto({
    super.key,
    required this.reportId,
    required this.index,
    required this.url,
  });

  final String reportId;
  final int index;
  final String url;

  @override
  State<_ReportPhoto> createState() => _ReportPhotoState();
}

class _ReportPhotoState extends State<_ReportPhoto> {
  int _attempt = 0;

  Future<void> _retry() async {
    await NetworkImage(dailyReportPhotoDisplayUrl(widget.url)).evict();
    if (mounted) setState(() => _attempt += 1);
  }

  @override
  Widget build(BuildContext context) {
    final displayUrl = dailyReportPhotoDisplayUrl(widget.url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(ZdRadius.sm),
      child: Image.network(
        displayUrl,
        key: Key(
          'worker-report-photo-image-${widget.reportId}-${widget.index}-attempt-$_attempt',
        ),
        width: 88,
        height: 88,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => InkWell(
          key: Key(
            'retry-worker-report-photo-${widget.reportId}-${widget.index}',
          ),
          onTap: _retry,
          child: Container(
            width: 88,
            height: 88,
            color: ZdColors.background,
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, color: _textLight, size: 22),
                SizedBox(height: 4),
                Text('重试图片', style: TextStyle(fontSize: 10, color: _textLight)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatReportTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
