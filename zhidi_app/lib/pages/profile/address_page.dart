import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';

class AddressPage extends StatelessWidget {
  const AddressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('地址管理')),
      body: state.addresses.isEmpty
          ? const Center(child: Text('暂无地址，添加一个常用地址吧'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final address in state.addresses)
                  Card(
                    child: ListTile(
                      title: Text('${address.recipient}  ${address.phone}'),
                      subtitle: Text(
                        '${address.city}${address.district}\n${address.detail}',
                      ),
                      isThreeLine: true,
                      leading: address.isDefault
                          ? const Chip(label: Text('默认'))
                          : const Icon(Icons.location_on_outlined),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: Key('edit-${address.id}'),
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openForm(context, address),
                          ),
                          IconButton(
                            key: Key('delete-${address.id}'),
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(context, address),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        icon: const Icon(Icons.add),
        label: const Text('新增地址'),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, OwnerAddress? address) =>
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AddressFormPage(address: address)),
      );

  Future<void> _delete(BuildContext context, OwnerAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除这个地址？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await OwnerAppScope.of(context).deleteAddress(address.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('地址已删除')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
      }
    }
  }
}

class AddressFormPage extends StatefulWidget {
  const AddressFormPage({super.key, this.address});
  final OwnerAddress? address;
  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _recipient = TextEditingController(
    text: widget.address?.recipient,
  );
  late final _phone = TextEditingController(text: widget.address?.phone);
  late final _city = TextEditingController(text: widget.address?.city);
  late final _district = TextEditingController(text: widget.address?.district);
  late final _detail = TextEditingController(text: widget.address?.detail);
  late bool _defaultAddress = widget.address?.isDefault ?? false;
  bool _saving = false;

  Widget _field(
    Key key,
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
  }) => TextFormField(
    key: key,
    controller: controller,
    decoration: InputDecoration(labelText: label),
    validator:
        validator ??
        (value) => value == null || value.trim().isEmpty ? '请输入$label' : null,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.address == null ? '新增地址' : '编辑地址')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _field(const Key('address-recipient'), '收件人', _recipient),
          _field(
            const Key('address-phone'),
            '手机号',
            _phone,
            validator: (value) =>
                RegExp(r'^1\d{10}$').hasMatch(value?.trim() ?? '')
                ? null
                : '请输入正确的中国大陆手机号',
          ),
          _field(const Key('address-city'), '城市', _city),
          _field(const Key('address-district'), '区县', _district),
          _field(const Key('address-detail'), '详细地址', _detail),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('设为默认地址'),
            value: _defaultAddress,
            onChanged: (value) =>
                setState(() => _defaultAddress = value ?? false),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存地址'),
          ),
        ],
      ),
    ),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final state = OwnerAppScope.of(context);
    final value = OwnerAddress(
      id:
          widget.address?.id ??
          'address-${DateTime.now().microsecondsSinceEpoch}',
      recipient: _recipient.text.trim(),
      phone: _phone.text.trim(),
      city: _city.text.trim(),
      district: _district.text.trim(),
      detail: _detail.text.trim(),
      isDefault: _defaultAddress,
    );
    try {
      await (widget.address == null
          ? state.addAddress(value)
          : state.updateAddress(value));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    }
  }
}
