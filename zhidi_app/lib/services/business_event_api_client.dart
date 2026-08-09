import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_api_client.dart';

abstract interface class BusinessEventApi {
  Future<BusinessEventPage> list(
    String accessToken, {
    required int after,
    int size = 100,
  });

  Future<RemoteBusinessEvent> markRead(String accessToken, String eventId);
}

final class RemoteBusinessEvent {
  const RemoteBusinessEvent({
    required this.eventId,
    required this.sequenceNo,
    required this.actorUserId,
    required this.eventType,
    required this.aggregateType,
    required this.aggregateId,
    required this.bookingId,
    required this.serviceRequestId,
    required this.payload,
    required this.occurredAt,
    required this.readAt,
  });

  factory RemoteBusinessEvent.fromJson(Map<String, dynamic> json) {
    return RemoteBusinessEvent(
      eventId: _requiredString(json, 'eventId'),
      sequenceNo: _requiredInt(json, 'sequenceNo'),
      actorUserId: _optionalString(json, 'actorUserId'),
      eventType: _requiredString(json, 'eventType'),
      aggregateType: _requiredString(json, 'aggregateType'),
      aggregateId: _requiredString(json, 'aggregateId'),
      bookingId: _requiredString(json, 'bookingId'),
      serviceRequestId: _requiredString(json, 'serviceRequestId'),
      payload: _optionalMap(json, 'payload'),
      occurredAt: _requiredDateTime(json, 'occurredAt'),
      readAt: _optionalDateTime(json, 'readAt'),
    );
  }

  final String eventId;
  final int sequenceNo;
  final String? actorUserId;
  final String eventType;
  final String aggregateType;
  final String aggregateId;
  final String bookingId;
  final String serviceRequestId;
  final Map<String, dynamic>? payload;
  final DateTime occurredAt;
  final DateTime? readAt;
}

final class BusinessEventPage {
  const BusinessEventPage({required this.items, required this.nextCursor});

  final List<RemoteBusinessEvent> items;
  final int nextCursor;
}

final class BusinessEventApiClient implements BusinessEventApi {
  BusinessEventApiClient({
    Uri? baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 10),
  }) : baseUrl = baseUrl ?? Uri.parse(AuthApiClient.configuredBaseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;

  @override
  Future<BusinessEventPage> list(
    String accessToken, {
    required int after,
    int size = 100,
  }) async {
    if (size < 1 || size > 100) {
      throw ArgumentError.value(size, 'size', 'must be between 1 and 100');
    }
    final uri = baseUrl
        .resolve('/api/v1/notifications')
        .replace(queryParameters: {'after': '$after', 'size': '$size'});
    final response = await _send(_authorized('GET', uri, accessToken));
    final page = _parsePage(response);
    _validatePage(page, after: after, response: response);
    return page;
  }

  @override
  Future<RemoteBusinessEvent> markRead(
    String accessToken,
    String eventId,
  ) async {
    final uri = baseUrl.resolve(
      '/api/v1/notifications/${Uri.encodeComponent(eventId)}/read',
    );
    final response = await _send(_authorized('PUT', uri, accessToken));
    return _parseEvent(response);
  }

  http.Request _authorized(String method, Uri uri, String accessToken) {
    return http.Request(method, uri)
      ..headers.addAll({
        'accept': 'application/json',
        'authorization': 'Bearer $accessToken',
      });
  }

  Future<http.Response> _send(http.BaseRequest request) async {
    try {
      final streamed = await _httpClient.send(request).timeout(requestTimeout);
      return http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const AuthApiException(
        code: 'NETWORK_TIMEOUT',
        message: '请求超时，请稍后重试',
      );
    } on SocketException {
      throw const AuthApiException(
        code: 'NETWORK_UNAVAILABLE',
        message: '无法连接服务器，请检查网络',
      );
    } on http.ClientException {
      throw const AuthApiException(
        code: 'NETWORK_UNAVAILABLE',
        message: '无法连接服务器，请检查网络',
      );
    }
  }
}

Map<String, dynamic> _parseEnvelope(http.Response response) {
  final Map<String, dynamic> envelope;
  try {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('response must be a JSON object');
    }
    envelope = decoded;
  } on FormatException {
    throw _invalidResponse(response);
  }

  final code = envelope['code'];
  if (code != 'OK' || response.statusCode < 200 || response.statusCode >= 300) {
    throw AuthApiException(
      code: code is String ? code : 'REQUEST_FAILED',
      message: envelope['message'] is String
          ? envelope['message'] as String
          : '请求失败',
      statusCode: response.statusCode,
    );
  }
  return envelope;
}

BusinessEventPage _parsePage(http.Response response) {
  final data = _parseEnvelope(response)['data'];
  if (data is! Map<String, dynamic>) throw _invalidResponse(response);
  final rawItems = data['items'];
  final nextCursor = data['nextCursor'];
  if (rawItems is! List || nextCursor is! int) {
    throw _invalidResponse(response);
  }
  try {
    final items = rawItems
        .map(
          (value) => RemoteBusinessEvent.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(growable: false);
    return BusinessEventPage(
      items: List<RemoteBusinessEvent>.unmodifiable(items),
      nextCursor: nextCursor,
    );
  } on FormatException {
    throw _invalidResponse(response);
  } on TypeError {
    throw _invalidResponse(response);
  }
}

RemoteBusinessEvent _parseEvent(http.Response response) {
  final data = _parseEnvelope(response)['data'];
  if (data is! Map<String, dynamic>) throw _invalidResponse(response);
  try {
    return RemoteBusinessEvent.fromJson(data);
  } on FormatException {
    throw _invalidResponse(response);
  } on TypeError {
    throw _invalidResponse(response);
  }
}

void _validatePage(
  BusinessEventPage page, {
  required int after,
  required http.Response response,
}) {
  var previous = after;
  for (final event in page.items) {
    if (event.sequenceNo <= previous) throw _invalidResponse(response);
    previous = event.sequenceNo;
  }
  final expectedCursor = page.items.isEmpty ? after : previous;
  if (page.nextCursor != expectedCursor) throw _invalidResponse(response);
}

AuthApiException _invalidResponse(http.Response response) => AuthApiException(
  code: 'INVALID_RESPONSE',
  message: '服务器响应格式异常',
  statusCode: response.statusCode,
);

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be null or a non-empty string');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer');
  return value;
}

Map<String, dynamic>? _optionalMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! Map) throw FormatException('$key must be null or an object');
  try {
    return Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(value));
  } on TypeError {
    throw FormatException('$key must contain string keys');
  }
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  try {
    return DateTime.parse(value).toUtc();
  } on FormatException {
    throw FormatException('$key must be an ISO-8601 date');
  }
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  if (json[key] == null) return null;
  return _requiredDateTime(json, key);
}
