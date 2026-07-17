import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../design/tokens.dart';
import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';

class ChatPage extends StatefulWidget {
  final String workerName;
  final String? workerId;
  final String? avatarPath;
  final String? initialMessage;

  const ChatPage({
    super.key,
    required this.workerName,
    this.workerId,
    this.avatarPath,
    this.initialMessage,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final bool _isOnline = true;
  final String _lastSeen = '刚刚在线';
  bool _isRecording = false;

  late List<_Message> _messages;
  final _ConversationContext _ctx = _ConversationContext();
  bool _initialized = false;

  String get _effectiveWorkerId => widget.workerId ?? widget.workerName;

  void _persistMessage(_Message msg) {
    if (msg.text == null || msg.text!.isEmpty) return;
    if (msg.type == _MsgType.thinking) return; // 不持久化思考态
    try {
      final state = OwnerAppScope.of(context);
      final now = DateTime.now();
      state.addChatMessage(
        _effectiveWorkerId,
        ChatMessage(
          id: 'chat-${now.millisecondsSinceEpoch}-${msg.hashCode}',
          workerId: _effectiveWorkerId,
          workerName: widget.workerName,
          text: msg.text!,
          isMe: msg.isMe,
          createdAt: now,
        ),
      );
    } catch (_) {
      // 静默失败，不阻塞聊天
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    // 尝试从持久化状态加载已有聊天记录
    if (widget.workerId != null) {
      try {
        final existing = OwnerAppScope.of(context).getChatMessages(_effectiveWorkerId);
        if (existing.isNotEmpty) {
          _messages = existing.map((cm) => _Message(
            text: cm.text,
            isMe: cm.isMe,
            isRead: true,
          )).toList();
          for (final cm in existing) {
            if (cm.isMe) _ctx.ingest(cm.text);
          }
          return;
        }
      } catch (_) {
        // fall through to default init
      }
    }

    final initial = widget.initialMessage;
    if (initial != null && initial.isNotEmpty) {
      _messages = [
        _Message(text: '您好，我是知底AI装修顾问！请说说你的需求，我帮你规划。', isMe: false),
        _Message(text: initial, isMe: true, isRead: true),
      ];
      // 从首条消息提取已知信息
      _ctx.ingest(initial);
      // 状态卡入口特殊处理，其余走智能追问
      if (initial.contains('急活') || initial.contains('急修')) {
        _messages.add(_Message(
          text: '别急，马上帮你找师傅！先告诉我是什么问题——',
          isMe: false,
          type: _MsgType.quickReplies,
          quickReplies: ['水管/龙头漏水', '电路跳闸/没电', '管道堵塞', '其他紧急问题'],
        ));
      } else if (initial.contains('进行到一半') || initial.contains('正在装修')) {
        _messages.add(_Message(
          text: '好的，继续推进你的装修！需要我帮你做什么——',
          isMe: false,
          type: _MsgType.quickReplies,
          quickReplies: ['继续排剩余工序', '想看当前进度', '想换一个师傅', '有问题要咨询'],
        ));
      } else {
        _showThinkingThenReply();
      }
    } else {
      _messages = [
        _Message(text: '您好，我是知底AI装修顾问！请说说你的需求，我帮你规划。', isMe: false),
      ];
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _humanTrigger = ['转人工', '人工客服', '找人工', '我要人工', '联系人工', '人工服务'];

  void _onChipTap(String chip) {
    setState(() {
      _messages.add(_Message(text: chip, isMe: true, isRead: true));
    });
    _ctx.ingest(chip);
    _showThinkingThenReply();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final lower = text.toLowerCase();
    final isHumanTrigger = _humanTrigger.any((kw) => lower.contains(kw));

    setState(() {
      _messages.add(_Message(text: text, isMe: true));
    });

    _controller.clear();

    // 持久化用户消息
    _persistMessage(_Message(text: text, isMe: true));

    if (isHumanTrigger) {
      _showTransferDialog(context);
      return;
    }

    _ctx.ingest(text);
    _showThinkingThenReply();
  }

  void _showThinkingThenReply() {
    // 先插入思考态
    setState(() => _messages.add(_Message.thinking()));

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      final reply = _buildNextQuestion();
      setState(() {
        // 移除思考态
        _messages.removeWhere((m) => m.type == _MsgType.thinking);
        if (reply != null) {
          _messages.add(reply);
          _persistMessage(reply);
        }
      });
    });
  }

  /// 根据上下文缺失信息，生成下一个追问。信息齐全则给出匹配结论。
  _Message? _buildNextQuestion() {
    // 0. 用户问了工期 / 时间 → 优先回答，不要跳过
    if (_ctx.hasTimelineQuestion && !_ctx.timelineAnswered) {
      _ctx.timelineAnswered = true;
      return _buildTimelineAnswer();
    }

    // 1. 没有工种 → 先问工种
    if (_ctx.trade == null && !_ctx.isFullRenovation) {
      return _Message(
        text: '好的，我记下了。你想找哪个工种的师傅？不同工种的报价差异挺大，选对了才能帮你精准匹配——',
        isMe: false,
        type: _MsgType.quickReplies,
        quickReplies: ['瓦工（贴砖/砌墙）', '水电工', '油漆工', '木工', '其他工种'],
      );
    }

    // 2. 有工种但没有房间（且不是全屋）→ 问房间
    if (_ctx.trade != null && _ctx.room == null && !_ctx.isFullRenovation) {
      final t = _ctx.trade!;
      return _Message(
        text: '$t没问题。具体是哪个房间要做？不同空间施工量和价格都不一样——',
        isMe: false,
        type: _MsgType.quickReplies,
        quickReplies: ['厨房', '卫生间', '客厅', '卧室', '阳台', '多个房间'],
      );
    }

    // 3. 没有面积 → 问面积
    if (_ctx.area == null) {
      final roomHint = _ctx.room != null && _ctx.room != '全屋' ? _ctx.room! : '';
      String intro;
      if (roomHint.isNotEmpty) {
        intro = '$roomHint贴砖的话，';
      } else {
        intro = '';
      }
      return _Message(
        text: '$intro大概多大面积？面积直接决定工时和用料——',
        isMe: false,
        type: _MsgType.quickReplies,
        quickReplies: _ctx.room == '全屋'
            ? ['60-80平', '80-100平', '100-120平', '120平以上']
            : ['5平米左右', '8平米左右', '10平米左右', '15平米以上'],
      );
    }

    // 4. 全屋装修 → 问预算 + 风格
    if (_ctx.isFullRenovation && _ctx.budget == null) {
      return _Message(
        text: '${_ctx.area}平装修，规模和空间都不小。下一步得帮你对标预算和风格——不同定位报价差距很大，你说个数我帮你参考——',
        isMe: false,
        type: _MsgType.quickReplies,
        quickReplies: ['8-12万简约', '12-18万现代', '18-25万中高端', '先看方案再定'],
      );
    }

    // 5. 瓦工 → 问材料
    if (_ctx.trade == '瓦工' && _ctx.material == null) {
      return _Message(
        text: '说到贴砖，关键一点——材料是你自己买，还是让师傅包工包料？这直接影响报价结构——',
        isMe: false,
        type: _MsgType.quickReplies,
        quickReplies: ['瓷砖我买好了', '需要师傅包料', '还没买，先报人工费'],
      );
    }

    // 6. 油漆工 → 问材料
    if (_ctx.trade == '油漆工' && _ctx.material == null) {
      return _Message(
        text: '刷漆这块——乳胶漆是你自己买，还是让师傅包料？两种方式报价不一样——',
        isMe: false,
        type: _MsgType.quickReplies,
        quickReplies: ['漆我买好了', '需要师傅包料', '先报人工费看看'],
      );
    }

    // 7. 信息齐全 → 给出匹配结论
    return _buildMatchConclusion();
  }

  _Message _buildMatchConclusion() {
    final parts = <String>[];
    if (_ctx.room != null) parts.add(_ctx.room!);
    if (_ctx.trade != null) parts.add(_ctx.trade!);
    if (_ctx.area != null) parts.add('${_ctx.area}平');
    final desc = parts.join('') + (_ctx.isFullRenovation ? '装修' : '');

    return _Message(
      text: '好的，信息齐全了。$desc——我现在帮你匹配有类似案例经验的师傅，报价也会一并整理出来——',
      isMe: false,
      type: _MsgType.quickReplies,
      quickReplies: ['帮我联系师傅', '先看看师傅评价', '还想问其他问题', '看看类似案例'],
    );
  }

  /// 结合作业量给出工期回答，按关键阶段拆解耗时
  _Message _buildTimelineAnswer() {
    final area = _ctx.area ?? '90平';
    final areaNum = int.tryParse(area.replaceAll(RegExp(r'[^0-9]'), '')) ?? 90;
    final isRough = ['毛坯', '新房', '旧房', '老房'].any((kw) => _ctx.timelineRaw.contains(kw));
    final userDays = _ctx.timelineDays;

    // 各阶段耗时（毛坯房全屋装修标准）
    final phases = <Map<String, String>>[
      if (isRough) {'name': '墙体改造/拆除', 'days': '3–5天'},
      {'name': '水电改造', 'days': '7–10天'},
      {'name': '泥瓦工（防水+贴砖）', 'days': areaNum >= 100 ? '12–18天' : '8–12天'},
      {'name': '木工（吊顶+柜体）', 'days': '7–15天'},
      {'name': '油漆工（刮腻子+刷漆）', 'days': '10–15天'},
      {'name': '安装（橱柜/门/地板/卫浴）', 'days': '7–10天'},
      {'name': '保洁+散味通风', 'days': '3–5天'},
    ];

    // 计算理论最快和最慢
    int fastest = 0, slowest = 0;
    for (final p in phases) {
      final d = p['days']!;
      final m = RegExp(r'(\d+)').allMatches(d);
      final nums = m.map((e) => int.parse(e.group(1)!)).toList();
      fastest += nums.first;
      slowest += nums.last;
    }

    String verdict;
    if (userDays != null) {
      if (userDays >= fastest && userDays <= slowest) {
        verdict = '所以只要衔接紧凑、材料不拖、没有返工，$userDays天理论上是够的。但说句实话，实际装修很少完全不超，建议留10–15天余量更稳。';
      } else if (userDays > slowest) {
        verdict = '纯施工最多$slowest天，你留了$userDays天，相当从容。材料进场、工种衔接、散味都绰绰有余，不用担心赶工。';
      } else {
        verdict = '理论最少$fastest天，$userDays天太极限了。除非只做局部、不做拆改、所有工种无缝衔接——现实中基本做不到，建议至少留$slowest天。';
      }
    } else {
      verdict = '纯施工约$fastest-$slowest天（${(fastest / 30).toStringAsFixed(1)}–${(slowest / 30).toStringAsFixed(1)}个月）。加上工种衔接、材料进场、节假日，实际通常要${(slowest * 1.2).round()}–${(slowest * 1.4).round()}天。';
    }

    // 组装文本
    final buf = StringBuffer();
    buf.writeln('我按标准施工流程帮你算了一下：');
    for (final p in phases) {
      buf.writeln('${p['name']}：${p['days']}');
    }
    buf.writeln();
    buf.write(verdict);

    return _Message(
      text: buf.toString().trim(),
      isMe: false,
      type: _MsgType.quickReplies,
      quickReplies: ['帮我排详细工序', '算报价+工期', '先匹配师傅'],
    );
  }

  void _showTransferDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '转接人工客服',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text('检测到您可能需要人工帮助，是否转接平台人工客服？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              '继续AI咨询',
              style: TextStyle(color: ZdColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatPage(workerName: '人工客服')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A2F),
            ),
            child: const Text('转人工'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() {
        _messages.add(
          _Message(imagePath: image.path, isMe: true, type: _MsgType.image),
        );
      });
    }
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo != null) {
      setState(() {
        _messages.add(
          _Message(imagePath: photo.path, isMe: true, type: _MsgType.image),
        );
      });
    }
  }

