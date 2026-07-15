import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api_client.dart';

abstract interface class OwnerProfileApi {
  Future<RemoteOwnerProfile> getCurrent(String accessToken);

  Future<RemoteOwnerProfile> updateCurrent(
    String accessToken,
    OwnerProfileUpdate request,
  );
}

final class OwnerProfileApiClient implements OwnerProfileApi {
  OwnerProfileApiClient({
    Uri? baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 10),
  }) : baseUrl = baseUrl ?? Uri.parse(AuthApiClient.configuredBaseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;

  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) async {
    final response = await _send('GET', accessToken);
    return _parseProfile(response);
  }

  @override
  Future<RemoteOwnerProfile> updateCurrent(
    String accessToken,
    OwnerProfileUpdate request,
  ) async {
    final response = await _send(
      'PUT',
      accessToken,
      body: jsonEncode(request.toJson()),
    );
    return _parseProfile(response);
  }

  Future<http.Response> _send(
    String method,
    String accessToken, {
    String? body,
  }) async {
    final request = http.Request(method, baseUrl.resolve('/api/v1/owners/me'))
      ..headers.addAll({
        'accept': 'application/json',
        'authorization': 'Bearer $accessToken',
        if (body != null) 'content-type': 'application/json',
      });
    if (body != null) {
      request.body = body;
    }

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
    } catch (_) {
      throw const AuthApiException(
        code: 'NETWORK_UNAVAILABLE',
        message: '无法连接服务器，请检查网络',
      );
    }
  }
}

final class RemoteOwnerProfile {
  const RemoteOwnerProfile({
    required this.userId,
    required this.phone,
    required this.name,
    required this.city,
    required this.decorationType,
    required this.address,
    required this.area,
    required this.profileComplete,
  });

  factory RemoteOwnerProfile.fromJson(Map<String, dynamic> json) {
    return RemoteOwnerProfile(
      userId: _requiredString(json, 'userId'),
      phone: _requiredString(json, 'phone'),
      name: _nullableString(json, 'name'),
      city: _requiredString(json, 'city'),
      decorationType: _nullableString(json, 'decorationType'),
      address: _nullableString(json, 'address'),
      area: _nullableDouble(json, 'area'),
      profileComplete: _requiredBool(json, 'profileComplete'),
    );
  }

  final String userId;
  final String phone;
  final String? name;
  final String city;
  final String? decorationType;
  final String? address;
  final double? area;
  final bool profileComplete;
}

final class OwnerProfileUpdate {
  const OwnerProfileUpdate({
    required this.name,
    required this.city,
    required this.decorationType,
    required this.address,
    required this.area,
  });

  final String? name;
  final String city;
  final String? decorationType;
  final String? address;
  final double? area;

  Map<String, dynamic> toJson() => {
    'name': name,
    'city': city,
    'decorationType': decorationType,
    'address': address,
    'area': area,
  };
}

RemoteOwnerProfile _parseProfile(http.Response response) {
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

  final data = envelope['data'];
  if (data is! Map<String, dynamic>) {
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应缺少数据',
      statusCode: response.statusCode,
    );
  }
  try {
    return RemoteOwnerProfile.fromJson(data);
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

double? _nullableDouble(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('$key is required');
  }
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! num) {
    throw FormatException('$key must be a number or null');
  }
  return value.toDouble();
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('$key must be a boolean');
  }
  return value;
}
