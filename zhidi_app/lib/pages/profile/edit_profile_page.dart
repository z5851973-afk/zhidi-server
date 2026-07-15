import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../design/tokens.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final profile = OwnerAppScope.of(context).profile;
    _nameController = TextEditingController(text: profile.name);
    _cityController = TextEditingController(text: profile.city);
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) =>
      value == null || value.trim().isEmpty ? message : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final state = OwnerAppScope.of(context);
    var saved = false;
    try {
      await state.updateProfile(
        state.profile.copyWith(
          name: _nameController.text.trim(),
          city: _cityController.text.trim(),
        ),
      );
      saved = true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (saved && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑资料')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              key: const Key('profile-name-field'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: '姓名'),
              validator: (value) => _required(value, '请输入姓名'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('profile-city-field'),
              controller: _cityController,
              decoration: const InputDecoration(labelText: '城市'),
              validator: (value) => _required(value, '请输入城市'),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: ZdColors.primary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(_saving ? '保存中…' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}
