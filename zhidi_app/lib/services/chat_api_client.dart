import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import '../models/chat_models.dart';
import 'auth_api_client.dart';

abstract interface class ChatApi {
  Future<ChatRoomModel> getOrCreateRoom(String accessToken, String bookingId);

  Future<List<ChatRoomModel>> getRooms(String accessToken);

  Future<List<ChatMessageModel>> getMessages(
    String accessToken,
    String roomId, {
    int page = 0,
    int size = 30,
  });

  Future<void> markRoomRead(String accessToken, String roomId);

  Future<ChatMessageModel> sendMessage(
    String accessToken,
    String roomId, {
    required String content,
    String type = 'TEXT',
    String? imageUrl,
  });
}

final class ChatApiClient implements ChatApi {
  ChatApiClient({
    Uri? baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 15),
  }) : baseUrl = baseUrl ?? Uri.parse(AuthApiClient.configuredBaseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;

  @override
  Future<ChatRoomModel> getOrCreateRoom(
    String accessToken,
    String bookingId,
  ) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/api/v1/chat/rooms/by-booking/$bookingId'),
          headers: _headers(accessToken),
        )
        .timeout(requestTimeout);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ChatRoomModel.fromJson(body['data'] as Map<String, dynamic>);
    }

    throw _chatApiException(response, fallbackCode: 'CHAT_ROOM_FAILED', fallbackMessage: '创建聊天室失败');
  }

  @override
  Future<List<ChatRoomModel>> getRooms(String accessToken) async {
    final response = await _httpClient
        .get(
          Uri.parse('$baseUrl/api/v1/chat/rooms'),
          headers: _headers(accessToken),
        )
        .timeout(requestTimeout);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>?;
      if (data == null) return [];
      return data
          .map((e) => ChatRoomModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw _chatApiException(response, fallbackCode: 'CHAT_ROOMS_FAILED', fallbackMessage: '获取聊天室列表失败');
  }

  @override
  Future<List<ChatMessageModel>> getMessages(
    String accessToken,
    String roomId, {
    int page = 0,
    int size = 30,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/chat/rooms/$roomId/messages?page=$page&size=$size',
    );
    final response = await _httpClient
        .get(uri, headers: _headers(accessToken))
        .timeout(requestTimeout);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>?;
      if (data == null) return [];
      return data
          .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
          .toList()
          .reversed
          .toList();
    }

    throw _chatApiException(response, fallbackCode: 'CHAT_MESSAGES_FAILED', fallbackMessage: '获取聊天记录失败');
  }

  @override
  Future<void> markRoomRead(String accessToken, String roomId) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/api/v1/chat/rooms/$roomId/read'),
          headers: _headers(accessToken),
        )
        .timeout(requestTimeout);

    if (response.statusCode == 200 || response.statusCode == 204) return;

    throw _chatApiException(
      response,
      fallbackCode: 'CHAT_MARK_READ_FAILED',
      fallbackMessage: '标记已读失败',
    );
  }

  @override
  Future<ChatMessageModel> sendMessage(
    String accessToken,
    String roomId, {
    required String content,
    String type = 'TEXT',
    String? imageUrl,
  }) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/api/v1/chat/rooms/$roomId/messages'),
          headers: _headers(accessToken),
          body: jsonEncode({
            'content': content,
            'type': type,
            'imageUrl': ?imageUrl,
          }),
        )
        .timeout(requestTimeout);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ChatMessageModel.fromJson(body['data'] as Map<String, dynamic>);
    }

    throw _chatApiException(response, fallbackCode: 'CHAT_SEND_FAILED', fallbackMessage: '发送消息失败');
  }

  Map<String, String> _headers(String accessToken) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $accessToken',
  };
}

AuthApiException _chatApiException(
  http.Response response, {
  required String fallbackCode,
  required String fallbackMessage,
}) {
  try {
    final body = jsonDecode(response.body);
    if (body is Map<String, dynamic>) {
      final code = body['code'];
      final message = body['message'];
      return AuthApiException(
        code: code is String && code.isNotEmpty ? code : fallbackCode,
        message: message is String && message.isNotEmpty
            ? message
            : fallbackMessage,
        statusCode: response.statusCode,
      );
    }
  } catch (_) {
    // Fall through to fallback.
  }
  return AuthApiException(
    code: response.statusCode == 401 ? 'UNAUTHORIZED' : fallbackCode,
    message: response.statusCode == 401 ? '登录已过期，请重新登录' : fallbackMessage,
    statusCode: response.statusCode,
  );
}
