import 'dart:async';

import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import '../../app/owner_app_scope.dart';
import '../../services/auth_api_client.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.onLoginDone, this.api});
  final VoidCallback? onLoginDone;
  final OwnerAuthApi? api;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _agreeTerms = true;
  bool _loading = false;
  bool _sendingCode = false;
  int _countdown = 0;
  Timer? _countdownTimer;
  late final OwnerAuthApi _api;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AuthApiClient();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_sendingCode || _countdown > 0) return;
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入正确的手机号')));
      return;
    }
    setState(() => _sendingCode = true);
    try {
      final response = await _api.requestSmsCode(phone);
      if (!mounted) return;
      if (response.simulatedCode case final code?) {
        _codeController.text = code;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('开发验证码已自动填入')));
      }
      setState(() {
        _codeSent = true;
        _countdown = response.retryAfterSeconds;
      });
      _startCountdown();
    } catch (error) {
      if (mounted) _showAuthError(error, sendingCode: true);
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    if (_countdown <= 0) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _login() async {
    if (!_agreeTerms) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先同意用户协议和隐私政策')));
      return;
    }
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入正确的手机号')));
      return;
    }
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入验证码')));
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await _api.loginOwner(phone, code);
      if (!mounted) return;
      final appState = OwnerAppScope.of(context);
      await appState.completeAuthenticatedLogin(response);
      if (!mounted) return;
      if (widget.onLoginDone != null) {
        widget.onLoginDone!();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) _showAuthError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAuthError(Object error, {bool sendingCode = false}) {
    final message = switch (error) {
      AuthApiException(code: 'SMS_RATE_LIMITED') => '验证码发送太频繁，请稍后再试',
      AuthApiException(code: 'SMS_CODE_INVALID') => '验证码不正确，请重新输入',
      AuthApiException(code: 'SMS_CODE_EXPIRED') => '验证码已过期，请重新获取',
      AuthApiException(code: 'SMS_CODE_ATTEMPTS_EXCEEDED') => '错误次数过多，请重新获取验证码',
      AuthApiException(code: 'ACCOUNT_DISABLED') => '账户已停用，请联系客服',
      AuthApiException(code: 'OWNER_ACCESS_DENIED') => '该手机号不是业主账户',
      AuthApiException(code: 'NETWORK_TIMEOUT') => '请求超时，请稍后重试',
      AuthApiException(code: 'NETWORK_UNAVAILABLE') => '无法连接服务器，请检查网络',
      AuthApiException() => sendingCode ? '验证码发送失败，请稍后重试' : '登录失败，请稍后重试',
      _ => '登录信息保存失败，请重试',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showWechatLoginUnavailable() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('微信登录暂未开放，请使用手机号登录')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: ZdColors.textPrimary),
          onPressed: () {
            if (widget.onLoginDone != null) return; // gate 模式下不允许关闭
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
              const SizedBox(height: 36),
              // ── 标题 ──
              const Text(
                '登录',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: ZdColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '登录后查看我的家、管理装修进度',
                style: TextStyle(
                  fontSize: 14,
                  color: ZdColors.textSecondary,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 40),

              // ── 手机号输入 ──
              _InputLabel('手机号'),
              const SizedBox(height: 8),
              TextField(
                key: const Key('login-phone'),
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                decoration: InputDecoration(
                  hintText: '请输入手机号',
                  counterText: '',
                  prefixIcon: const Icon(
                    Icons.phone_android_outlined,
                    size: 20,
                  ),
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

              // ── 验证码输入 ──
              _InputLabel('验证码'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('login-code'),
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        hintText: '请输入验证码',
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
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      key: const Key('login-send-code'),
                      onPressed: _sendingCode || _countdown > 0
                          ? null
                          : _sendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZdColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: ZdColors.divider,
                        disabledForegroundColor: ZdColors.textSecondary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: _sendingCode
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _countdown > 0
                                  ? '${_countdown}s'
                                  : (_codeSent ? '重新获取' : '获取验证码'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── 登录按钮 ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  key: const Key('login-submit'),
                  onPressed: _loading ? null : _login,
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
                          '登录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // ── 用户协议 ──
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _agreeTerms,
                      onChanged: (v) =>
                          setState(() => _agreeTerms = v ?? false),
                      activeColor: ZdColors.primary,
                      side: const BorderSide(
                        color: ZdColors.textSecondary,
                        width: 1.5,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 12,
                          color: ZdColors.textSecondary,
                        ),
                        children: [
                          const TextSpan(text: '登录即代表您同意'),
                          TextSpan(
                            text: '《用户协议》',
                            style: TextStyle(color: ZdColors.primary),
                          ),
                          const TextSpan(text: '和'),
                          TextSpan(
                            text: '《隐私政策》',
                            style: TextStyle(color: ZdColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // ── 其他登录方式 ──
              Center(
                child: Text(
                  '其他登录方式',
                  style: TextStyle(
                    fontSize: 13,
                    color: ZdColors.textSecondary.withValues(alpha: .6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SocialButton(
                    icon: Icons.wechat_outlined,
                    label: '微信',
                    onTap: _showWechatLoginUnavailable,
                  ),
                ],
              ),
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

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ZdColors.divider),
            ),
            child: Icon(icon, size: 24, color: ZdColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: ZdColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
