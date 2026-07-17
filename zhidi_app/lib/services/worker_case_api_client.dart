import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'auth_api_client.dart';

final class WorkerCaseDraft {
  const WorkerCaseDraft({
    required this.title,
    required this.description,
    required this.serviceCity,
    required this.completionYear,
    required this.imageUrls,
  });

  final String title;
  final String description;
  final String serviceCity;
  final int completionYear;
  final List<String> imageUrls;

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'serviceCity': serviceCity,
    'completionYear': completionYear,
    'imageUrls': imageUrls,
  };
}

final class RemoteWorkerCase {
  const RemoteWorkerCase({
    required this.id,
    required this.workerUserId,
    required this.title,
    required this.description,
    required this.serviceCity,
    required this.completionYear,
    required this.imageUrls,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RemoteWorkerCase.fromJson(Map<String, dynamic> json) {
    final rawImages = json['imageUrls'];
    if (rawImages is! List || rawImages.any((value) => value is! String)) {
      throw const FormatException('imageUrls must be a string list');
    }
    return RemoteWorkerCase(
      id: _requiredString(json, 'id'),
      workerUserId: _requiredString(json, 'workerUserId'),
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      serviceCity: _requiredString(json, 'serviceCity'),
      completionYear: _requiredInt(json, 'completionYear'),
      imageUrls: List<String>.unmodifiable(rawImages),
      createdAt: DateTime.parse(_requiredString(json, 'createdAt')).toUtc(),
      updatedAt: DateTime.parse(_requiredString(json, 'updatedAt')).toUtc(),
    );
  }

  final String id;
  final String workerUserId;
  final String title;
  final String description;
  final String serviceCity;
  final int completionYear;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkerCaseDraft toDraft() => WorkerCaseDraft(
    title: title,
    description: description,
    serviceCity: serviceCity,
    completionYear: completionYear,
    imageUrls: imageUrls,
  );
}

abstract interface class WorkerCaseApi {
  Future<List<RemoteWorkerCase>> listPublicCases(String workerUserId);
  Future<List<RemoteWorkerCase>> listMyCases(String accessToken);
  Future<RemoteWorkerCase> createCase(
    String accessToken,
    WorkerCaseDraft draft,
  );
  Future<RemoteWorkerCase> updateCase(
    String accessToken,
    String caseId,
    WorkerCaseDraft draft,
  );
  Future<void> deleteCase(String accessToken, String caseId);
  Future<String> uploadImage(
    String accessToken, {
    required String filename,
    required List<int> bytes,
  });
}

final class WorkerCaseApiClient implements WorkerCaseApi {
  WorkerCaseApiClient({
    Uri? baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 15),
  }) : baseUrl = baseUrl ?? Uri.parse(AuthApiClient.configuredBaseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;

  @override
  Future<List<RemoteWorkerCase>> listPublicCases(String workerUserId) async {
    final request = http.Request(
      'GET',
      baseUrl.resolve(
        '/api/v1/workers/${Uri.encodeComponent(workerUserId)}/cases',
      ),
    )..headers['accept'] = 'application/json';
    return _parseList(await _send(request));
  }

  @override
  Future<List<RemoteWorkerCase>> listMyCases(String accessToken) async {
    final request = _authorized('GET', '/api/v1/workers/me/cases', accessToken);
    return _parseList(await _send(request));
  }

  @override
  Future<RemoteWorkerCase> createCase(
    String accessToken,
    WorkerCaseDraft draft,
  ) async {
    final request = _jsonRequest(
      'POST',
      '/api/v1/workers/me/cases',
      accessToken,
      draft,
    );
    return _parseCase(await _send(request));
  }

  @override
  Future<RemoteWorkerCase> updateCase(
    String accessToken,
    String caseId,
    WorkerCaseDraft draft,
  ) async {
    final request = _jsonRequest(
      'PUT',
      '/api/v1/workers/me/cases/${Uri.encodeComponent(caseId)}',
      accessToken,
      draft,
    );
    return _parseCase(await _send(request));
  }

  @override
  Future<void> deleteCase(String accessToken, String caseId) async {
    final request = _authorized(
      'DELETE',
      '/api/v1/workers/me/cases/${Uri.encodeComponent(caseId)}',
      accessToken,
    );
    final response = await _send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _parseEnvelope(response);
    }
  }

  @override
  Future<String> uploadImage(
    String accessToken, {
    required String filename,
    required List<int> bytes,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            baseUrl.resolve('/api/v1/workers/me/case-images'),
          )
          ..headers.addAll({
            'accept': 'application/json',
            'authorization': 'Bearer $accessToken',
          })
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: filename,
              contentType: _mediaType(filename),
            ),
          );
    final response = await _send(request);
    final envelope = _parseEnvelope(response);
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw _invalidResponse(response);
    }
    return _requiredString(data, 'url');
  }

  http.Request _authorized(String method, String path, String accessToken) {
    return http.Request(method, baseUrl.resolve(path))
      ..headers.addAll({
        'accept': 'application/json',
        'authorization': 'Bearer $accessToken',
      });
  }

  http.Request _jsonRequest(
    String method,
    String path,
    String accessToken,
    WorkerCaseDraft draft,
  ) {
    return _authorized(method, path, accessToken)
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(draft.toJson());
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

MediaType _mediaType(String filename) {
  final value = filename.toLowerCase();
  if (value.endsWith('.png')) return MediaType('image', 'png');
  if (value.endsWith('.webp')) return MediaType('image', 'webp');
  return MediaType('image', 'jpeg');
}

List<RemoteWorkerCase> _parseList(http.Response response) {
  final data = _parseEnvelope(response)['data'];
  if (data is! List) throw _invalidResponse(response);
  try {
    return List<RemoteWorkerCase>.unmodifiable(
      data.map(
        (value) =>
            RemoteWorkerCase.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
  } on FormatException {
    throw _invalidResponse(response);
  } on TypeError {
    throw _invalidResponse(response);
  }
}

RemoteWorkerCase _parseCase(http.Response response) {
  final data = _parseEnvelope(response)['data'];
  if (data is! Map<String, dynamic>) throw _invalidResponse(response);
  try {
    return RemoteWorkerCase.fromJson(data);
  } on FormatException {
    throw _invalidResponse(response);
  } on TypeError {
    throw _invalidResponse(response);
  }
}

Map<String, dynamic> _parseEnvelope(http.Response response) {
  late final Map<String, dynamic> envelope;
  try {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) throw const FormatException();
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

AuthApiException _invalidResponse(http.Response response) => AuthApiException(
  code: 'INVALID_RESPONSE',
  message: '服务器响应格式异常',
  statusCode: response.statusCode,
);

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer');
  return value;
}
