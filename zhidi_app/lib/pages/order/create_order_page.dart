import 'package:flutter/material.dart';
import '../../app/owner_app_scope.dart';
import '../../app/owner_appointment.dart';
import 'order_success_page.dart';

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

    final order = OrderItem(
      workerName: widget.workerName,
      customerName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      area: _areaController.text.trim(),
      description: _descController.text.trim(),
      visitTime: _selectedTime,
      status: '待师傅确认',
      createdAt: DateTime.now(),
    );

    setState(() => _submitting = true);
    try {
      await OwnerAppScope.of(context).addAppointment(order);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OrderSuccessPage(order: order)),
      );
    } catch (_) {
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
          '填写预约单',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF222222),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          _WorkerInfoCard(workerName: widget.workerName),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _InputCard(
                  title: '联系人',
                  hint: '请输入联系人姓名',
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请填写联系人';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _InputCard(
                  title: '手机号',
                  hint: '请输入手机号',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return '请填写手机号';
                    if (!RegExp(r'^1\d{10}$').hasMatch(text)) {
                      return '手机号格式不正确';
                    }
                    return null;
                  },
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
                  title: '房屋面积',
                  hint: '例如：89㎡',
                  controller: _areaController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _InputCard(
                  title: '装修需求',
                  hint: '例如：厨房水电改造、旧房翻新等',
                  controller: _descController,
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请填写装修需求';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _TimeCard(
            selectedTime: _selectedTime,
            onChanged: (value) {
              setState(() {
                _selectedTime = value;
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6A1A),
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
}

class _WorkerInfoCard extends StatelessWidget {
  final String workerName;

  const _WorkerInfoCard({required this.workerName});

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
              color: Color(0xFFFF6A1A),
              size: 38,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '预约 $workerName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '提交后师傅会尽快与你联系',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF777777),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _InputCard({
    required this.title,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
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
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: title,
          hintText: hint,
          border: InputBorder.none,
          labelStyle: const TextStyle(
            color: Color(0xFF222222),
            fontWeight: FontWeight.w900,
          ),
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  final String selectedTime;
  final ValueChanged<String> onChanged;

  const _TimeCard({required this.selectedTime, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final times = ['今天上午', '今天下午', '明天上午', '明天下午', '后天上午', '后天下午'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '上门时间',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: times.map((time) {
              final active = selectedTime == time;
              return ChoiceChip(
                label: Text(time),
                selected: active,
                onSelected: (_) => onChanged(time),
                selectedColor: const Color(0xFFFF6A1A),
                backgroundColor: const Color(0xFFFFF1E8),
                labelStyle: TextStyle(
                  color: active ? Colors.white : const Color(0xFFFF6A1A),
                  fontWeight: FontWeight.w900,
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
