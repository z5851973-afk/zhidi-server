// 聊天相关数据模型
// ignore_for_file: dangling_library_doc_comments

class ChatRoomModel {
  final String id;
  final String bookingId;
  final String ownerUserId;
  final String workerUserId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime createdAt;

  const ChatRoomModel({
    required this.id,
    required this.bookingId,
    required this.ownerUserId,
    required this.workerUserId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.lastMessageText,
    this.lastMessageAt,
    this.unreadCount = 0,
    required this.createdAt,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    return ChatRoomModel(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      ownerUserId: json['ownerUserId'] as String,
      workerUserId: json['workerUserId'] as String,
      otherUserId: (json['otherUserId'] as String?) ??
          (json['workerUserId'] as String),
      otherUserName: (json['otherUserName'] as String?) ?? '',
      otherUserAvatar: json['otherUserAvatar'] as String?,
      lastMessageText: json['lastMessageText'] as String?,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'] as String)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

class ChatMessageModel {
  final String id;
  final String roomId;
  final String senderUserId;
  final String senderRole; // OWNER / WORKER
  final String type; // TEXT / IMAGE / SYSTEM
  final String content;
  final String? imageUrl;
  final DateTime? readAt;
  final DateTime createdAt;
  final bool isMe;

  const ChatMessageModel({
    required this.id,
    required this.roomId,
    required this.senderUserId,
    required this.senderRole,
    required this.type,
    required this.content,
    this.imageUrl,
    this.readAt,
    required this.createdAt,
    this.isMe = false,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final senderUserId = json['senderUserId'] as String;
    return ChatMessageModel(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      senderUserId: senderUserId,
      senderRole: json['senderRole'] as String? ?? 'OWNER',
      type: json['type'] as String? ?? 'TEXT',
      content: json['content'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      isMe: currentUserId != null && senderUserId == currentUserId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'senderUserId': senderUserId,
        'senderRole': senderRole,
        'type': type,
        'content': content,
        'imageUrl': imageUrl,
        'readAt': readAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'isMe': isMe,
      };

  ChatMessageModel copyWithIsMe(String currentUserId) {
    return ChatMessageModel(
      id: id,
      roomId: roomId,
      senderUserId: senderUserId,
      senderRole: senderRole,
      type: type,
      content: content,
      imageUrl: imageUrl,
      readAt: readAt,
      createdAt: createdAt,
      isMe: senderUserId == currentUserId,
    );
  }
}

/// WebSocket 推送的订单状态变更消息
class BookingStatusPush {
  final String bookingId;
  final String status;
  final DateTime timestamp;

  const BookingStatusPush({
    required this.bookingId,
    required this.status,
    required this.timestamp,
  });

  factory BookingStatusPush.fromJson(Map<String, dynamic> json) {
    return BookingStatusPush(
      bookingId: json['bookingId'] as String,
      status: json['status'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}
