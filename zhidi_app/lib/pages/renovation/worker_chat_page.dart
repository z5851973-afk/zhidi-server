import 'package:flutter/material.dart';
import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';
import '../../design/tokens.dart';

const _primary = ZdColors.primary;
const _green = ZdColors.success;
const _bg = ZdColors.background;
const _textDark = ZdColors.textPrimary;
const _textLight = ZdColors.textSecondary;
const _bubbleBg = ZdColors.background;

class WorkerChatPage extends StatefulWidget {
  final String workerName;

  const WorkerChatPage({super.key, required this.workerName});

  @override
  State<WorkerChatPage> createState() => _WorkerChatPageState();
}

class _WorkerChatPageState extends State<WorkerChatPage> {
  final _textController = TextEditingController();
  final _messages = <String>[];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.workerName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: _green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Text('在线', style: TextStyle(fontSize: 12, color: _green)),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // ── 消息列表 ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: [
                _buildWelcomeBubble(),
                for (final message in _messages) ...[
                  const SizedBox(height: 12),
                  _buildUserBubble(message),
                ],
              ],
            ),
          ),
          // ── 底部输入栏 ──
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── 欢迎语气泡 ──
  Widget _buildWelcomeBubble() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 橙色圆形头像
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: _primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, size: 24, color: Colors.white),
        ),
        const SizedBox(width: 10),
        // 气泡
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _bubbleBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: const Text(
              '您好，我是知底AI装修顾问！请说说你的需求，我帮你规划。',
              style: TextStyle(fontSize: 14, color: _textDark, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── 底部输入栏 ──
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 图片按钮
            _InputIconButton(
              icon: Icons.image_outlined,
              onTap: () => _showUnavailable('图片发送暂未开放'),
            ),
            const SizedBox(width: 4),
            // 麦克风按钮
            _InputIconButton(
              icon: Icons.mic_none_rounded,
              onTap: () => _showUnavailable('语音发送暂未开放'),
            ),
            const SizedBox(width: 10),
            // 输入框
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: ZdColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(fontSize: 14, color: _textDark),
                  decoration: const InputDecoration(
                    hintText: '请输入咨询内容',
                    hintStyle: TextStyle(fontSize: 14, color: _textLight),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 发送按钮
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(17),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '发送',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(text);
      _textController.clear();
    });
    _persistMessage(text);
  }

  void _persistMessage(String text) {
    try {
      final now = DateTime.now();
      OwnerAppScope.of(context)
          .addChatMessage(
            widget.workerName,
            ChatMessage(
              id: 'worker-chat-${now.millisecondsSinceEpoch}',
              workerId: widget.workerName,
              workerName: widget.workerName,
              text: text,
              isMe: true,
              createdAt: now,
            ),
          )
          .catchError((_) {});
    } catch (_) {
      // Allows lightweight previews/tests of this page without OwnerAppScope.
    }
  }

  void _showUnavailable(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildUserBubble(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 输入栏图标按钮 ──
class _InputIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _InputIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: ZdColors.background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, size: 20, color: _textLight),
      ),
    );
  }
}
