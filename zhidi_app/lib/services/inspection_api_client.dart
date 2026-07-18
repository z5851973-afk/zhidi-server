import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api_client.dart';

final class RemoteInspectionNode {
  const RemoteInspectionNode({
    required this.id,
    required this.bookingId,
    required this.name,
    this.description,
    required this.status,
    required this.sortOrder,
    required this.createdAt,
    this.updatedAt,
  });

  factory RemoteInspectionNode.fromJson(Map<String, dynamic> json) {
    return RemoteInspectionNode(
      id: _requiredString(json, 'id'),
      bookingId: _requiredString(json, 'bookingId'),
      name: _requiredString(json, 'name'),
      description: json['description'] as String?,
      status: _requiredString(json, 'status'),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(_requiredString(json, 'createdAt')).toUtc(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String).toUtc() : null,
    );
  }

  final String id;
  final String bookingId;
  final String name;
  final String? description;
  final String status;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == 'PENDING';
  bool get isInspecting => status == 'INSPECTING';
  bool get isPassed => status == 'PASSED';
  bool get isFailed => status == 'FAILED';
}

final class RemoteInspectionRecord {
  const RemoteInspectionRecord({
    required this.id,
    required this.nodeId,
    required this.inspectorUserId,
    required this.result,
    this.comment,
    required this.photos,
    required this.version,
    required this.createdAt,
  });

