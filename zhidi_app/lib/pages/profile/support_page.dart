import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});
  @override
  Widget build(BuildContext context) {
    final requests = OwnerAppScope.of(context).afterSalesRequests;
    return Scaffold(
      appBar: AppBar(title: const Text('保障与售后')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '平台保障说明',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '平台提供服务留痕、验收记录和售后协助。款项与赔付以实际订单协议及平台审核结果为准，本页面不会模拟支付或退款。',
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '我的售后申请',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (requests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('暂无售后申请')),
            ),
          for (final item in requests)
            Card(
              child: ListTile(
                title: Text(item.issueType),
                subtitle: Text(item.description),
                trailing: Text(item.status),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AfterSalesFormPage()),
        ),
        label: const Text('提交售后申请'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class AfterSalesFormPage extends StatefulWidget {
  const AfterSalesFormPage({super.key});
  @override
  State<AfterSalesFormPage> createState() => _AfterSalesFormPageState();
}

class _AfterSalesFormPageState extends State<AfterSalesFormPage> {
  final _key = GlobalKey<FormState>();
  final _description = TextEditingController();
  String? _type;
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('售后申请')),
    body: Form(
      key: _key,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            key: const Key('support-type'),
            initialValue: _type,
            decoration: const InputDecoration(labelText: '问题类型'),
            items: const [
              '施工质量',
              '材料问题',
              '服务争议',
              '其他',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (value) => setState(() => _type = value),
            validator: (value) => value == null ? '请选择问题类型' : null,
          ),
          TextFormField(
            key: const Key('support-description'),
            controller: _description,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(labelText: '问题描述'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入问题描述' : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? '提交中…' : '提交申请'),
          ),
        ],
      ),
    ),
  );
  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await OwnerAppScope.of(context).submitAfterSales(
        AfterSalesRequest(
          id: 'after-sales-${DateTime.now().microsecondsSinceEpoch}',
          issueType: _type!,
          description: _description.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('售后申请已提交')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('提交失败，请重试')));
      }
    }
  }
}
