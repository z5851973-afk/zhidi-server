import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../design/tokens.dart';
import '../../services/auth_api_client.dart';
import '../../services/worker_case_api_client.dart';

final class PickedCaseImage {
  const PickedCaseImage({required this.filename, required this.bytes});

  final String filename;
  final List<int> bytes;
}

typedef WorkerCaseImagePicker = Future<List<PickedCaseImage>> Function();

class WorkerCaseEditPage extends StatefulWidget {
  const WorkerCaseEditPage({
    super.key,
    required this.api,
    required this.accessToken,
    required this.initialCity,
    this.existing,
    this.imagePicker,
  });

  final WorkerCaseApi api;
  final String accessToken;
  final String initialCity;
  final RemoteWorkerCase? existing;
  final WorkerCaseImagePicker? imagePicker;

  @override
  State<WorkerCaseEditPage> createState() => _WorkerCaseEditPageState();
}

class _WorkerCaseEditPageState extends State<WorkerCaseEditPage> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _city;
  late final TextEditingController _year;
  late List<String> _existingImages;
  final List<PickedCaseImage> _pickedImages = [];
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _description = TextEditingController(text: existing?.description ?? '');
    _city = TextEditingController(
      text: existing?.serviceCity ?? widget.initialCity,
    );
    _year = TextEditingController(
      text: (existing?.completionYear ?? DateTime.now().year).toString(),
    );
    _existingImages = [...?existing?.imageUrls];
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _city.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<List<PickedCaseImage>> _pickFromGallery() async {
    final files = await ImagePicker().pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
    );
    final result = <PickedCaseImage>[];
    for (final file in files) {
      result.add(
        PickedCaseImage(filename: file.name, bytes: await file.readAsBytes()),
      );
    }
    return result;
  }

  Future<void> _pickImages() async {
    try {
      final picked = await (widget.imagePicker ?? _pickFromGallery)();
      final available = 6 - _existingImages.length - _pickedImages.length;
      if (!mounted || picked.isEmpty) return;
      if (available <= 0) {
        _show('每个案例最多上传 6 张图片');
        return;
      }
      setState(() => _pickedImages.addAll(picked.take(available)));
      if (picked.length > available) _show('已保留前 $available 张图片');
    } catch (_) {
      if (mounted) _show('读取图片失败，请重试');
    }
  }

  String? _validate() {
    if (_title.text.trim().isEmpty) return '请填写案例标题';
    if (_description.text.trim().isEmpty) return '请填写案例说明';
    if (_city.text.trim().isEmpty) return '请填写施工城市';
    final year = int.tryParse(_year.text.trim());
    if (year == null || year < 2000 || year > DateTime.now().year) {
      return '完工年份请输入 2000 到 ${DateTime.now().year}';
    }
    if (_existingImages.isEmpty && _pickedImages.isEmpty) {
      return '请至少选择 1 张案例图片';
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      _show(error);
      return;
    }
    setState(() => _saving = true);
    try {
      final imageUrls = [..._existingImages];
      for (final image in _pickedImages) {
        imageUrls.add(
          await widget.api.uploadImage(
            widget.accessToken,
            filename: image.filename,
            bytes: image.bytes,
          ),
        );
      }
      final draft = WorkerCaseDraft(
        title: _title.text.trim(),
        description: _description.text.trim(),
        serviceCity: _city.text.trim(),
        completionYear: int.parse(_year.text.trim()),
        imageUrls: imageUrls,
      );
      final saved = widget.existing == null
          ? await widget.api.createCase(widget.accessToken, draft)
          : await widget.api.updateCase(
              widget.accessToken,
              widget.existing!.id,
              draft,
            );
      if (mounted) Navigator.pop(context, saved);
    } on AuthApiException catch (error) {
      if (mounted) _show('保存失败：${error.message}');
    } catch (_) {
      if (mounted) _show('保存失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    setState(() => _deleting = true);
    try {
      await widget.api.deleteCase(widget.accessToken, existing.id);
      if (mounted) Navigator.pop(context, existing.id);
    } catch (_) {
      if (mounted) _show('删除失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: Text(widget.existing == null ? '添加施工案例' : '编辑施工案例'),
        actions: [
          if (widget.existing != null)
            TextButton(
              onPressed: _deleting ? null : _delete,
              child: Text(_deleting ? '删除中...' : '删除'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field('案例标题', _title, const Key('case-title')),
          const SizedBox(height: 14),
          _field(
            '案例说明',
            _description,
            const Key('case-description'),
            maxLines: 4,
          ),
          const SizedBox(height: 14),
          _field('施工城市', _city, const Key('case-city')),
          const SizedBox(height: 14),
          _field(
            '完工年份',
            _year,
            const Key('case-year'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '案例图片（1–6 张）',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('case-pick-images'),
                onPressed: _saving ? null : _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('选择图片'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_existingImages.isEmpty && _pickedImages.isEmpty)
            const Text('尚未选择图片', style: TextStyle(color: ZdColors.textHint))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final url in _existingImages)
                  _ImageChip(
                    label: '已上传图片',
                    onRemove: () => setState(() => _existingImages.remove(url)),
                  ),
                for (final image in _pickedImages)
                  _ImageChip(
                    label: image.filename,
                    onRemove: () => setState(() => _pickedImages.remove(image)),
                  ),
              ],
            ),
          const SizedBox(height: 28),
          FilledButton(
            key: const Key('case-save'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '上传保存中...' : '上传并保存案例'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    Key key, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      key: key,
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _ImageChip extends StatelessWidget {
  const _ImageChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: const Icon(Icons.image_outlined, size: 18),
      label: SizedBox(
        width: 120,
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      onDeleted: onRemove,
    );
  }
}
