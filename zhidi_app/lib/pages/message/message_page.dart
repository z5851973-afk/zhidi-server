import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';
import '../chat/chat_page.dart';
import 'notification_detail_page.dart';
import '../../design/tokens.dart';

// ── 设计常量 ──
const _primary = ZdColors.primary;
const _primaryBg = Color(0xFFFFF7F0);
const _textDark = ZdColors.textPrimary;
const _textMid = Color(0xFF666666);
const _textLight = ZdColors.textSecondary;
const _bg = ZdColors.background;
const _cardBg = Colors.white;

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final _searchController = TextEditingController();
  String _keyword = '';
  String? _category;
  bool _unreadOnly = false;
  bool _markingAll = false;
  String? _openingMessageId;

  static const _categories = <_MessageCategory>[
    _MessageCategory('系统通知', Icons.campaign_outlined, {'系统'}),
    _MessageCategory('订单通知', Icons.receipt_long_outlined, {'订单', '预约'}),
    _MessageCategory('工单通知', Icons.build_outlined, {'工单', '项目', '验收'}),
    _MessageCategory('互动消息', Icons.people_outline, {'互动'}),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _inCategory(OwnerMessage m, _MessageCategory cat) =>
      cat.values.contains(m.category);

  List<OwnerMessage> _filtered(List<OwnerMessage> messages) {
    final kw = _keyword.trim().toLowerCase();
    final selected =
        _categories.where((c) => c.label == _category).firstOrNull;
    return messages.where((m) {
      final hits =
          kw.isEmpty ||
          m.title.toLowerCase().contains(kw) ||
          m.content.toLowerCase().contains(kw);
      final inCat = selected == null || _inCategory(m, selected);
      return hits && inCat && (!_unreadOnly || !m.isRead);
    }).toList();
  }

  /// 从 chatMessages 构建互动消息列表
  List<_InteractionEntry> _buildInteractionEntries(Map<String, List<ChatMessage>> chatMsgs) {
    final entries = <_InteractionEntry>[];
    chatMsgs.forEach((workerId, msgs) {
      if (msgs.isEmpty) return;
      final last = msgs.last;
      // 排除纯 welcome 消息（首条 AI 消息无用户交互）
      final hasUserMsg = msgs.any((m) => m.isMe);
      if (!hasUserMsg) return;
      entries.add(_InteractionEntry(
        workerId: workerId,
        workerName: last.workerName,
        lastText: last.text,
        lastTime: last.createdAt,
        messageCount: msgs.length,
      ));
    });
    // 按时间倒序排列
    entries.sort((a, b) => b.lastTime.compareTo(a.lastTime));
    return entries;
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    final state = OwnerAppScope.of(context);
    if (state.unreadMessageCount == 0) return;
    setState(() => _markingAll = true);
    try {
      await state.markAllMessagesRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已全部标记为已读')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('标记失败，请稍后重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _open(OwnerMessage message) async {
    if (_openingMessageId != null) return;
    setState(() => _openingMessageId = message.id);
    try {
      await OwnerAppScope.of(context).markMessageRead(message.id);
      if (!mounted) return;
      final isHuman = message.category == '互动';
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => isHuman
              ? ChatPage(workerName: message.title)
              : NotificationDetailPage(
                  message: message.copyWith(isRead: true),
                ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('消息状态保存失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingMessageId = null);
    }
  }

  Future<void> _openChat(String workerId, String workerName) async {
    if (_openingMessageId != null) return;
    setState(() => _openingMessageId = workerId);
    try {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatPage(
            workerName: workerName,
            workerId: workerId,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingMessageId = null);
    }
  }

  // ── 构建 ──

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    final isInteraction = _category == '互动消息';
    final messages = _filtered(state.messages);
    final unreadCount = state.unreadMessageCount;

    // 互动消息：构建聊天记录预览列表
    final interactionEntries = isInteraction
        ? _buildInteractionEntries(state.chatMessages)
        : null;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _topBar(unreadCount),
          _searchBar(),
          _categoryBar(state.messages),
          _filterChips(),
          const SizedBox(height: 4),
          Expanded(
            child: isInteraction
                ? _interactionList(interactionEntries!)
                : messages.isEmpty
                    ? _emptyView()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: messages.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 2),
                        itemBuilder: (_, i) => _messageCard(messages[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _interactionList(List<_InteractionEntry> entries) {
    if (entries.isEmpty) return _emptyView();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (_, i) => _interactionCard(entries[i]),
    );
  }

  Widget _interactionCard(_InteractionEntry entry) {
    final pageBusy = _openingMessageId != null;
    final busy = _openingMessageId == entry.workerId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: pageBusy ? null : () => _openChat(entry.workerId, entry.workerName),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 师傅头像
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF7E57C2).withAlpha(40), const Color(0xFF7E57C2).withAlpha(15)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.person, size: 22, color: Color(0xFF7E57C2)),
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
                            entry.workerName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _textDark,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (busy)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.lastText,
                            style: const TextStyle(fontSize: 13, color: _textMid, height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(entry.lastTime),
                          style: const TextStyle(fontSize: 11, color: _textLight),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 顶部栏 ──
  Widget _topBar(int unreadCount) => Container(
    color: _cardBg,
    padding: EdgeInsets.fromLTRB(
      20,
      MediaQuery.of(context).padding.top + 14,
      16,
      8,
    ),
    child: Row(
      children: [
        const Text(
          '消息',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _textDark,
            letterSpacing: -0.5,
          ),
        ),
        if (unreadCount > 0) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$unreadCount 条未读',
              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const Spacer(),
        TextButton(
          onPressed: _markingAll ? null : _markAllRead,
          style: TextButton.styleFrom(
            foregroundColor: _primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          child: _markingAll
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('全部已读'),
        ),
      ],
    ),
  );

  // ── 搜索栏 ──
  Widget _searchBar() => Container(
    color: _cardBg,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: TextField(
      key: const Key('message-search'),
      controller: _searchController,
      onChanged: (v) => setState(() => _keyword = v),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: '搜索消息内容',
        hintStyle: const TextStyle(color: _textLight, fontSize: 14),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 12, right: 6),
          child: Icon(Icons.search, size: 20, color: _textLight),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: _keyword.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18, color: _textLight),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _keyword = '');
                },
              )
            : null,
        filled: true,
        fillColor: _bg,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  // ── 分类栏 ──
  Widget _categoryBar(List<OwnerMessage> messages) {
    final chatMsgs = OwnerAppScope.of(context).chatMessages;
    return Container(
    color: _cardBg,
    padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
    child: Row(
      children: _categories.map((cat) {
        final int unread = cat.label == '互动消息'
            ? chatMsgs.values.where((msgs) => msgs.any((m) => m.isMe)).length
            : messages.where((m) => !m.isRead && _inCategory(m, cat)).length;
        final selected = cat.label == _category;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: cat == _categories.first ? 0 : 5,
              right: cat == _categories.last ? 0 : 5,
            ),
            child: GestureDetector(
              onTap: () =>
                  setState(() => _category = selected ? null : cat.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? cat.bgColor : cat.bgColor.withAlpha(80),
                  borderRadius: BorderRadius.circular(10),
                  border: selected
                      ? Border.all(color: cat.accentColor, width: 1)
                      : Border.all(color: Colors.transparent, width: 1),
                ),
                child: Column(
                  children: [
                    Icon(cat.icon, size: 22, color: selected ? cat.accentColor : _textLight),
                    const SizedBox(height: 4),
                    Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? cat.accentColor : _textMid,
                      ),
                    ),
                    if (unread > 0) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: selected ? cat.accentColor : cat.accentColor.withAlpha(50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$unread',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : cat.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
  }

  // ── 筛选标签 ──
  Widget _filterChips() => Container(
    color: _cardBg,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: Row(
      children: [
        _chip('全部', !_unreadOnly, () => setState(() => _unreadOnly = false)),
        const SizedBox(width: 8),
        _chip('未读', _unreadOnly, () => setState(() => _unreadOnly = true)),
        if (_category != null) ...[
          const Spacer(),
          ActionChip(
            label: Text(
              '$_category ×',
              style: const TextStyle(fontSize: 12, color: _primary),
            ),
            backgroundColor: _primaryBg,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onPressed: () => setState(() => _category = null),
          ),
        ],
      ],
    ),
  );

  Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? _primary : _bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: selected ? Colors.white : _textMid,
        ),
      ),
    ),
  );

  // ── 消息卡片 ──
  Widget _messageCard(OwnerMessage message) {
    final pageBusy = _openingMessageId != null;
    final busy = _openingMessageId == message.id;
    final cat = _categories.where((c) => _inCategory(message, c)).firstOrNull;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: pageBusy ? null : () => _open(message),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧图标
              _messageIcon(message, cat),
              const SizedBox(width: 12),
              // 中间文字
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!message.isRead) ...[
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            message.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: message.isRead ? FontWeight.w500 : FontWeight.w600,
                              color: _textDark,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!message.isRead)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: _primaryBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '新',
                              style: TextStyle(fontSize: 10, color: _primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.content,
                            style: const TextStyle(fontSize: 13, color: _textMid, height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(message.createdAt),
                          style: const TextStyle(fontSize: 11, color: _textLight),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 消息图标 ──
  Widget _messageIcon(OwnerMessage message, _MessageCategory? cat) {
    final icon = cat?.icon ?? Icons.notifications_outlined;
    final accent = cat?.accentColor ?? _textLight;
    final bg = cat?.bgColor ?? ZdColors.background;

    if (message.category == '互动') {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withAlpha(40), accent.withAlpha(15)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(Icons.person, size: 22, color: accent),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22, color: accent),
    );
  }

  // ── 空状态 ──
  Widget _emptyView() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inbox_outlined, size: 56, color: _textLight.withAlpha(80)),
        const SizedBox(height: 12),
        const Text('暂无匹配消息', style: TextStyle(color: _textLight, fontSize: 14)),
      ],
    ),
  );
}

