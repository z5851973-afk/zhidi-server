import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_api_client.dart';

abstract interface class WorkerDirectoryApi {
  Future<List<RemoteWorkerDirectoryProfile>> listWorkers();

  Future<RemoteWorkerDirectoryProfile> getWorker(String userId);
}

final class WorkerDirectoryApiClient implements WorkerDirectoryApi {
  WorkerDirectoryApiClient({
    Uri? baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 10),
  }) : baseUrl = baseUrl ?? Uri.parse(AuthApiClient.configuredBaseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;

  @override
  Future<List<RemoteWorkerDirectoryProfile>> listWorkers() async {
    final response = await _get('/api/v1/workers');
    return _parseList(response);
  }

  @override
  Future<RemoteWorkerDirectoryProfile> getWorker(String userId) async {
    final response = await _get(
      '/api/v1/workers/${Uri.encodeComponent(userId)}',
    );
    return _parseProfile(response);
  }

  Future<http.Response> _get(String path) async {
    final request = http.Request('GET', baseUrl.resolve(path))
      ..headers.addAll({'accept': 'application/json'});

    try {
      return await (() async {
        final streamedResponse = await _httpClient.send(request);
        return http.Response.fromStream(streamedResponse);
      })().timeout(requestTimeout);
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

final class RemoteWorkerDirectoryProfile {
  const RemoteWorkerDirectoryProfile({
    required this.userId,
    required this.name,
    required this.serviceCity,
    required this.primaryTrade,
    required this.experienceYears,
    required this.dailyRate,
    required this.bio,
  });

  factory RemoteWorkerDirectoryProfile.fromJson(Map<String, dynamic> json) {
    return RemoteWorkerDirectoryProfile(
      userId: _requiredString(json, 'userId'),
      name: _requiredString(json, 'name'),
      serviceCity: _nullableString(json, 'serviceCity'),
      primaryTrade: _requiredString(json, 'primaryTrade'),
      experienceYears: _requiredInt(json, 'experienceYears'),
      dailyRate: _requiredDouble(json, 'dailyRate'),
      bio: _nullableString(json, 'bio'),
    );
  }

  final String userId;
  final String name;
  final String? serviceCity;
  final String primaryTrade;
  final int experienceYears;
  final double dailyRate;
  final String? bio;
}

List<RemoteWorkerDirectoryProfile> _parseList(http.Response response) {
  final envelope = _parseEnvelope(response);
  final data = envelope['data'];
  if (data is! List) {
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应缺少数据',
      statusCode: response.statusCode,
    );
  }
  try {
    return List.unmodifiable(
      data.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('worker item must be a JSON object');
        }
        return RemoteWorkerDirectoryProfile.fromJson(item);
      }),
    );
  } on FormatException {
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应格式异常',
      statusCode: response.statusCode,
    );
  } on TypeError {
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应格式异常',
      statusCode: response.statusCode,
    );
  }
}

RemoteWorkerDirectoryProfile _parseProfile(http.Response response) {
  final envelope = _parseEnvelope(response);
  final data = envelope['data'];
  if (data is! Map<String, dynamic>) {
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应缺少数据',
      statusCode: response.statusCode,
    );
  }
  try {
    return RemoteWorkerDirectoryProfile.fromJson(data);
  } on FormatException {
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应格式异常',
      statusCode: response.statusCode,
    );
  } on TypeError {
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应格式异常',
      statusCode: response.statusCode,
    );
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
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应格式异常',
      statusCode: response.statusCode,
    );
  }

  final apiCode = envelope['code'];
  final apiMessage = envelope['message'];
  if (apiCode != 'OK' ||
      response.statusCode < 200 ||
      response.statusCode >= 300) {
    throw AuthApiException(
      code: apiCode is String ? apiCode : 'REQUEST_FAILED',
      message: apiMessage is String ? apiMessage : '请求失败',
      statusCode: response.statusCode,
    );
  }
  return envelope;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

String? _nullableString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('$key is required');
  }
  final value = json[key];
  if (value != null && value is! String) {
    throw FormatException('$key must be a string or null');
  }
  return value as String?;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key must be an integer');
  }
  return value;
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw FormatException('$key must be a number');
  }
  return value.toDouble();
}
