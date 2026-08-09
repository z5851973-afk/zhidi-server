import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';
import '../../data/owner_service_regions.dart';
import '../../design/tokens.dart';

class AddressPage extends StatefulWidget {
  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing || !mounted) return;
    setState(() => _refreshing = true);
    try {
      await OwnerAppScope.of(context).refreshOwnerAddresses();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('地址加载失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text('地址管理'),
        actions: [
          IconButton(
            tooltip: '刷新地址',
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: _refreshing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: state.addresses.isEmpty
          ? _EmptyAddress(onAdd: () => _openForm(context, null))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: state.addresses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final address = state.addresses[index];
                  return _AddressCard(
                    address: address,
                    onEdit: () => _openForm(context, address),
                    onDelete: () => _delete(context, address),
                    onSetDefault: address.isDefault
                        ? null
                        : () => _setDefault(context, address),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        backgroundColor: ZdColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增地址'),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, OwnerAddress? address) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddressFormPage(address: address)),
    );
    if (saved == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(address == null ? '地址已新增' : '地址已更新')),
      );
    }
  }

  Future<void> _setDefault(BuildContext context, OwnerAddress address) async {
    try {
      await OwnerAppScope.of(context).setDefaultAddress(address.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('默认地址已更新')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('设置失败，请重试')));
      }
    }
  }

  Future<void> _delete(BuildContext context, OwnerAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除这个地址？'),
        content: Text(
          address.isDefault ? '这是当前默认地址，删除后系统会自动选择新的默认地址。' : '删除后无法恢复。',
        ),
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

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final OwnerAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSetDefault;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: address.isDefault
              ? const Color(0xFFFFC9A8)
              : const Color(0xFFF0E7E1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      address.recipient,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      maskPhone(address.phone),
                      style: const TextStyle(color: ZdColors.textSecondary),
                    ),
                    if (address.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEEE3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '默认地址',
                          style: TextStyle(
                            color: ZdColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: Key('edit-${address.id}'),
                tooltip: '编辑地址',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 21),
              ),
              IconButton(
                key: Key('delete-${address.id}'),
                tooltip: '删除地址',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 21),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${address.province}${address.city}${address.district}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: ZdColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            address.detail,
            style: const TextStyle(height: 1.45, color: ZdColors.textSecondary),
          ),
          if (onSetDefault != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              key: Key('default-${address.id}'),
              onPressed: onSetDefault,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('设为默认'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyAddress extends StatelessWidget {
  const _EmptyAddress({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 64,
              color: Color(0xFFB8AAA1),
            ),
            const SizedBox(height: 16),
            const Text(
              '还没有常用地址',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '添加后，找师傅和预约上门会自动带入默认地址。',
              textAlign: TextAlign.center,
              style: TextStyle(color: ZdColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加第一个地址'),
            ),
          ],
        ),
      ),
    );
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
  late String? _province = widget.address?.province;
  late String? _city = widget.address?.city;
  late String? _district = widget.address?.district;
  late final _detail = TextEditingController(text: widget.address?.detail);
  late bool _defaultAddress = widget.address?.isDefault ?? false;
  late bool _legacyRegionUnsupported =
      widget.address != null &&
      !OwnerServiceRegionCatalog.contains(
        widget.address!.province,
        widget.address!.city,
        widget.address!.district,
      );
  bool _saving = false;

  @override
  void dispose() {
    _recipient.dispose();
    _phone.dispose();
    _detail.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '请输入$label' : null;

  Widget _field(
    Key key,
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        key: key,
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: label),
        validator: validator ?? (value) => _required(value, label),
      ),
    );
  }

  Widget _regionField({
    required Key key,
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        validator: (_) =>
            value == null || value.trim().isEmpty ? '请选择$label' : null,
        builder: (field) => InkWell(
          key: key,
          onTap: _saving ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: field.errorText,
              helperText: _legacyRegionUnsupported ? '当前地区暂未开放' : null,
              helperStyle: const TextStyle(color: ZdColors.primary),
              suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
            child: Text(
              value?.trim().isNotEmpty == true ? value! : '请选择$label',
              style: TextStyle(
                color: value?.trim().isNotEmpty == true
                    ? ZdColors.textPrimary
                    : ZdColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(title: Text(widget.address == null ? '新增地址' : '编辑地址')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _field(const Key('address-recipient'), '联系人', _recipient),
                    _field(
                      const Key('address-phone'),
                      '联系电话',
                      _phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          RegExp(r'^1[3-9]\d{9}$').hasMatch(value?.trim() ?? '')
                          ? null
                          : '请输入正确的中国大陆手机号',
                    ),
                    _regionField(
                      key: const Key('address-province'),
                      label: '省份',
                      value: _province,
                      onTap: _selectProvince,
                    ),
                    _regionField(
                      key: const Key('address-city'),
                      label: '城市',
                      value: _city,
                      onTap: _selectCity,
                    ),
                    _regionField(
                      key: const Key('address-district'),
                      label: '区县',
                      value: _district,
                      onTap: _selectDistrict,
                    ),
                    _field(const Key('address-detail'), '详细地址', _detail),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('设为默认地址'),
                      subtitle: const Text('后续找师傅和预约上门优先使用'),
                      value: _defaultAddress,
                      onChanged: _saving
                          ? null
                          : (value) => setState(
                              () => _defaultAddress = value ?? false,
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: ZdColors.primary,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(_saving ? '保存中…' : '保存地址'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final province = _province?.trim() ?? '';
    final city = _city?.trim() ?? '';
    final district = _district?.trim() ?? '';
    if (!OwnerServiceRegionCatalog.contains(province, city, district)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择已开放且匹配的省市区')));
      return;
    }
    setState(() => _saving = true);
    final state = OwnerAppScope.of(context);
    final value = OwnerAddress(
      id:
          widget.address?.id ??
          'pending-${DateTime.now().microsecondsSinceEpoch}',
      recipient: _recipient.text.trim(),
      phone: _phone.text.trim(),
      province: province,
      city: city,
      district: district,
      detail: _detail.text.trim(),
      isDefault: _defaultAddress,
      createdAt: widget.address?.createdAt,
      updatedAt: widget.address?.updatedAt,
    );
    try {
      await (widget.address == null
          ? state.addAddress(value)
          : state.updateAddress(value));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    }
  }

  Future<void> _selectProvince() async {
    final selected = await _showRegionPicker(
      title: '选择省份',
      options: OwnerServiceRegionCatalog.provinces,
      selected: _province,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (_province != selected) {
        _province = selected;
        _city = null;
        _district = null;
      }
      _legacyRegionUnsupported = false;
    });
  }

  Future<void> _selectCity() async {
    final province = _province;
    if (province == null ||
        !OwnerServiceRegionCatalog.provinces.contains(province)) {
      _showRegionDependencyMessage('请先选择省份');
      return;
    }
    final selected = await _showRegionPicker(
      title: '选择城市',
      options: OwnerServiceRegionCatalog.citiesFor(province),
      selected: _city,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (_city != selected) {
        _city = selected;
        _district = null;
      }
    });
  }

  Future<void> _selectDistrict() async {
    final province = _province;
    final city = _city;
    if (province == null ||
        !OwnerServiceRegionCatalog.provinces.contains(province)) {
      _showRegionDependencyMessage('请先选择省份');
      return;
    }
    if (city == null ||
        !OwnerServiceRegionCatalog.citiesFor(province).contains(city)) {
      _showRegionDependencyMessage('请先选择城市');
      return;
    }
    final selected = await _showRegionPicker(
      title: '选择区县',
      options: OwnerServiceRegionCatalog.districtsFor(province, city),
      selected: _district,
    );
    if (selected == null || !mounted) return;
    setState(() => _district = selected);
  }

  void _showRegionDependencyMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _showRegionPicker({
    required String title,
    required List<String> options,
    required String? selected,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RegionPickerSheet(
        title: title,
        options: options,
        selected: selected,
      ),
    );
  }
}

class _RegionPickerSheet extends StatefulWidget {
  const _RegionPickerSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<String> options;
  final String? selected;

  @override
  State<_RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<_RegionPickerSheet> {
  final _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.options
        .where((item) => item.contains(_keyword.trim()))
        .toList(growable: false);
    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE4DDD8),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                key: const Key('region-search'),
                controller: _searchController,
                onChanged: (value) => setState(() => _keyword = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '搜索地区',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _keyword.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除搜索',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _keyword = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            Expanded(
              child: options.isEmpty
                  ? const Center(
                      child: Text(
                        '没有匹配的地区',
                        style: TextStyle(color: ZdColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: options.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final selected = option == widget.selected;
                        return ListTile(
                          title: Text(option),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: ZdColors.primary,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, option),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String maskPhone(String value) {
  final normalized = value.trim();
  if (normalized.length != 11) return normalized;
  return '${normalized.substring(0, 3)}****${normalized.substring(7)}';
}