  void _startVoice() {
    setState(() => _isRecording = true);
  }

  void _stopVoice() {
    setState(() => _isRecording = false);
    // 模拟发送语音消息
    _messages.add(
      _Message(text: '语音消息 (3″)', isMe: true, type: _MsgType.voice),
    );
    setState(() {});
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
              widget.workerName,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 2),
            _StatusRow(isOnline: _isOnline, lastSeen: _lastSeen),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: ZdColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _MessageBubble(
                  message: _messages[index],
                  workerName: widget.workerName,
                  avatarPath: widget.avatarPath,
                  onChipTap: _onChipTap,
                );
              },
            ),
          ),
          _InputBar(
            controller: _controller,
            onSend: _sendMessage,
            isRecording: _isRecording,
            onPickImage: _pickImage,
            onTakePhoto: _takePhoto,
            onStartVoice: _startVoice,
            onStopVoice: _stopVoice,
          ),
        ],
      ),
    );
  }
}

enum _MsgType { text, image, voice, quickReplies, thinking }

class _Message {
  final String? text;
  final String? imagePath;
  final bool isMe;
  final _MsgType type;
  final bool isRead;
  final List<String>? quickReplies;

  _Message({
    this.text,
    this.imagePath,
    required this.isMe,
    this.type = _MsgType.text,
    this.isRead = false,
    this.quickReplies,
  });

