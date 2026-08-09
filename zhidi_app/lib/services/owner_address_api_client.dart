import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_api_client.dart';

final class OwnerAddressDraft {
  const OwnerAddressDraft({
    required this.recipient,
    required this.phone,
    required this.province,
    required this.city,
    required this.district,
    required this.detail,
    required this.isDefault,
  });

  final String recipient;
  final String phone;
  final String province;
  final String city;
  final String district;
  final String detail;
  final bool isDefault;

  Map<String, dynamic> toJson() => {
    'recipient': recipient,
    'phone': phone,
    'province': province,
    'city': city,
    'district': district,
    'detail': detail,
    'isDefault': isDefault,
  };
}

final class RemoteOwnerAddress {
  const RemoteOwnerAddress({
    required this.id,
    required this.recipient,
    required this.phone,
    required this.province,
    required this.city,
    required this.district,
    required this.detail,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RemoteOwnerAddress.fromJson(Map<String, dynamic> json) {
    return RemoteOwnerAddress(
      id: _requiredString(json, 'id'),
      recipient: _requiredString(json, 'recipient'),
      phone: _requiredString(json, 'phone'),
      province: _requiredString(json, 'province'),
      city: _requiredString(json, 'city'),
      district: _requiredString(json, 'district'),
      detail: _requiredString(json, 'detail'),
      isDefault: _requiredBool(json, 'isDefault'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }

  final String id;
  final String recipient;
  final String phone;
  final String province;
  final String city;
  final String district;
  final String detail;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
}

abstract interface class OwnerAddressApi {
  Future<List<RemoteOwnerAddress>> list(String accessToken);

  Future<RemoteOwnerAddress> create(
    String accessToken,
    OwnerAddressDraft draft,
  );

  Future<RemoteOwnerAddress> update(
    String accessToken,
    String addressId,
    OwnerAddressDraft draft,
  );

  Future<RemoteOwnerAddress> setDefault(String accessToken, String addressId);

  Future<void> delete(String accessToken, String addressId);
}

final class OwnerAddressApiClient implements OwnerAddressApi {
  OwnerAddressApiClient({
    Uri? baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 10),
  }) : baseUrl = baseUrl ?? Uri.parse(AuthApiClient.configuredBaseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;

  @override
  Future<List<RemoteOwnerAddress>> list(String accessToken) async {
    final response = await _send(
      _authorized('GET', '/api/v1/owners/me/addresses', accessToken),
    );
    final data = _parseEnvelope(response)['data'];
    if (data is! List) throw _invalidResponse(response);
    try {
      return List<RemoteOwnerAddress>.unmodifiable(
        data.map(
          (value) => RemoteOwnerAddress.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      );
    } on FormatException {
      throw _invalidResponse(response);
    } on TypeError {
      throw _invalidResponse(response);
    }
  }

  @override
  Future<RemoteOwnerAddress> create(
    String accessToken,
    OwnerAddressDraft draft,
  ) async {
    return _parseAddress(
      await _send(
        _jsonRequest('POST', '/api/v1/owners/me/addresses', accessToken, draft),
      ),
    );
  }

  @override
  Future<RemoteOwnerAddress> update(
    String accessToken,
    String addressId,
    OwnerAddressDraft draft,
  ) async {
    return _parseAddress(
      await _send(
        _jsonRequest(
          'PUT',
          '/api/v1/owners/me/addresses/${Uri.encodeComponent(addressId)}',
          accessToken,
          draft,
        ),
      ),
    );
  }

  @override
  Future<RemoteOwnerAddress> setDefault(
    String accessToken,
    String addressId,
  ) async {
    return _parseAddress(
      await _send(
        _authorized(
          'PUT',
          '/api/v1/owners/me/addresses/${Uri.encodeComponent(addressId)}/default',
          accessToken,
        ),
      ),
    );
  }

  @override
  Future<void> delete(String accessToken, String addressId) async {
    final response = await _send(
      _authorized(
        'DELETE',
        '/api/v1/owners/me/addresses/${Uri.encodeComponent(addressId)}',
        accessToken,
      ),
    );
    _parseEnvelope(response);
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
    OwnerAddressDraft draft,
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

RemoteOwnerAddress _parseAddress(http.Response response) {
  final data = _parseEnvelope(response)['data'];
  if (data is! Map<String, dynamic>) throw _invalidResponse(response);
  try {
    return RemoteOwnerAddress.fromJson(data);
  } on FormatException {
    throw _invalidResponse(response);
  } on TypeError {
    throw _invalidResponse(response);
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

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean');
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  try {
    return DateTime.parse(value).toUtc();
  } on FormatException {
    throw FormatException('$key must be an ISO-8601 date');
  }
}
