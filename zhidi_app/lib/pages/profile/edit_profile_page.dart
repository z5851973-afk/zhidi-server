import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/owner_app_scope.dart';
import '../../design/tokens.dart';
import '../../services/auth_api_client.dart';
import '../../services/upload_api_client.dart';

typedef OwnerAvatarUploader = Future<String?> Function(String accessToken);

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, this.avatarUploader});

  final OwnerAvatarUploader? avatarUploader;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _phoneController;
  String? _avatarUrl;
  String? _gender;
  bool _initialized = false;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final profile = OwnerAppScope.of(context).profile;
    _nameController = TextEditingController(text: profile.name);
    _cityController = TextEditingController(text: profile.city);
    _phoneController = TextEditingController(text: profile.phone);
    _avatarUrl = profile.avatarUrl;
    _gender = profile.gender;
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) =>
      value == null || value.trim().isEmpty ? message : null;

  Future<String?> _defaultAvatarUpload(String accessToken) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 86,
    );
    if (image == null) return null;
    final result = await UploadApiClient().uploadImage(
      File(image.path),
      accessToken: accessToken,
      category: 'owner-avatar',
    );
    if (!result.objectKey.startsWith('owner-avatar/')) {
      throw const UploadApiException(
        code: 'INVALID_RESPONSE',
        message: '头像地址异常',
      );
    }
    return '/uploads/${result.objectKey}';
  }

  Future<void> _changeAvatar() async {
    if (_uploadingAvatar || _saving) return;
    final state = OwnerAppScope.of(context);
    final token = await state.getAccessToken();
    if (!mounted) return;
    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录已过期，请重新登录')));
      return;
    }
    setState(() => _uploadingAvatar = true);
    try {
      final uploaded = await (widget.avatarUploader ?? _defaultAvatarUpload)(
        token,
      );
      if (uploaded != null && uploaded.isNotEmpty && mounted) {
        setState(() => _avatarUrl = uploaded);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('头像上传失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving || _uploadingAvatar) {
      return;
    }
    setState(() => _saving = true);
    final state = OwnerAppScope.of(context);
    var saved = false;
    try {
      await state.updateProfile(
        state.profile.copyWith(
          name: _nameController.text.trim(),
          city: _cityController.text.trim(),
          avatarUrl: _avatarUrl,
          gender: _gender,
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
      backgroundColor: ZdColors.background,
      appBar: AppBar(title: const Text('个人资料')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Column(
                children: [
                  _AvatarPreview(avatarUrl: _avatarUrl),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const Key('profile-avatar-button'),
                    onPressed: _uploadingAvatar ? null : _changeAvatar,
                    icon: _uploadingAvatar
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text(_uploadingAvatar ? '上传中…' : '更换头像'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ProfileCard(
              children: [
                TextFormField(
                  key: const Key('profile-name-field'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '姓名或称呼',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => _required(value, '请输入姓名或称呼'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('profile-phone-field'),
                  controller: _phoneController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    prefixIcon: Icon(Icons.phone_iphone_rounded),
                    suffixIcon: Tooltip(
                      message: '手机号已验证，不可在此修改',
                      child: Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF00B85A),
                      ),
                    ),
                    filled: true,
                    fillColor: Color(0xFFF4F1EF),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('profile-gender-field'),
                  initialValue: _gender,
                  decoration: const InputDecoration(
                    labelText: '性别（选填）',
                    prefixIcon: Icon(Icons.wc_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'MALE', child: Text('男')),
                    DropdownMenuItem(value: 'FEMALE', child: Text('女')),
                    DropdownMenuItem(value: 'UNDISCLOSED', child: Text('不透露')),
                  ],
                  onChanged: (value) => setState(() => _gender = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('profile-city-field'),
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: '所在城市',
                    prefixIcon: Icon(Icons.location_city_rounded),
                  ),
                  validator: (value) => _required(value, '请输入所在城市'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '房屋地址、面积和装修类型属于具体需求，请在找师傅时填写。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: ZdColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving || _uploadingAvatar ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: ZdColors.primary,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(_saving ? '保存中…' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final raw = avatarUrl?.trim();
    final resolved = raw == null || raw.isEmpty
        ? null
        : (Uri.parse(raw).hasScheme
              ? raw
              : Uri.parse(
                  AuthApiClient.configuredBaseUrl,
                ).resolve(raw).toString());
    return Container(
      width: 88,
      height: 88,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Color(0xFFFFE9DC),
        shape: BoxShape.circle,
      ),
      child: resolved == null
          ? const Icon(Icons.person_rounded, color: ZdColors.primary, size: 50)
          : Image.network(
              resolved,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.person_rounded,
                color: ZdColors.primary,
                size: 50,
              ),
            ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E5DE)),
      ),
      child: Column(children: children),
    );
  }
}
