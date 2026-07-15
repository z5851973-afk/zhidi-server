import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import '../../app/owner_app_scope.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.onDone});
  final VoidCallback? onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _areaController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _decorationType;
  bool _loading = false;

  final _decorationOptions = const ['新房装修', '旧房改造', '局部改造'];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = OwnerAppScope.of(context).profile;
    if (_nameController.text.isEmpty) {
      _nameController.text = profile.name;
    }
    if (_phoneController.text.isEmpty) {
      _phoneController.text = profile.phone;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _areaController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _addressController.text.trim().isNotEmpty &&
      _decorationType != null &&
      _areaController.text.trim().isNotEmpty &&
      _phoneController.text.trim().length == 11;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _loading = true);

    final area = double.tryParse(_areaController.text.trim());
    if (area == null || area <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请输入有效面积')));
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final appState = OwnerAppScope.of(context);
      await appState.completeOnboarding(
        name: _nameController.text.trim(),
        decorationType: _decorationType!,
        address: _addressController.text.trim(),
        area: area,
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
    if (widget.onDone != null) {
      widget.onDone!();
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
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: ZdColors.textPrimary,
            size: 20,
          ),
          onPressed: () {
            if (widget.onDone != null) return;
            Navigator.of(context).pop(false);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                '完善您的资料',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: ZdColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '帮助我们为您匹配最合适的装修方案',
                style: TextStyle(
                  fontSize: 14,
                  color: ZdColors.textSecondary,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 36),

              _InputLabel('姓名'),
              const SizedBox(height: 8),
              TextField(
                key: const Key('onboarding-name-field'),
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '请输入您的姓名',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ZdColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ZdColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: ZdColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── 小区名称 & 详细地址 ──
              _InputLabel('房屋地址'),
              const SizedBox(height: 8),
              TextField(
                key: const Key('onboarding-address-field'),
                controller: _addressController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '请输入小区名称、栋、单元、门牌号',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ZdColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ZdColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: ZdColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── 装修类型 ──
              _InputLabel('装修类型'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ZdColors.divider),
                ),
                child: Row(
                  children: _decorationOptions.map((option) {
                    final selected = _decorationType == option;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _decorationType = option),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? ZdColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : ZdColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // ── 预估面积 ──
              _InputLabel('预估面积'),
              const SizedBox(height: 8),
              TextField(
                key: const Key('onboarding-area-field'),
                controller: _areaController,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '请输入房屋面积',
                  suffixText: 'm²',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ZdColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ZdColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: ZdColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── 手机号 ──
              _InputLabel('手机号'),
              const SizedBox(height: 8),
              TextField(
                key: const Key('onboarding-phone-field'),
                controller: _phoneController,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.phone,
                maxLength: 11,
                decoration: InputDecoration(
                  hintText: '请输入手机号',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ZdColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ZdColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: ZdColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // ── 提交按钮 ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_canSubmit && !_loading) ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZdColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor: ZdColors.divider,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          '开始使用',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputLabel extends StatelessWidget {
  const _InputLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ZdColors.textPrimary,
      ),
    );
  }
}