  factory RemoteInspectionRecord.fromJson(Map<String, dynamic> json) {
    return RemoteInspectionRecord(
      id: _requiredString(json, 'id'),
      nodeId: _requiredString(json, 'nodeId'),
      inspectorUserId: _requiredString(json, 'inspectorUserId'),
      result: _requiredString(json, 'result'),
      comment: json['comment'] as String?,
      photos: (json['photos'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.parse(_requiredString(json, 'createdAt')).toUtc(),
    );
  }

  final String id;
  final String nodeId;
  final String inspectorUserId;
  final String result;
  final String? comment;
  final List<String> photos;
  final int version;
  final DateTime createdAt;

  bool get isPassed => result == 'PASS';
  bool get isFailed => result == 'FAIL';
}

abstract interface class InspectionApi {
  Future<List<RemoteInspectionNode>> createNodes(String accessToken, String bookingId, List<Map<String, dynamic>> nodes);
  Future<List<RemoteInspectionNode>> getNodes(String accessToken, String bookingId);
  Future<RemoteInspectionNode> requestInspection(String accessToken, String nodeId);
  Future<RemoteInspectionRecord> inspect(String accessToken, String nodeId, String result, String? comment, List<String> photos);
  Future<List<RemoteInspectionRecord>> getRecords(String accessToken, String nodeId);
}

final class InspectionApiClient implements InspectionApi {
  InspectionApiClient({
    Uri? baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 10),
  }) : baseUrl = baseUrl ?? Uri.parse(AuthApiClient.configuredBaseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;

  @override
  Future<List<RemoteInspectionNode>> createNodes(String accessToken, String bookingId, List<Map<String, dynamic>> nodes) async {
    final response = await _post('/api/v1/bookings/$bookingId/inspection-nodes', accessToken, jsonEncode(nodes));
    return _parseNodeList(response);
  }

  @override
  Future<List<RemoteInspectionNode>> getNodes(String accessToken, String bookingId) async {
    final response = await _get('/api/v1/bookings/$bookingId/inspection-nodes', accessToken);
    return _parseNodeList(response);
  }

  @override
  Future<RemoteInspectionNode> requestInspection(String accessToken, String nodeId) async {
    final response = await _put('/api/v1/inspection-nodes/$nodeId/request-inspection', accessToken);
    return _parseNode(response);
  }

  @override
  Future<RemoteInspectionRecord> inspect(String accessToken, String nodeId, String result, String? comment, List<String> photos) async {
    final response = await _post('/api/v1/inspection-nodes/$nodeId/inspect', accessToken, jsonEncode({
      'result': result,
      // ignore: use_null_aware_elements
      if (comment != null) 'comment': comment,
      'photos': photos,
    }));
    return _parseRecord(response);
  }

  @override
  Future<List<RemoteInspectionRecord>> getRecords(String accessToken, String nodeId) async {
    final response = await _get('/api/v1/inspection-nodes/$nodeId/records', accessToken);
    return _parseRecordList(response);
  }

  Future<http.Response> _post(String path, String accessToken, String body) async {
    final uri = baseUrl.replace(path: path);
    try {
      return await _httpClient.post(uri, headers: _headers(accessToken), body: body).timeout(requestTimeout);
    } on TimeoutException {
      throw AuthApiException(code: 'TIMEOUT', message: '请求超时');
    }
  }

  Future<http.Response> _put(String path, String accessToken) async {
    final uri = baseUrl.replace(path: path);
    try {
      return await _httpClient.put(uri, headers: _headers(accessToken)).timeout(requestTimeout);
    } on TimeoutException {
      throw AuthApiException(code: 'TIMEOUT', message: '请求超时');
    }
  }

  Future<http.Response> _get(String path, String accessToken) async {
    final uri = baseUrl.replace(path: path);
    try {
      return await _httpClient.get(uri, headers: _headers(accessToken)).timeout(requestTimeout);
    } on TimeoutException {
      throw AuthApiException(code: 'TIMEOUT', message: '请求超时');
    }
  }

  Map<String, String> _headers(String accessToken) => {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };
}

RemoteInspectionNode _parseNode(http.Response response) {
  final envelope = _parseEnvelope(response);
  final data = envelope['data'];
  if (data is! Map<String, dynamic>) throw AuthApiException(code: 'INVALID_RESPONSE', message: '服务器响应缺少数据', statusCode: response.statusCode);
  return RemoteInspectionNode.fromJson(data);
}

List<RemoteInspectionNode> _parseNodeList(http.Response response) {
  final envelope = _parseEnvelope(response);
  final data = envelope['data'];
  if (data is! List<dynamic>) throw AuthApiException(code: 'INVALID_RESPONSE', message: '服务器响应缺少数据列表', statusCode: response.statusCode);
  return data.map((e) => RemoteInspectionNode.fromJson(e as Map<String, dynamic>)).toList();
}

RemoteInspectionRecord _parseRecord(http.Response response) {
  final envelope = _parseEnvelope(response);
  final data = envelope['data'];
  if (data is! Map<String, dynamic>) throw AuthApiException(code: 'INVALID_RESPONSE', message: '服务器响应缺少数据', statusCode: response.statusCode);
  return RemoteInspectionRecord.fromJson(data);
}

List<RemoteInspectionRecord> _parseRecordList(http.Response response) {
  final envelope = _parseEnvelope(response);
  final data = envelope['data'];
  if (data is! List<dynamic>) throw AuthApiException(code: 'INVALID_RESPONSE', message: '服务器响应缺少数据列表', statusCode: response.statusCode);
  return data.map((e) => RemoteInspectionRecord.fromJson(e as Map<String, dynamic>)).toList();
}

Map<String, dynamic> _parseEnvelope(http.Response response) {
  final Map<String, dynamic> envelope;
  try {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) throw const FormatException('response must be a JSON object');
    envelope = decoded;
  } on FormatException {
    throw AuthApiException(code: 'INVALID_RESPONSE', message: '服务器响应格式异常', statusCode: response.statusCode);
  }
  final apiCode = envelope['code'];
  final apiMessage = envelope['message'];
  if (apiCode != 'OK' || response.statusCode < 200 || response.statusCode >= 300) {
    throw AuthApiException(code: apiCode is String ? apiCode : 'REQUEST_FAILED', message: apiMessage is String ? apiMessage : '请求失败', statusCode: response.statusCode);
  }
  return envelope;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) throw FormatException('$key must be a non-empty string');
  return value;
}
