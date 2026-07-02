import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';
import '../chat/chat_page.dart';
import 'notification_detail_page.dart';

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

  static const _categories = <_Category>[
    _Category('系统通知', Icons.campaign_outlined, {'系统'}),
    _Category('订单通知', Icons.receipt_long_outlined, {'订单', '预约'}),
    _Category('工单通知', Icons.build_outlined, {'工单', '项目'}),
    _Category('互动消息', Icons.people_outline, {'互动'}),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _inCategory(OwnerMessage message, _Category category) =>
      category.values.contains(message.category);

  List<OwnerMessage> _filtered(List<OwnerMessage> messages) {
    final keyword = _keyword.trim().toLowerCase();
    final selected = _categories
        .where((item) => item.label == _category)
        .firstOrNull;
    return messages.where((message) {
      final matchesKeyword =
          keyword.isEmpty ||
          message.title.toLowerCase().contains(keyword) ||
          message.content.toLowerCase().contains(keyword);
      final matchesCategory =
          selected == null || _inCategory(message, selected);
      return matchesKeyword &&
          matchesCategory &&
          (!_unreadOnly || !message.isRead);
    }).toList();
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    final state = OwnerAppScope.of(context);
    if (state.unreadMessageCount == 0) return;
    setState(() => _markingAll = true);
    try {
      await state.markAllMessagesRead();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已全部标记为已读')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('标记失败，请稍后重试')));
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
              : NotificationDetailPage(message: message.copyWith(isRead: true)),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('消息状态保存失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _openingMessageId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    final messages = _filtered(state.messages);
    return ColoredBox(
      color: const Color(0xFFF7F7FB),
      child: Column(
        children: [
          _topBar(),
          _categoryBar(state.messages),
          _filterBar(),
          const Divider(height: 1),
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text('暂无匹配消息'))
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: messages.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (_, index) => _messageRow(messages[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() => Container(
    color: Colors.white,
    padding: EdgeInsets.fromLTRB(
      16,
      MediaQuery.of(context).padding.top + 8,
      16,
      12,
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Text(
              '消息',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton(
              onPressed: _markingAll ? null : _markAllRead,
              child: _markingAll
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('全部已读'),
            ),
          ],
        ),
        TextField(
          key: const Key('message-search'),
          controller: _searchController,
          onChanged: (value) => setState(() => _keyword = value),
          decoration: InputDecoration(
            hintText: '搜索消息内容',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _keyword.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空搜索',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _keyword = '');
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _categoryBar(List<OwnerMessage> messages) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _categories.map((category) {
        final unread = messages
            .where((m) => !m.isRead && _inCategory(m, category))
            .length;
        final selected = category.label == _category;
        return InkWell(
          onTap: () =>
              setState(() => _category = selected ? null : category.label),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              children: [
                Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFFE9DF)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      category.icon,
                      color: selected ? const Color(0xFFFF6B35) : null,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected ? const Color(0xFFFF6B35) : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    ),
  );

  Widget _filterBar() => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Row(
      children: [
        ChoiceChip(
          label: const Text('全部'),
          selected: !_unreadOnly,
          onSelected: (_) => setState(() => _unreadOnly = false),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('未读'),
          selected: _unreadOnly,
          onSelected: (_) => setState(() => _unreadOnly = true),
        ),
        if (_category != null) ...[
          const Spacer(),
          ActionChip(
            label: Text('$_category ×'),
            onPressed: () => setState(() => _category = null),
          ),
        ],
      ],
    ),
  );

  Widget _messageRow(OwnerMessage message) {
    final pageBusy = _openingMessageId != null;
    final busy = _openingMessageId == message.id;
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: pageBusy ? null : () => _open(message),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Badge(
                isLabelVisible: !message.isRead,
                child: CircleAvatar(
                  backgroundColor: const Color(0xFFFFF0E8),
                  child: Icon(
                    message.category == '互动'
                        ? Icons.person
                        : Icons.notifications,
                    color: const Color(0xFFFF6B35),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.title,
                      style: TextStyle(
                        fontWeight: message.isRead
                            ? FontWeight.w500
                            : FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF777777)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _formatListTime(message.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatListTime(DateTime time) =>
    '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';

class _Category {
  const _Category(this.label, this.icon, this.values);
  final String label;
  final IconData icon;
  final Set<String> values;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
