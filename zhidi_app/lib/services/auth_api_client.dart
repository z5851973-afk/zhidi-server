import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

abstract interface class OwnerAuthApi {
  Future<SmsCodeResponse> requestSmsCode(String phone);

  Future<OwnerLoginResponse> loginOwner(String phone, String code);

  Future<OwnerLoginResponse> loginWorker(String phone, String code);

  Future<RemoteWorkerProfile> getWorkerProfile(String token);

  Future<void> updateWorkerProfile(String token, Map<String, dynamic> body);
}

final class AuthApiClient implements OwnerAuthApi {
  AuthApiClient({
    Uri? baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 10),
  }) : baseUrl = baseUrl ?? Uri.parse(configuredBaseUrl),
       _httpClient = httpClient ?? http.Client();

  static const configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://47.109.0.191:8080',
  );

  final Uri baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;

  @override
  Future<SmsCodeResponse> requestSmsCode(String phone) async {
    final response = await _post('/api/v1/auth/sms-codes', {'phone': phone});
    return _parseData(response, SmsCodeResponse.fromJson);
  }

  @override
  Future<OwnerLoginResponse> loginOwner(String phone, String code) async {
    final response = await _post('/api/v1/auth/login', {
      'phone': phone,
      'code': code,
    });
    return _parseData(response, OwnerLoginResponse.fromJson);
  }

  @override
  Future<OwnerLoginResponse> loginWorker(String phone, String code) async {
    final response = await _post('/api/v1/auth/workers/login', {
      'phone': phone,
      'code': code,
    });
    return _parseData(response, OwnerLoginResponse.fromJson);
  }

  @override
  Future<RemoteWorkerProfile> getWorkerProfile(String token) async {
    final response = await _authedGet('/api/v1/workers/me', token: token);
    return _parseData(response, RemoteWorkerProfile.fromJson);
  }

  @override
  Future<void> updateWorkerProfile(
      String token, Map<String, dynamic> body) async {
    final response = await _authedPut(
      '/api/v1/workers/me',
      token: token,
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(
        code: 'UPDATE_FAILED',
        message: '更新资料失败',
        statusCode: response.statusCode,
      );
    }
  }

  Future<({Map<String, dynamic> data, int statusCode})> _post(
    String path,
    Map<String, String> body,
  ) async {
    late final http.Response response;
    try {
      response = await _httpClient
          .post(
            baseUrl.resolve(path),
            headers: const {
              'accept': 'application/json',
              'content-type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
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
    return (data: data, statusCode: response.statusCode);
  }

  Future<http.Response> _authedPut(
    String path, {
    required String token,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await _httpClient
          .put(
            baseUrl.resolve(path),
            headers: {
              'accept': 'application/json',
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
      return response;
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

  Future<({Map<String, dynamic> data, int statusCode})> _authedGet(
    String path, {
    required String token,
  }) async {
    late final http.Response response;
    try {
      response = await _httpClient
          .get(
            baseUrl.resolve(path),
            headers: {
              'accept': 'application/json',
              'authorization': 'Bearer $token',
            },
          )
          .timeout(requestTimeout);
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
    return (data: data, statusCode: response.statusCode);
  }
}

T _parseData<T>(
  ({Map<String, dynamic> data, int statusCode}) response,
  T Function(Map<String, dynamic>) parser,
) {
  try {
    return parser(response.data);
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

final class SmsCodeResponse {
  const SmsCodeResponse({
    required this.simulatedCode,
    required this.expiresInSeconds,
    required this.retryAfterSeconds,
  });

  factory SmsCodeResponse.fromJson(Map<String, dynamic> json) {
    return SmsCodeResponse(
      simulatedCode: json['simulatedCode'] as String?,
      expiresInSeconds: _requiredInt(json, 'expiresInSeconds'),
      retryAfterSeconds: _requiredInt(json, 'retryAfterSeconds'),
    );
  }

  final String? simulatedCode;
  final int expiresInSeconds;
  final int retryAfterSeconds;
}

final class OwnerLoginResponse {
  const OwnerLoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresInSeconds,
    required this.user,
  });

  factory OwnerLoginResponse.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is! Map<String, dynamic>) {
      throw const FormatException('user must be a JSON object');
    }
    return OwnerLoginResponse(
      accessToken: _requiredString(json, 'accessToken'),
      tokenType: _requiredString(json, 'tokenType'),
      expiresInSeconds: _requiredInt(json, 'expiresInSeconds'),
      user: AuthUser.fromJson(user),
    );
  }

  final String accessToken;
  final String tokenType;
  final int expiresInSeconds;
  final AuthUser user;
}

final class AuthUser {
  const AuthUser({
    required this.id,
    required this.phone,
    required this.status,
    required this.roles,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    if (rawRoles is! List) {
      throw const FormatException('roles must be a JSON array');
    }
    return AuthUser(
      id: _requiredString(json, 'id'),
      phone: _requiredString(json, 'phone'),
      status: _requiredString(json, 'status'),
      roles: List.unmodifiable(rawRoles.cast<String>()),
    );
  }

  final String id;
  final String phone;
  final String status;
  final List<String> roles;
}

final class AuthApiException implements Exception {
  const AuthApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'AuthApiException($code, status: $statusCode)';
}

final class RemoteWorkerProfile {
  const RemoteWorkerProfile({
    this.userId,
    required this.phone,
    this.name,
    this.serviceCity,
    this.primaryTrade,
    this.experienceYears,
    this.dailyRate,
    this.bio,
    this.profileComplete = false,
  });

  factory RemoteWorkerProfile.fromJson(Map<String, dynamic> json) {
    return RemoteWorkerProfile(
      userId: json['userId'] as String?,
      phone: _requiredString(json, 'phone'),
      name: json['name'] as String?,
      serviceCity: json['serviceCity'] as String?,
      primaryTrade: json['primaryTrade'] as String?,
      experienceYears: json['experienceYears'] as int?,
      dailyRate: (json['dailyRate'] as num?)?.toDouble(),
      bio: json['bio'] as String?,
      profileComplete: json['profileComplete'] as bool? ?? false,
    );
  }

  final String? userId;
  final String phone;
  final String? name;
  final String? serviceCity;
  final String? primaryTrade;
  final int? experienceYears;
  final double? dailyRate;
  final String? bio;
  final bool profileComplete;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key must be an integer');
  }
  return value;
}
