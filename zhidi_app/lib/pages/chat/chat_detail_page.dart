import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../design/tokens.dart';
import '../../models/chat_models.dart';
import '../../services/chat_api_client.dart';
import '../../services/chat_websocket_service.dart';
import '../../services/auth_api_client.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({
    super.key,
    required this.roomId,
    required this.otherUserName,
    required this.accessToken,
    required this.currentUserId,
  });

  final String roomId;
  final String otherUserName;
  final String accessToken;
  final String currentUserId;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final _api = ChatApiClient();
  final _wsService = ChatWebSocketService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  List<ChatMessageModel> _messages = [];
  bool _loading = true;
  bool _wsConnected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _connectWs();
  }

  @override
  void dispose() {
    _wsService.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await _api.getMessages(
        widget.accessToken,
        widget.roomId,
      );
      final mapped = msgs
          .map((m) => m.copyWithIsMe(widget.currentUserId))
          .toList();
      if (mounted) {
        setState(() {
          _messages = mapped;
          _loading = false;
        });
        _scrollToBottom();
      }
    } on AuthApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '加载失败：$e'; });
    }
  }

  Future<void> _connectWs() async {
    await _wsService.connect(
      accessToken: widget.accessToken,
      currentUserId: widget.currentUserId,
    );
    _wsService.onMessage.listen((msg) {
      if (msg.roomId == widget.roomId) {
        if (mounted) {
          setState(() {
            _messages.add(msg.copyWithIsMe(widget.currentUserId));
          });
          _scrollToBottom();
        }
      }
    });
    _wsService.onConnectionState.listen((state) {
      if (mounted) {
        setState(() {
          _wsConnected = state == WebSocketConnectionState.connected;
        });
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    // 先通过 WebSocket 发送
    if (_wsConnected) {
      _wsService.sendMessage(widget.roomId, {
        'content': text,
        'type': 'TEXT',
      });
    }

    // REST 兜底 + 获取服务器返回的正式消息
    _api.sendMessage(
      widget.accessToken,
      widget.roomId,
      content: text,
    ).then((msg) {
      if (mounted) {
        setState(() {
          // 替换掉可能重复的临时消息
          _messages.removeWhere((m) =>
              m.senderUserId == widget.currentUserId &&
              m.content == text &&
              m.id.isEmpty);
          _messages.add(msg.copyWithIsMe(widget.currentUserId));
        });
        _scrollToBottom();
      }
    }).catchError((_) {
      // WebSocket 已发送，REST 失败不影响体验
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;

    // 本地先显示
    final tempId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final localMsg = ChatMessageModel(
      id: tempId,
      roomId: widget.roomId,
      senderUserId: widget.currentUserId,
      senderRole: 'OWNER',
      type: 'IMAGE',
      content: '',
      imageUrl: image.path,
      createdAt: DateTime.now(),
      isMe: true,
    );
    setState(() => _messages.add(localMsg));
    _scrollToBottom();

    // 上传图片并发送 URL
    try {
      final file = File(image.path);
      final bytes = await file.readAsBytes();
      final response = await _createUploadRequest(image.path, bytes);
      if (response != null) {
        _api.sendMessage(
          widget.accessToken,
          widget.roomId,
          content: response,
          type: 'IMAGE',
        );
        // 移除本地临时消息
        setState(() {
          _messages.removeWhere((m) => m.id == tempId);
        });
      }
    } catch (_) {
      // 保留本地临时消息
    }
  }

  Future<String?> _createUploadRequest(String path, List<int> bytes) async {
    try {
      final uri = Uri.parse('${ChatApiClient().baseUrl}/api/v1/storage/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${widget.accessToken}'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: path.split('/').last,
        ));
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        return body['data']['url'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUserName,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _wsConnected ? '在线' : '连接中…',
              style: TextStyle(
                fontSize: 12,
                color: _wsConnected
                    ? const Color(0xFF07C160)
                    : ZdColors.textHint,
              ),
            ),
          ],
        ),
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
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: ZdText.caption),
            const SizedBox(height: 16),
            TextButton(onPressed: _loadMessages, child: const Text('重试')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final showTime = index == 0 ||
                  _messages[index - 1].createdAt
                      .difference(msg.createdAt)
                      .inMinutes
                      .abs() > 5;
              return _MessageBubble(
                message: msg,
                showTime: showTime,
                otherUserName: widget.otherUserName,
              );
            },
          ),
        ),
        _InputBar(
          controller: _controller,
          onSend: _sendText,
          onPickImage: _pickImage,
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.showTime,
    required this.otherUserName,
  });

  final ChatMessageModel message;
  final bool showTime;
  final String otherUserName;

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final isImage = message.type == 'IMAGE';
    final isSystem = message.type == 'SYSTEM';

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              message.content,
              style: ZdText.tiny,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          if (showTime) ...[
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${message.createdAt.month}/${message.createdAt.day} ${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                  style: ZdText.tiny,
                ),
              ),
            ),
          ],
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) _Avatar(name: otherUserName),
              if (!isMe) const SizedBox(width: 8),
              Flexible(
                child: isImage
                    ? _ImageContent(imageUrl: message.imageUrl!)
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFF07C160)
                              : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft:
                                Radius.circular(isMe ? 18 : 4),
                            bottomRight:
                                Radius.circular(isMe ? 4 : 18),
                          ),
                        ),
                        child: Text(
                          message.content,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: isMe ? Colors.white : ZdColors.textPrimary,
                          ),
                        ),
                      ),
              ),
              if (isMe) const SizedBox(width: 8),
              if (isMe) const _MeAvatar(),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final isLocal = !imageUrl.startsWith('http');
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              body: Center(
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: isLocal
                      ? Image.file(File(imageUrl))
                      : Image.network(imageUrl),
                ),
              ),
            ),
          ),
        );
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.55,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: isLocal
              ? Image.file(File(imageUrl), fit: BoxFit.cover)
              : Image.network(imageUrl, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        color: const Color(0xFFFFEEE3),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: const TextStyle(
            color: ZdColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _MeAvatar extends StatelessWidget {
  const _MeAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8ED),
        borderRadius: BorderRadius.circular(19),
      ),
      child: const Icon(
        Icons.person_outline_rounded,
        size: 25,
        color: Color(0xFF07C160),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onPickImage,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onPickImage,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: ZdColors.background,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  size: 22,
                  color: ZdColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '请输入消息',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  hintStyle: TextStyle(
                    color: ZdColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: onSend,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF07C160),
                foregroundColor: Colors.white,
                minimumSize: const Size(68, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: const Text(
                '发送',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
