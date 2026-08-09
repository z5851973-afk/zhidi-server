import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../design/tokens.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _gender;
  bool _initialized = false;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final profile = OwnerAppScope.of(context).profile;
    _nameController.text = profile.name;
    _cityController.text = profile.city;
    _phoneController.text = profile.phone;
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

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _cityController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit || _loading) return;
    setState(() => _loading = true);
    try {
      await OwnerAppScope.of(context).completeOnboarding(
        name: _nameController.text.trim(),
        city: _cityController.text.trim(),
        gender: _gender,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请稍后重试')));
      setState(() => _loading = false);
      return;
    }

    if (!mounted) return;
    if (widget.onDone case final onDone?) {
      onDone();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: widget.onDone == null
              ? () => Navigator.of(context).pop(false)
              : null,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '先认识一下您',
                style: TextStyle(
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: ZdColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '姓名和所在城市用于联系与同城服务，房屋信息可在找师傅时再填写。',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: ZdColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFE9DC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 42,
                        color: ZdColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '头像可稍后在个人资料中设置',
                      style: TextStyle(
                        fontSize: 12,
                        color: ZdColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _InputLabel('姓名或称呼', requiredField: true),
              const SizedBox(height: 8),
              _ProfileTextField(
                fieldKey: const Key('onboarding-name-field'),
                controller: _nameController,
                hintText: '例如：王女士',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              const _InputLabel('所在城市', requiredField: true),
              const SizedBox(height: 8),
              _ProfileTextField(
                fieldKey: const Key('onboarding-city-field'),
                controller: _cityController,
                hintText: '例如：成都',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              const _InputLabel('手机号'),
              const SizedBox(height: 8),
              _ProfileTextField(
                fieldKey: const Key('onboarding-phone-field'),
                controller: _phoneController,
                hintText: '',
                readOnly: true,
                suffix: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: Color(0xFF00B85A),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '已验证',
                      style: TextStyle(color: Color(0xFF00A852), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _InputLabel('性别（选填）'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'MALE', label: Text('男')),
                  ButtonSegment(value: 'FEMALE', label: Text('女')),
                  ButtonSegment(value: 'UNDISCLOSED', label: Text('不透露')),
                ],
                selected: _gender == null ? const {} : {_gender!},
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() => _gender = selection.firstOrNull);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  side: WidgetStateProperty.all(
                    const BorderSide(color: ZdColors.divider),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _canSubmit && !_loading ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZdColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: ZdColors.divider,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '开始使用',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputLabel extends StatelessWidget {
  const _InputLabel(this.label, {this.requiredField = false});

  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ZdColors.textPrimary,
          ),
        ),
        if (requiredField)
          const Text(' *', style: TextStyle(color: ZdColors.primary)),
      ],
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    this.fieldKey,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.readOnly = false,
    this.suffix,
  });

  final TextEditingController controller;
  final Key? fieldKey;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      readOnly: readOnly,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        suffixIcon: suffix == null
            ? null
            : Padding(padding: const EdgeInsets.only(right: 14), child: suffix),
        suffixIconConstraints: const BoxConstraints(minHeight: 48),
        filled: true,
        fillColor: readOnly ? const Color(0xFFF4F1EF) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ZdColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ZdColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ZdColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
