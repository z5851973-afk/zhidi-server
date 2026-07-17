// ============================================================
// 工匠端 — 独立登录页（手机验证码登录）
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import '../../app/worker_app_scope.dart';
import '../../services/auth_api_client.dart';
import '../../services/daily_report_api_client.dart';
import '../../services/worker_booking_api_client.dart';

class WorkerLoginPage extends StatefulWidget {
  const WorkerLoginPage({super.key, this.api});

  final OwnerAuthApi? api;

  @override
  State<WorkerLoginPage> createState() => _WorkerLoginPageState();
}

class _WorkerLoginPageState extends State<WorkerLoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
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
        ).showSnackBar(
          SnackBar(
            content: Text('开发验证码已自动填入：$code，有效期${response.expiresInSeconds ~/ 60}分钟'),
          ),
        );
      }
      setState(() => _countdown = response.retryAfterSeconds);
      _startCountdown();
    } catch (error) {
      if (mounted) {
        _showAuthError(error, sendingCode: true);
      }
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
      ).showSnackBar(const SnackBar(content: Text('请先阅读并同意用户协议')));
      return;
    }
    if (_phoneController.text.trim().length != 11 ||
        _codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入手机号和验证码')));
      return;
    }
    final scope = WorkerAppScope.of(context);
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    try {
      final phone = _phoneController.text.trim();
      final code = _codeController.text.trim();
      final loginResp = await _api.loginWorker(phone, code);
      RemoteWorkerProfile? remoteProfile;
      try {
        remoteProfile = await _api.getWorkerProfile(loginResp.accessToken);
      } catch (_) {
        // 资料读取失败不阻断登录；后续个人资料页仍可手动保存/刷新。
      }
      await scope.loginOnline(loginResp, remoteProfile: remoteProfile);
      scope.initBookingApi(
        api: WorkerBookingApiClient(),
        accessToken: loginResp.accessToken,
      );
      scope.initReportApi(
        api: DailyReportApiClient(),
        accessToken: loginResp.accessToken,
      );

      if (!mounted) return;
      // WorkerApp 会根据真实登录状态切换首页。
    } catch (error) {
      if (!mounted) return;
      _showAuthError(error);
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _showAuthError(Object error, {bool sendingCode = false}) {
    final message = switch (error) {
      AuthApiException(code: 'SMS_RATE_LIMITED') => '验证码发送太频繁，请稍后再试',
      AuthApiException(code: 'SMS_CODE_INVALID') => '验证码不正确，请重新输入',
      AuthApiException(code: 'SMS_CODE_EXPIRED') => '验证码已过期，请重新获取',
      AuthApiException(code: 'SMS_CODE_ATTEMPTS_EXCEEDED') => '错误次数过多，请重新获取验证码',
      AuthApiException(code: 'ACCOUNT_DISABLED') => '账户已停用，请联系客服',
      AuthApiException(code: 'WORKER_ACCESS_DENIED') => '该手机号不是工匠账户',
      AuthApiException(code: 'NETWORK_TIMEOUT') => '请求超时，请稍后重试',
      AuthApiException(code: 'NETWORK_UNAVAILABLE') => '无法连接服务器，请检查网络',
      AuthApiException() => sendingCode ? '验证码发送失败，请稍后重试' : '登录失败，请稍后重试',
      _ => sendingCode ? '验证码发送失败，请稍后重试' : '登录失败，请重试',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: ZdSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              // Logo
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: ZdColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(ZdRadius.card),
                ),
                child: const Center(
                  child: Text(
                    '知',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: ZdSpacing.xl),
              const Text(
                '工匠登录',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: ZdColors.textPrimary,
                ),
              ),
              const SizedBox(height: ZdSpacing.sm),
              const Text(
                '登录后开始接单服务',
                style: TextStyle(fontSize: 14, color: ZdColors.textSecondary),
              ),
              const SizedBox(height: 40),

              // 手机号输入
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                decoration: InputDecoration(
                  labelText: '手机号',
                  hintText: '请输入手机号',
                  prefixIcon: const Icon(Icons.phone_android_outlined),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ZdRadius.sm),
                  ),
                ),
              ),
              const SizedBox(height: ZdSpacing.md),

              // 验证码输入
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: '验证码',
                        hintText: '请输入验证码',
                        prefixIcon: const Icon(Icons.lock_outline),
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(ZdRadius.sm),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: ZdSpacing.md),
                  SizedBox(
                    width: 120,
                    height: 48,
                    child: OutlinedButton(
                      onPressed:
                          (_sendingCode || _countdown > 0) ? null : _sendCode,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ZdColors.primary,
                        side: const BorderSide(color: ZdColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ZdRadius.sm),
                        ),
                      ),
                      child: _sendingCode
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ZdColors.primary,
                              ),
                            )
                          : Text(
                              _countdown > 0 ? '${_countdown}s' : '获取验证码',
                              style: const TextStyle(fontSize: 13),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZdSpacing.lg),

              // 协议
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _agreeTerms,
                      activeColor: ZdColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) =>
                          setState(() => _agreeTerms = v ?? false),
                    ),
                  ),
                  const SizedBox(width: ZdSpacing.sm),
                  const Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: '已阅读并同意',
                        style: TextStyle(
                          fontSize: 12,
                          color: ZdColors.textSecondary,
                        ),
                        children: [
                          TextSpan(
                            text: '《用户协议》',
                            style: TextStyle(color: ZdColors.primary),
                          ),
                          TextSpan(text: '和'),
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
              const SizedBox(height: ZdSpacing.xl),

              // 登录按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZdColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: ZdColors.primary.withValues(
                      alpha: 0.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ZdRadius.sm),
                    ),
                    elevation: 0,
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
                          '登录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
