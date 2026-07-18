import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../models/chat_models.dart';

/// STOMP over WebSocket 聊天服务
/// 管理连接生命周期，暴露实时消息流
class ChatWebSocketService {
  ChatWebSocketService({Uri? wsUrl}) : _wsUrl = wsUrl; // ignore: prefer_initializing_formals

  StompClient? _client;
  final Uri? _wsUrl;
  String? _currentUserId;

  final _messageController = StreamController<ChatMessageModel>.broadcast();
  final _statusController = StreamController<BookingStatusPush>.broadcast();
  final _connectionController = StreamController<WebSocketConnectionState>.broadcast();

  Stream<ChatMessageModel> get onMessage => _messageController.stream;
  Stream<BookingStatusPush> get onStatusPush => _statusController.stream;
  Stream<WebSocketConnectionState> get onConnectionState => _connectionController.stream;

  bool get isConnected => _client?.connected ?? false;

  /// 连接 WebSocket
  Future<void> connect({
    required String accessToken,
    required String currentUserId,
  }) async {
    _currentUserId = currentUserId;

    final base = _wsUrl ?? Uri.parse('ws://47.109.0.191:8080');
    final wsUri = base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws');

    _client = StompClient(
      config: StompConfig(
        url: '$wsUri/ws',
        onConnect: _onConnect,
        onWebSocketError: (dynamic error) {
          _connectionController.add(WebSocketConnectionState.error);
        },
        onDisconnect: (_) {
          _connectionController.add(WebSocketConnectionState.disconnected);
        },
        stompConnectHeaders: {
          'Authorization': 'Bearer $accessToken',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $accessToken',
        },
      ),
    );

    _client!.activate();
  }

  void _onConnect(StompFrame frame) {
    _connectionController.add(WebSocketConnectionState.connected);

    // 订阅个人聊天消息
    _client!.subscribe(
      destination: '/user/queue/chat',
      callback: (StompFrame frame) {
        if (frame.body != null) {
          try {
            final json = jsonDecode(frame.body!) as Map<String, dynamic>;
            final msg = ChatMessageModel.fromJson(
              json,
              currentUserId: _currentUserId,
            );
            _messageController.add(msg);
          } catch (_) {
            // 忽略解析错误
          }
        }
      },
    );
  }

  /// 订阅订单状态变更
  void subscribeBooking(String bookingId) {
    if (_client == null || !_client!.connected) return;
    _client!.subscribe(
      destination: '/topic/booking/$bookingId',
      callback: (StompFrame frame) {
        if (frame.body != null) {
          try {
            final json = jsonDecode(frame.body!) as Map<String, dynamic>;
            final push = BookingStatusPush.fromJson(json);
            _statusController.add(push);
          } catch (_) {
            // 忽略解析错误
          }
        }
      },
    );
  }

  /// 发送消息到指定聊天室
  void sendMessage(String roomId, Map<String, dynamic> body) {
    if (_client == null || !_client!.connected) return;
    _client!.send(
      destination: '/app/chat/$roomId',
      body: jsonEncode(body),
    );
  }

  /// 断开连接
  Future<void> disconnect() async {
    _client?.deactivate();
    _client = null;
    _connectionController.add(WebSocketConnectionState.disconnected);
  }

  /// 释放资源
  void dispose() {
    _client?.deactivate();
    _messageController.close();
    _statusController.close();
    _connectionController.close();
  }
}

enum WebSocketConnectionState {
  connected,
  disconnected,
  error,
}