  /// 快捷创建思考中消息
  factory _Message.thinking() => _Message(
        text: '正在分析你的需求…',
        isMe: false,
        type: _MsgType.thinking,
      );
}

class _StatusRow extends StatelessWidget {
  final bool isOnline;
  final String lastSeen;
  const _StatusRow({required this.isOnline, required this.lastSeen});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: isOnline ? const Color(0xFF07C160) : const Color(0xFFBBBBBB),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          isOnline ? '在线' : lastSeen,
          style: const TextStyle(
            fontSize: 12,
            color: ZdColors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _Message message;
  final String workerName;
  final String? avatarPath;
  final void Function(String chip)? onChipTap;

  const _MessageBubble({
    required this.message,
    required this.workerName,
    this.avatarPath,
    this.onChipTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final isImage = message.type == _MsgType.image;
    final isVoice = message.type == _MsgType.voice;
    final isQuickReplies = message.type == _MsgType.quickReplies;
    final isThinking = message.type == _MsgType.thinking;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) _Avatar(name: workerName, avatarPath: avatarPath),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (isThinking)
                  _ThinkingIndicator()
                else if (isImage)
                  _ImageBubble(imagePath: message.imagePath!, isMe: isMe)
                else if (isVoice)
                  _VoiceBubble(isMe: isMe, duration: message.text ?? '')
                else if (isQuickReplies) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(18),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text!,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: ZdColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: message.quickReplies!.map((chip) {
                            return GestureDetector(
                              onTap: () => onChipTap?.call(chip),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E8),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: const Color(0xFFFFD8B8)),
                                ),
                                child: Text(
                                  chip,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: ZdColors.primary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF07C160) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isMe
                              ? const Color(0x1807C160)
                              : const Color(0x08000000),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      message.text!,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: isMe ? Colors.white : ZdColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (isMe && message.type == _MsgType.text) ...[
                  const SizedBox(height: 4),
                  Text(
                    message.isRead ? '已读' : '未读',
                    style: TextStyle(
                      fontSize: 11,
                      color: message.isRead
                          ? ZdColors.textSecondary
                          : const Color(0xFFBBBBBB),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe) const _MeAvatar(),
        ],
      ),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  final String imagePath;
  final bool isMe;
  const _ImageBubble({required this.imagePath, required this.isMe});

  @override
  Widget build(BuildContext context) {
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
                  child: Image.file(File(imagePath)),
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
          boxShadow: [
            BoxShadow(
              color: isMe ? const Color(0x1807C160) : const Color(0x08000000),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(File(imagePath), fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  final bool isMe;
  final String duration;
  const _VoiceBubble({required this.isMe, required this.duration});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF07C160) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isMe ? const Color(0x1807C160) : const Color(0x08000000),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe) ...[
            const Icon(
              Icons.play_arrow_rounded,
              size: 20,
              color: Color(0xFF07C160),
            ),
            const SizedBox(width: 6),
          ],
          Icon(
            Icons.multitrack_audio_rounded,
            size: 16,
            color: isMe ? Colors.white70 : ZdColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            duration,
            style: TextStyle(
              fontSize: 13,
              color: isMe ? Colors.white70 : ZdColors.textSecondary,
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.play_arrow_rounded,
              size: 20,
              color: Colors.white70,
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? avatarPath;
  const _Avatar({required this.name, this.avatarPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        image: avatarPath != null
            ? DecorationImage(
                image: avatarPath!.startsWith('assets/')
                    ? AssetImage(avatarPath!) as ImageProvider
                    : FileImage(File(avatarPath!)),
                fit: BoxFit.cover,
              )
            : null,
        color: avatarPath == null ? const Color(0xFFFFEEE3) : null,
      ),
      child: avatarPath == null
          ? const Icon(Icons.person_rounded, size: 25, color: Color(0xFFFF7A2F))
          : null,
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
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isRecording;
  final VoidCallback onPickImage;
  final VoidCallback onTakePhoto;
  final VoidCallback onStartVoice;
  final VoidCallback onStopVoice;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.isRecording,
    required this.onPickImage,
    required this.onTakePhoto,
    required this.onStartVoice,
    required this.onStopVoice,
  });

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
            // 图片按钮
            _ToolButton(
              icon: Icons.image_outlined,
              onTap: onPickImage,
              onLongPress: onTakePhoto,
            ),
            const SizedBox(width: 4),
            // 语音按钮
            GestureDetector(
              onLongPressStart: (_) => onStartVoice(),
              onLongPressEnd: (_) => onStopVoice(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isRecording
                      ? const Color(0xFFFFF0F0)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Icon(
                  isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                  size: 22,
                  color: isRecording ? Colors.red : ZdColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // 输入框
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '请输入咨询内容',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  hintStyle: TextStyle(
                    color: ZdColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ToolButton({
    required this.icon,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: ZdColors.background,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Icon(icon, size: 22, color: ZdColors.textSecondary),
      ),
    );
  }
}

// ================================================================
// 思考中动画 —— 模拟 ChatGPT 风格
// ================================================================
class _ThinkingIndicator extends StatefulWidget {
  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.zero,
          topRight: const Radius.circular(14),
          bottomLeft: const Radius.circular(14),
          bottomRight: const Radius.circular(14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '思考中',
            style: TextStyle(fontSize: 14, color: ZdColors.textSecondary),
          ),
          const SizedBox(width: 4),
          _Dot(ctrl: _ctrl, delay: 0),
          _Dot(ctrl: _ctrl, delay: 200),
          _Dot(ctrl: _ctrl, delay: 400),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final AnimationController ctrl;
  final int delay;
  const _Dot({required this.ctrl, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, _) {
        final t = ((ctrl.value * 1200 + delay) % 1200) / 1200;
        final opacity = t < 0.3 ? t / 0.3 : t < 0.5 ? 1.0 : 1.0 - (t - 0.5) / 0.5;
        return Opacity(
          opacity: opacity.clamp(0.05, 1.0),
          child: Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: const BoxDecoration(
              color: Color(0xFFBBBBBB),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

// ================================================================
// 对话上下文 —— 追踪已收集的所有信息，不重复追问
// ================================================================
class _ConversationContext {
  String? trade;
  String? room;
  String? area;
  String? budget;
  String? material;
  bool isFullRenovation = false;

  // 工期相关
  bool hasTimelineQuestion = false;
  bool timelineAnswered = false;
  int? timelineDays; // 用户问的具体天数
  String timelineRaw = ''; // 原始提问文本，用于判断毛坯等

  static const _tradeMap = {
    '瓦工': ['瓦工', '贴砖', '贴瓷砖', '贴墙砖', '贴地砖', '砌墙', '抹灰', '找平', '美缝'],
    '水电工': ['水电', '水电工', '改水电', '布线', '水管', '电路', '跳闸', '漏水', '排水', '龙头'],
    '油漆工': ['油漆', '油漆工', '刷漆', '刷墙', '刮腻子', '乳胶漆', '涂料'],
    '木工': ['木工', '打柜子', '吊顶', '衣柜', '橱柜', '木作', '定制'],
    '泥工': ['泥工', '泥瓦', '防水'],
    '拆除': ['拆除', '拆墙', '砸墙', '拆旧'],
  };

  static const _roomMap = {
    '厨房': ['厨房', '灶台', '橱柜'],
    '卫生间': ['卫生间', '厕所', '浴室', '洗手间'],
    '客厅': ['客厅'],
    '卧室': ['卧室', '主卧', '次卧', '房间'],
    '阳台': ['阳台'],
  };

  static const _fullRenovationKw = ['全屋', '整套', '毛坯', '新房', '老房', '旧房', '装修一套', '装修房子', '全包装修'];

  void ingest(String text) {
    // 工期检测（最先判断，不依赖其他字段）
    if (!timelineAnswered) {
      final tlDays = RegExp(r'(\d+)\s*(?:天|日|个月)').firstMatch(text);
      final tlAsk = ['能搞定', '来得及', '够不够', '行不行', '能做完', '多久', '多长时间', '几个月', '工期'].any((kw) => text.contains(kw));
      if (tlAsk) {
        hasTimelineQuestion = true;
        timelineRaw = text;
        if (tlDays != null) {
          final n = int.parse(tlDays.group(1)!);
          timelineDays = text.contains('个月') ? n * 30 : n;
        }
      }
    }

    // 工种
    if (trade == null) {
      for (final e in _tradeMap.entries) {
        if (e.value.any((kw) => text.contains(kw))) { trade = e.key; break; }
      }
    }
    // 房间
    if (room == null) {
      for (final e in _roomMap.entries) {
        if (e.value.any((kw) => text.contains(kw))) { room = e.key; break; }
      }
    }
    // 全屋
    if (_fullRenovationKw.any((kw) => text.contains(kw))) {
      isFullRenovation = true;
      room ??= '全屋';
    }
    // 面积
    if (area == null) {
      final m = RegExp(r'(\d+)\s*(?:平|平米|㎡|m2|平方)').firstMatch(text);
      if (m != null) area = '${m.group(1)}平';
    }
    // 材料
    if (material == null) {
      if (['还没买', '没买', '先报人工', '人工费', '还没想好'].any((kw) => text.contains(kw))) {
        material = '人工费';
      } else if (['瓷砖买好', '瓷砖有了', '漆买好', '漆买了', '材料买好', '材料有了', '买好了', '我买好', '自备'].any((kw) => text.contains(kw))) {
        material = '自备';
      } else if (['包料', '需要师傅包', '包工包料', '师傅带'].any((kw) => text.contains(kw))) {
        material = '包料';
      }
    }
    // 预算
    if (budget == null) {
      final bm = RegExp(r'(\d+)\s*(?:万|w|W)').firstMatch(text);
      if (bm != null) budget = '${bm.group(1)}万';
    }
  }
}
