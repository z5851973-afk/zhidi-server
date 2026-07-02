import 'package:flutter/material.dart';
import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _key = GlobalKey<FormState>();
  final _description = TextEditingController();
  String? _category;
  bool _saving = false;
  bool _success = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('帮助与反馈')),
    body: _success
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 12),
                const Text(
                  '反馈提交成功',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _success = false;
                    _category = null;
                    _description.clear();
                  }),
                  child: const Text('继续反馈'),
                ),
              ],
            ),
          )
        : Form(
            key: _key,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('告诉我们遇到的问题或建议，我们会认真查看。'),
                DropdownButtonFormField<String>(
                  key: const Key('feedback-category'),
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: '反馈分类'),
                  items: const ['产品建议', '使用问题', '内容纠错', '其他']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v),
                  validator: (v) => v == null ? '请选择反馈分类' : null,
                ),
                TextFormField(
                  key: const Key('feedback-description'),
                  controller: _description,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: '反馈内容'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '请输入反馈内容' : null,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(_saving ? '提交中…' : '提交反馈'),
                ),
              ],
            ),
          ),
  );
  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await OwnerAppScope.of(context).submitFeedback(
        FeedbackEntry(
          id: 'feedback-${DateTime.now().microsecondsSinceEpoch}',
          category: _category!,
          description: _description.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _success = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('提交失败，请重试')));
      }
    }
  }
}
