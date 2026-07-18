import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../models/chat_models.dart';
import '../../services/chat_api_client.dart';
import '../../services/auth_api_client.dart';
import 'chat_detail_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({
    super.key,
    required this.accessToken,
    required this.currentUserId,
  });

  final String accessToken;
  final String currentUserId;

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _api = ChatApiClient();
  List<ChatRoomModel> _rooms = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await _api.getRooms(widget.accessToken);
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _loading = false;
        });
      }
    } on AuthApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '加载失败：$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text('消息'),
        backgroundColor: Colors.white,
        foregroundColor: ZdColors.textPrimary,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: ZdText.caption),
            const SizedBox(height: 16),
            TextButton(onPressed: _loadRooms, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('暂无聊天消息', style: ZdText.caption),
            const SizedBox(height: 4),
            Text(
              '预约确认后会在这里显示聊天入口',
              style: ZdText.tiny,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: ListView.separated(
        padding: const EdgeInsets.all(ZdSpacing.md),
        itemCount: _rooms.length,
        separatorBuilder: (_, _) => const SizedBox(height: ZdSpacing.sm),
        itemBuilder: (context, index) {
          final room = _rooms[index];
          return _RoomTile(
            room: room,
            onTap: () => _openChat(room),
          );
        },
      ),
    );
  }

  void _openChat(ChatRoomModel room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          roomId: room.id,
          otherUserName: room.otherUserName,
          accessToken: widget.accessToken,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, this.onTap});
  final ChatRoomModel room;
  final VoidCallback? onTap;

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ZdRadius.card),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: ZdColors.primary.withValues(alpha: 0.12),
              child: Text(
                room.otherUserName.isNotEmpty
                    ? room.otherUserName[0]
                    : '?',
                style: const TextStyle(
                  color: ZdColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.otherUserName,
                          style: ZdText.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(room.lastMessageAt),
                        style: ZdText.tiny,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.lastMessageText ?? '暂无消息',
                          style: TextStyle(
                            fontSize: 13,
                            color: room.unreadCount > 0
                                ? ZdColors.textPrimary
                                : ZdColors.textHint,
                            fontWeight: room.unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (room.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: ZdColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
