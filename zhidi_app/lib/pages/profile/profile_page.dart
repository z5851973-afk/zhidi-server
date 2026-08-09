import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../app/owner_app_state.dart';
import 'edit_profile_page.dart';
import 'address_page.dart';
import 'feedback_page.dart';
import 'profile_components.dart';
import 'settings_page.dart';
import 'support_page.dart';
import '../order/my_orders_page.dart';
import '../home/my_home_page.dart';
import 'favorites_page.dart';
import '../../design/tokens.dart';
import '../../services/auth_api_client.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.projectsPageBuilder,
    this.projectRefresh,
    this.refreshEpoch = 0,
  });

  final WidgetBuilder? projectsPageBuilder;
  final Future<void> Function()? projectRefresh;
  final int refreshEpoch;

  @override
  State<ProfilePage> createState() => _ProfilePageState();

  static const _services = [
    (Icons.event_available_rounded, '我的预约'),
    (Icons.chat_bubble_outline_rounded, '在线咨询'),
    (Icons.favorite_border_rounded, '我的收藏'),
    (Icons.support_agent_rounded, '平台客服'),
  ];
  static const _management = [
    (Icons.location_on_outlined, '地址管理'),
    (Icons.verified_user_outlined, '保障与售后'),
    (Icons.help_outline_rounded, '帮助与反馈'),
    (Icons.settings_outlined, '设置'),
  ];
}

class _ProfilePageState extends State<ProfilePage> {
  String? _projectRefreshError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshProjects());
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshEpoch != oldWidget.refreshEpoch) {
      unawaited(_refreshProjects());
    }
  }

  Future<void> _refreshProjects() async {
    try {
      final state = OwnerAppScope.of(context);
      await (widget.projectRefresh?.call() ??
          state.fetchRemoteServiceRequests());
      if (!mounted) return;
      setState(() => _projectRefreshError = state.remoteServiceRequestError);
    } catch (_) {
      if (mounted) setState(() => _projectRefreshError = '项目加载失败，请重试');
    }
  }

  void _open(BuildContext context, String title) {
    if (title == '在线咨询') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('平台咨询暂未开放')));
      return;
    }
    final destination = switch (title) {
      '地址管理' => const AddressPage(),
      '保障与售后' || '平台客服' => const SupportPage(),
      '帮助与反馈' => const FeedbackPage(),
      '设置' => const SettingsPage(),
      '我的预约' => const MyOrdersPage(),
      '我的收藏' => const FavoritesPage(),
      _ => ProfilePlaceholderPage(title: title),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ZdColors.primary, Color(0xFFFF914D)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: _ProfileHeader(
              name: state.profile.name,
              city: state.profile.city,
              avatarUrl: state.profile.avatarUrl,
              projectCount: state.remoteProjectCount,
              onProjects: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (routeContext) =>
                      widget.projectsPageBuilder?.call(routeContext) ??
                      const MyHomePage(),
                ),
              ),
              onEdit: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfilePage()),
              ),
            ),
          ),
          if (_projectRefreshError != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _refreshProjects,
              child: Text('$_projectRefreshError · 重试'),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            '我的服务',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ProfileSectionCard(
            child: Column(
              children: [
                for (final item in ProfilePage._services)
                  ProfileMenuTile(
                    icon: item.$1,
                    label: item.$2,
                    onTap: () => _open(context, item.$2),
                    badge: item.$2 == '我的收藏'
                        ? (_FavoritesBadge(state: state))
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '管理与支持',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ProfileSectionCard(
            child: Column(
              children: [
                for (final item in ProfilePage._management)
                  ProfileMenuTile(
                    icon: item.$1,
                    label: item.$2,
                    onTap: () => _open(context, item.$2),
                    subtitle: item.$2 == '地址管理'
                        ? (state.addresses.isEmpty
                              ? '还未添加常用地址'
                              : '${state.addresses.length} 个常用地址')
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.city,
    required this.avatarUrl,
    required this.projectCount,
    required this.onProjects,
    required this.onEdit,
  });

  final String name;
  final String city;
  final String? avatarUrl;
  final int projectCount;
  final VoidCallback onProjects;
  final VoidCallback onEdit;

  Widget get _avatar {
    final raw = avatarUrl?.trim();
    final resolved = raw == null || raw.isEmpty
        ? null
        : (Uri.parse(raw).hasScheme
              ? raw
              : Uri.parse(
                  AuthApiClient.configuredBaseUrl,
                ).resolve(raw).toString());
    return Container(
      width: 60,
      height: 60,
      decoration: const BoxDecoration(
        color: Color(0x33FFFFFF),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: resolved == null
          ? const Icon(Icons.person_rounded, color: Colors.white, size: 36)
          : Image.network(
              resolved,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
    );
  }

  Widget _identity({int nameLines = 1}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        name.trim().isEmpty ? '完善个人资料' : name,
        maxLines: nameLines,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: Colors.white, size: 16),
          SizedBox(width: 4),
          Text(
            '手机号已验证',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    ],
  );

  Widget get _editButton => TextButton(
    onPressed: onEdit,
    child: const Text('编辑资料', style: TextStyle(color: Colors.white)),
  );

  Widget get _projectCountLabel => Semantics(
    button: true,
    label: '查看 $projectCount 个项目',
    child: InkWell(
      onTap: onProjects,
      borderRadius: BorderRadius.circular(ZdRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Text(
          '$projectCount 个项目',
          style: const TextStyle(color: Color(0xE6FFFFFF)),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = MediaQuery.sizeOf(context).width < 360 || textScale > 1.3;
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar,
              const SizedBox(width: 14),
              Expanded(child: _identity(nameLines: 2)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            city.trim().isEmpty ? '未设置城市' : city,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xE6FFFFFF)),
          ),
          Align(alignment: Alignment.centerLeft, child: _projectCountLabel),
          Align(alignment: Alignment.centerRight, child: _editButton),
        ],
      );
    }
    return Row(
      children: [
        _avatar,
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _identity(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      city.trim().isEmpty ? '未设置城市' : city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xE6FFFFFF)),
                    ),
                  ),
                  const Text(
                    '  ·  ',
                    style: TextStyle(color: Color(0xE6FFFFFF)),
                  ),
                  _projectCountLabel,
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        _editButton,
      ],
    );
  }
}

class _FavoritesBadge extends StatelessWidget {
  const _FavoritesBadge({required this.state});
  final OwnerAppState state;
  @override
  Widget build(BuildContext context) {
    final count = state.savedQuotes.length;
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5A00),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
