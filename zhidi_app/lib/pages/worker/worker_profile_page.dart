// ============================================================
// 工匠端 — 个人资料页
// 头像更换 + 基本资料编辑 + 认证信息展示 + 接单开关
// ============================================================

import 'package:flutter/material.dart';

import '../../app/worker_app_scope.dart';
import '../../models/renovation.dart';
import '../../design/tokens.dart';
import '../../design/components.dart';
import '../../services/auth_api_client.dart';
import '../../services/worker_case_api_client.dart';
import 'worker_case_edit_page.dart';

const _primary = ZdColors.primary;
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _divider = ZdColors.divider;
const _success = ZdColors.success;
const _error = ZdColors.error;

class WorkerProfilePage extends StatefulWidget {
  const WorkerProfilePage({
    super.key,
    this.onboarding = false,
    this.api,
    this.caseApi,
    this.caseImagePicker,
  });

  final bool onboarding;
  final OwnerAuthApi? api;
  final WorkerCaseApi? caseApi;
  final WorkerCaseImagePicker? caseImagePicker;

  @override
  State<WorkerProfilePage> createState() => _WorkerProfilePageState();
}

class _WorkerProfilePageState extends State<WorkerProfilePage> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _yearsCtrl;
  late TextEditingController _dailyRateCtrl;
  late TextEditingController _bioCtrl;
  late Trade _trade;
  bool _tradeSelected = false;
  bool _acceptOrders = true;
  bool _saving = false;
  bool _initialized = false;
  bool _casesLoading = false;
  String? _casesError;
  List<RemoteWorkerCase> _cases = const [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _yearsCtrl = TextEditingController();
    _dailyRateCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
    _trade = Trade.values.first;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final scope = WorkerAppScope.of(context);
    final p = scope.profile;
    _nameCtrl.text = p.name;
    _phoneCtrl.text = p.phone;
    _cityCtrl.text = p.serviceCity;
    _yearsCtrl.text = p.experienceYears.toString();
    _dailyRateCtrl.text = p.dailyRate > 0 ? p.dailyRate.toStringAsFixed(0) : '';
    _bioCtrl.text = p.bio;
    _trade = p.trade;
    _tradeSelected = p.tradeSelected;
    _acceptOrders = scope.settings.acceptOrders;
    if (!widget.onboarding) Future<void>.microtask(_loadCases);
  }

  WorkerCaseApi get _caseApi => widget.caseApi ?? WorkerCaseApiClient();

  Future<void> _loadCases() async {
    final token = WorkerAppScope.of(context).accessToken;
    if (token == null) return;
    setState(() {
      _casesLoading = true;
      _casesError = null;
    });
    try {
      final values = await _caseApi.listMyCases(token);
      if (!mounted) return;
      setState(() => _cases = values);
    } catch (_) {
      if (!mounted) return;
      setState(() => _casesError = '案例加载失败');
    } finally {
      if (mounted) setState(() => _casesLoading = false);
    }
  }

  Future<void> _openCaseEditor([RemoteWorkerCase? existing]) async {
    final state = WorkerAppScope.of(context);
    final token = state.accessToken;
    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录已过期，请重新登录')));
      return;
    }
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerCaseEditPage(
          api: _caseApi,
          accessToken: token,
          initialCity: state.profile.serviceCity,
          existing: existing,
          imagePicker: widget.caseImagePicker,
        ),
      ),
    );
    if (result != null && mounted) await _loadCases();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _yearsCtrl.dispose();
    _dailyRateCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final validationMessage = _validationMessage();
    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }
    setState(() => _saving = true);
    try {
      final state = WorkerAppScope.of(context);
      await state.updateProfile(
        state.profile.copyWith(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          trade: _trade,
          tradeSelected: true,
          serviceCity: _cityCtrl.text.trim(),
          experienceYears: int.tryParse(_yearsCtrl.text) ?? 0,
          dailyRate: double.tryParse(_dailyRateCtrl.text) ?? 0,
          bio: _bioCtrl.text.trim(),
        ),
        api: widget.api,
      );
      await state.updateSettings(
        state.settings.copyWith(acceptOrders: _acceptOrders),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存成功')));
        if (!widget.onboarding) Navigator.maybePop(context);
      }
    } on AuthApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请检查网络后重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validationMessage() {
    if (_nameCtrl.text.trim().isEmpty) return '请填写真实姓名';
    if (_cityCtrl.text.trim().isEmpty) return '请填写服务城市';
    if (!_tradeSelected) return '请选择您的工种';
    final years = int.tryParse(_yearsCtrl.text.trim());
    if (years == null || years < 0 || years > 60) return '工龄请输入 0 到 60 的整数';
    final dailyRate = double.tryParse(_dailyRateCtrl.text.trim());
    if (dailyRate == null || dailyRate < 1 || dailyRate > 99999.99) {
      return '日薪请输入 1 到 99999.99';
    }
    if (_bioCtrl.text.trim().isEmpty) return '请填写自我介绍';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = WorkerAppScope.of(context).profile;

    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.onboarding,
        title: Text(widget.onboarding ? '完善工人资料' : '个人资料'),
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? '保存中...' : '保存',
              style: TextStyle(color: _primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── 头像区域 ──
            ZdCard(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      // 实际应使用 image_picker，此处为示意
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('点击更换头像')));
                    },
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: _primary.withValues(alpha: 0.1),
                          child: Text(
                            p.name.isNotEmpty ? p.name[0] : '工',
                            style: const TextStyle(
                              fontSize: 32,
                              color: _primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ZdSpacing.sm),
                  Text('点击更换头像', style: ZdText.tiny),
                ],
              ),
            ),

            // ── 基本信息编辑 ──
            ZdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('基本信息', style: ZdText.subtitle),
                  const SizedBox(height: ZdSpacing.lg),
                  _field(
                    '真实姓名',
                    _nameCtrl,
                    fieldKey: const Key('worker-profile-name'),
                  ),
                  const SizedBox(height: ZdSpacing.md),
                  _field(
                    '手机号',
                    _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    readOnly: true,
                  ),

                  const SizedBox(height: ZdSpacing.md),
                  _field(
                    '服务城市',
                    _cityCtrl,
                    fieldKey: const Key('worker-profile-city'),
                  ),

                  const SizedBox(height: ZdSpacing.md),
                  Text(
                    '工种',
                    style: ZdText.caption.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZdSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: _divider),
                      borderRadius: BorderRadius.circular(ZdRadius.sm),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Trade>(
                        key: const Key('worker-profile-trade'),
                        value: _trade,
                        isExpanded: true,
                        items: Trade.values.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(t.label),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _trade = v;
                              _tradeSelected = true;
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: ZdSpacing.md),
                  _field(
                    '工龄（年）',
                    _yearsCtrl,
                    keyboardType: TextInputType.number,
                    fieldKey: const Key('worker-profile-years'),
                  ),

                  const SizedBox(height: ZdSpacing.md),
                  _field(
                    '日薪（元）',
                    _dailyRateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    fieldKey: const Key('worker-profile-daily-rate'),
                  ),

                  const SizedBox(height: ZdSpacing.md),
                  Text(
                    '个人简介',
                    style: ZdText.caption.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    key: const Key('worker-profile-bio'),
                    controller: _bioCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '介绍您的专业技能、服务优势...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ZdRadius.sm),
                      ),
                      contentPadding: const EdgeInsets.all(ZdSpacing.md),
                    ),
                  ),
                ],
              ),
            ),

            // ── 认证信息 ──
            if (!widget.onboarding) _buildCasesCard(),

            // ── 认证信息 ──
            ZdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('认证信息', style: ZdText.subtitle),
                  const SizedBox(height: ZdSpacing.lg),
                  _certRow('身份认证', p.isVerified, '已完成'),
                  if (p.certifications.isNotEmpty)
                    ...p.certifications.map((c) => _certRow(c, true, '已认证')),
                ],
              ),
            ),

            // ── 接单设置 ──
            ZdCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('接单开关', style: ZdText.body),
                      const SizedBox(height: 2),
                      Text(
                        _acceptOrders ? '当前可接新订单' : '暂停接单中',
                        style: ZdText.tiny.copyWith(
                          color: _acceptOrders ? _success : _error,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _acceptOrders,
                    activeThumbColor: _primary,
                    onChanged: (v) => setState(() => _acceptOrders = v),
                  ),
                ],
              ),
            ),

            // ── 保存按钮 ──
            Padding(
              padding: const EdgeInsets.all(ZdSpacing.lg),
              child: ZdPrimaryButton(
                key: const Key('worker-profile-save'),
                label: _saving ? '保存中...' : '保存修改',
                onTap: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCasesCard() {
    return ZdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('施工案例管理', style: ZdText.subtitle),
              const Spacer(),
              TextButton.icon(
                onPressed: _casesLoading ? null : () => _openCaseEditor(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加案例'),
              ),
            ],
          ),
          if (_casesLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_casesError != null)
            TextButton.icon(
              onPressed: _loadCases,
              icon: const Icon(Icons.refresh),
              label: Text(_casesError!),
            )
          else if (_cases.isEmpty)
            Text('尚未添加案例，业主端将显示“暂无施工案例”', style: ZdText.caption)
          else
            ..._cases.map(
              (value) => Material(
                type: MaterialType.transparency,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(value.title),
                  subtitle: Text(
                    '${value.serviceCity} · ${value.completionYear}年 · ${value.imageUrls.length}张',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openCaseEditor(value),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboardType = TextInputType.text,
    Key? fieldKey,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ZdText.caption.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        TextField(
          key: fieldKey,
          controller: ctrl,
          keyboardType: keyboardType,
          readOnly: readOnly,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ZdRadius.sm),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: ZdSpacing.md,
              vertical: ZdSpacing.md,
            ),
          ),
        ),
      ],
    );
  }

  Widget _certRow(String label, bool passed, String status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZdSpacing.sm),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.pending,
            size: 18,
            color: passed ? _success : _textMid,
          ),
          const SizedBox(width: ZdSpacing.sm),
          Text(label, style: ZdText.body),
          const Spacer(),
          Text(
            status,
            style: ZdText.tiny.copyWith(
              color: passed ? _success : _textMid,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