// ── 时间格式化 ──
String _formatTime(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDate = DateTime(time.year, time.month, time.day);
  final diff = today.difference(msgDate).inDays;

  if (diff == 0) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  } else if (diff == 1) {
    return '昨天';
  } else if (diff < 7) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[time.weekday - 1];
  } else {
    return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }
}

// ── 分类数据模型 ──
class _MessageCategory {
  const _MessageCategory(this.label, this.icon, this.values);

  final String label;
  final IconData icon;
  final Set<String> values;

  Color get accentColor => switch (label) {
    '系统通知' => const Color(0xFF607D8B),
    '订单通知' => const Color(0xFFFFA726),
    '工单通知' => const Color(0xFF66BB6A),
    '互动消息' => const Color(0xFF7E57C2),
    _ => _primary,
  };

  Color get bgColor => switch (label) {
    '系统通知' => const Color(0xFFECEFF1),
    '订单通知' => const Color(0xFFFFF3E0),
    '工单通知' => const Color(0xFFE8F5E9),
    '互动消息' => const Color(0xFFEDE7F6),
    _ => _primaryBg,
  };
}

class _InteractionEntry {
  final String workerId;
  final String workerName;
  final String lastText;
  final DateTime lastTime;
  final int messageCount;

  const _InteractionEntry({
    required this.workerId,
    required this.workerName,
    required this.lastText,
    required this.lastTime,
    required this.messageCount,
  });
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
