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

  Future<ChatMessageModel> sendMessage(
    String accessToken,
    String roomId, {
    required String content,
    String type = 'TEXT',
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

    throw AuthApiException(
      code: 'CHAT_ROOM_FAILED',
      message: '创建聊天室失败',
      statusCode: response.statusCode,
    );
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

    throw AuthApiException(
      code: 'CHAT_ROOMS_FAILED',
      message: '获取聊天室列表失败',
      statusCode: response.statusCode,
    );
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
      final data = body['data'] as Map<String, dynamic>?;
      final content = data?['content'] as List<dynamic>?;
      if (content == null) return [];
      return content
          .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw AuthApiException(
      code: 'CHAT_MESSAGES_FAILED',
      message: '获取聊天记录失败',
      statusCode: response.statusCode,
    );
  }

  @override
  Future<ChatMessageModel> sendMessage(
    String accessToken,
    String roomId, {
    required String content,
    String type = 'TEXT',
  }) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/api/v1/chat/rooms/$roomId/messages'),
          headers: _headers(accessToken),
          body: jsonEncode({
            'content': content,
            'type': type,
          }),
        )
        .timeout(requestTimeout);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ChatMessageModel.fromJson(body['data'] as Map<String, dynamic>);
    }

    throw AuthApiException(
      code: 'CHAT_SEND_FAILED',
      message: '发送消息失败',
      statusCode: response.statusCode,
    );
  }

  Map<String, String> _headers(String accessToken) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
}
