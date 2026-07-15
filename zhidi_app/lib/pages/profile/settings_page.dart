import 'package:flutter/material.dart';
import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _writing = false;
  Future<void> _update(OwnerSettings value) async {
    setState(() => _writing = true);
    try {
      await OwnerAppScope.of(context).updateSettings(value);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('设置已保存')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，设置未更改，请重试')));
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = OwnerAppScope.of(context).settings;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          SwitchListTile(
            key: const Key('push-switch'),
            title: const Text('接收通知'),
            subtitle: const Text('允许应用发送重要提醒'),
            value: settings.pushNotifications,
            onChanged: _writing
                ? null
                : (v) => _update(settings.copyWith(pushNotifications: v)),
          ),
          SwitchListTile(
            key: const Key('project-switch'),
            title: const Text('项目动态通知'),
            value: settings.projectNotifications,
            onChanged: _writing
                ? null
                : (v) => _update(settings.copyWith(projectNotifications: v)),
          ),
          SwitchListTile(
            key: const Key('privacy-switch'),
            title: const Text('隐藏手机号'),
            subtitle: const Text('向服务人员展示脱敏号码'),
            value: settings.hidePhone,
            onChanged: _writing
                ? null
                : (v) => _update(settings.copyWith(hidePhone: v)),
          ),
          const Divider(),
          ListTile(
            title: const Text('恢复默认通知与隐私设置'),
            subtitle: const Text('不删除账号、地址、项目和提交记录'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _writing ? null : _resetSettings,
          ),
          ListTile(
            title: const Text('关于智地'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _sheet('智地业主端', '智地为业主提供装修服务发现、项目协作与售后记录工具。'),
          ),
          ListTile(
            title: const Text('隐私说明'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _sheet('隐私说明', '我们仅在提供服务所需范围内保存本地资料与设置；手机号可选择脱敏展示。'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text(
              '退出登录',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text('退出后需要重新使用手机号登录'),
            onTap: _writing ? null : _logout,
          ),
        ],
      ),
    );
  }

  Future<void> _resetSettings() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('恢复默认设置？'),
        content: const Text('将恢复默认通知与隐私选项，不会删除账号、地址、项目或提交记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _writing = true);
    try {
      await OwnerAppScope.of(context).resetSettings();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('默认设置已恢复')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('恢复失败，设置未更改，请重试')));
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _sheet(String title, String detail) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(detail),
          ],
        ),
      ),
    ),
  );

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('退出登录？'),
        content: const Text('将清除本机登录状态，下次进入“我的”等页面需要重新验证手机号。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('确认退出'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _writing = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await OwnerAppScope.of(context).logout();
      if (!mounted) return;
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text('已退出登录')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('退出失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }
}
