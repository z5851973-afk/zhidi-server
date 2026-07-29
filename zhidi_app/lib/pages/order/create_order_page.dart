import 'package:flutter/material.dart';
import '../../app/owner_app_scope.dart';
import '../../app/owner_appointment.dart';
import '../renovation/booking_success_page.dart';
import '../../design/tokens.dart';

class CreateOrderPage extends StatefulWidget {
  final String workerName;

  const CreateOrderPage({super.key, required this.workerName});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _areaController = TextEditingController();
  final _descController = TextEditingController();

  String _selectedTime = '今天下午';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = OwnerAppScope.of(context);
      final profile = state.profile;
      final defaultAddress = state.addresses.isEmpty
          ? null
          : state.addresses.firstWhere(
              (item) => item.isDefault,
              orElse: () => state.addresses.first,
            );
      setState(() {
        if (_nameController.text.isEmpty && profile.name.isNotEmpty) {
          _nameController.text = profile.name;
        }
        if (_phoneController.text.isEmpty && profile.phone.isNotEmpty) {
          _phoneController.text = profile.phone;
        }
        if (_addressController.text.isEmpty) {
          final profileAddress = profile.address?.trim();
          if (profileAddress != null && profileAddress.isNotEmpty) {
            _addressController.text = profileAddress;
          } else if (defaultAddress != null) {
            _addressController.text =
                '${defaultAddress.city}${defaultAddress.district}${defaultAddress.detail}';
          }
        }
        if (_descController.text.isEmpty) {
          _descController.text = _serviceType;
        }
      });
    });
  }

  String get _serviceType {
    final text = widget.workerName;
    if (text.contains('水电')) return '水电改造';
    if (text.contains('木')) return '木工施工';
    if (text.contains('泥') || text.contains('瓦')) return '泥瓦施工';
    if (text.contains('防水')) return '防水施工';
    if (text.contains('油漆')) return '油漆施工';
    if (text.contains('拆')) return '拆除施工';
    return '上门勘测';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _areaController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final order = OrderItem(
      id: 'order-${now.millisecondsSinceEpoch}-${widget.workerName.hashCode.toRadixString(36)}',
      workerName: widget.workerName,
      customerName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      area: _areaController.text.trim(),
      description: _descController.text.trim(),
      visitTime: _selectedTime,
      status: '待师傅确认',
      createdAt: now,
    );

    setState(() => _submitting = true);
    try {
      await OwnerAppScope.of(context).addAppointment(order);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingSuccessPage(
            workerName: order.workerName,
            workerJob: _serviceType,
            rating: 4.98,
            renovationStage: '预约上门',
            tradeType: _serviceType,
            serviceAddress: order.address,
            estimatedTime: order.visitTime,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('[CreateOrderPage] addAppointment failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('预约提交失败，请稍后重试')));
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(
        title: const Text(
          '预约师傅上门',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: ZdColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          _WorkerInfoCard(workerName: widget.workerName, serviceType: _serviceType),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _PickerRow(
                  label: '服务类型',
                  value: _serviceType,
                  icon: Icons.handyman_outlined,
                ),
                const SizedBox(height: 12),
                _PickerRow(
                  label: '预约时间',
                  value: _selectedTime,
                  icon: Icons.schedule_rounded,
                  onTap: _showTimePicker,
                ),
                const SizedBox(height: 12),
                _InputCard(
                  title: '上门地址',
                  hint: '请输入小区 / 街道 / 门牌号',
                  controller: _addressController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请填写上门地址';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _InputCard(
                  title: '备注（选填）',
                  hint: '请填写备注信息',
                  controller: _descController,
                  maxLines: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _GuaranteeStrip(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: _submitting
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '提交预约',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
          ),
        ),
      ),
    );
  }

  void _showTimePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final times = ['今天上午', '今天下午', '明天上午', '明天下午', '后天上午', '后天下午'];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '选择预约时间',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: ZdColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                ...times.map(
                  (time) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(time),
                    trailing: _selectedTime == time
                        ? const Icon(Icons.check_circle, color: ZdColors.primary)
                        : null,
                    onTap: () {
                      setState(() => _selectedTime = time);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkerInfoCard extends StatelessWidget {
  final String workerName;
  final String serviceType;

  const _WorkerInfoCard({required this.workerName, required this.serviceType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEE3),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFFFF7A2F),
              size: 38,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workerName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: ZdColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '8年经验 · 4.98分 · 平台认证',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF777777),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ZdColors.warningSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              serviceType,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ZdColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ZdColors.primary),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: ZdColors.textPrimary,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ZdColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: ZdColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _GuaranteeStrip extends StatelessWidget {
  const _GuaranteeStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: ZdColors.warningSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_outlined, size: 16, color: ZdColors.primary),
          SizedBox(width: 6),
          Text(
            '平台保障：预约准时 · 售后保护',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: ZdColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final String title;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final String? Function(String?)? validator;

  const _InputCard({
    required this.title,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: title,
          hintText: hint,
          border: InputBorder.none,
          labelStyle: const TextStyle(
            color: ZdColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
          hintStyle: const TextStyle(color: ZdColors.textHint, fontSize: 13),
        ),
      ),
    );
  }
}
