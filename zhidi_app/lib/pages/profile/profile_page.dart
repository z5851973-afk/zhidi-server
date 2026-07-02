import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import 'edit_profile_page.dart';
import 'profile_components.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

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

  void _open(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfilePlaceholderPage(title: title)),
    );
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
                colors: [Color(0xFFFF6B35), Color(0xFFFF914D)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0x33FFFFFF),
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.profile.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        '已实名认证',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            state.profile.city,
                            style: const TextStyle(color: Color(0xE6FFFFFF)),
                          ),
                          const Text(
                            '  ·  ',
                            style: TextStyle(color: Color(0xE6FFFFFF)),
                          ),
                          Text(
                            '${state.projects.length} 个项目',
                            style: const TextStyle(color: Color(0xE6FFFFFF)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
                  ),
                  child: const Text(
                    '编辑资料',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '我的服务',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ProfileSectionCard(
            child: Column(
              children: [
                for (final item in _services)
                  ProfileMenuTile(
                    icon: item.$1,
                    label: item.$2,
                    onTap: () => _open(context, item.$2),
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
                for (final item in _management)
                  ProfileMenuTile(
                    icon: item.$1,
                    label: item.$2,
                    onTap: () => _open(context, item.$2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
