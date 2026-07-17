import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api_client.dart';

final class RemoteDailyReport {
  const RemoteDailyReport({
    required this.id,
    required this.bookingId,
    required this.workerUserId,
    required this.title,
    required this.content,
    required this.imageUrls,
    required this.createdAt,
  });

  factory RemoteDailyReport.fromJson(Map<String, dynamic> json) {
    return RemoteDailyReport(
      id: _requiredString(json, 'id'),
      bookingId: _requiredString(json, 'bookingId'),
      workerUserId: _requiredString(json, 'workerUserId'),
      title: _requiredString(json, 'title'),
      content: _requiredString(json, 'content'),
      imageUrls: (json['imageUrls'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      createdAt: DateTime.parse(_requiredString(json, 'createdAt')).toUtc(),
    );
  }

  final String id;
  final String bookingId;
  final String workerUserId;
  final String title;
  final String content;
  final List<String> imageUrls;
  final DateTime createdAt;
}

abstract interface class DailyReportApi {
  Future<RemoteDailyReport> submitReport(
    String accessToken,
    String bookingId,
    String title,
    String content,
    List<String> imageUrls,
  );

  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  );

  Future<List<RemoteDailyReport>> getMyReports(String accessToken);
}

final class DailyReportApiClient implements DailyReportApi {
  DailyReportApiClient({
    Uri? baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 10),
  }) : baseUrl = baseUrl ?? Uri.parse(AuthApiClient.configuredBaseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;

  @override
  Future<RemoteDailyReport> submitReport(
    String accessToken,
    String bookingId,
    String title,
    String content,
    List<String> imageUrls,
  ) async {
    final response = await _post(
      '/api/v1/bookings/$bookingId/reports',
      accessToken,
      jsonEncode({
        'title': title,
        'content': content,
        'imageUrls': imageUrls,
      }),
    );
    return _parseReport(response);
  }

  @override
  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  ) async {
    final response = await _get(
      '/api/v1/bookings/$bookingId/reports',
      accessToken,
    );
    return _parseReportList(response);
  }

  @override
  Future<List<RemoteDailyReport>> getMyReports(String accessToken) async {
    final response = await _get('/api/v1/workers/me/reports', accessToken);
    return _parseReportList(response);
  }

  Future<http.Response> _post(
    String path,
    String accessToken,
    String body,
  ) async {
    final uri = baseUrl.replace(path: path);
    try {
      return await _httpClient
          .post(uri, headers: _headers(accessToken), body: body)
          .timeout(requestTimeout);
    } on TimeoutException {
      throw AuthApiException(code: 'TIMEOUT', message: '请求超时');
    }
  }

  Future<http.Response> _get(String path, String accessToken) async {
    final uri = baseUrl.replace(path: path);
    try {
      return await _httpClient
          .get(uri, headers: _headers(accessToken))
          .timeout(requestTimeout);
    } on TimeoutException {
      throw AuthApiException(code: 'TIMEOUT', message: '请求超时');
    }
  }

  Map<String, String> _headers(String accessToken) => {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };
}

RemoteDailyReport _parseReport(http.Response response) {
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
    return RemoteDailyReport.fromJson(data);
  } on FormatException {
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应格式异常',
      statusCode: response.statusCode,
    );
  }
}

List<RemoteDailyReport> _parseReportList(http.Response response) {
  final envelope = _parseEnvelope(response);
  final data = envelope['data'];
  if (data is! List<dynamic>) {
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应缺少数据列表',
      statusCode: response.statusCode,
    );
  }
  try {
    return data
        .map((e) => RemoteDailyReport.fromJson(e as Map<String, dynamic>))
        .toList();
  } on FormatException {
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
