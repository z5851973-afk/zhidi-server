import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

final class UploadApiClient {
  UploadApiClient({
    Uri? baseUrl,
    this.requestTimeout = const Duration(seconds: 30),
  }) : baseUrl = baseUrl ?? Uri.parse(configuredBaseUrl);

  static const configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://47.109.0.191:8080',
  );

  final Uri baseUrl;
  final Duration requestTimeout;

  Future<UploadResult> uploadImage(
    File file, {
    required String accessToken,
    String category = 'uploads',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      baseUrl.resolve('/api/v1/storage/upload'),
    );
    request.headers['authorization'] = 'Bearer $accessToken';
    request.fields['category'] = category;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    try {
      final streamedResponse =
          await request.send().timeout(requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final envelope = _tryDecode(response);
        throw UploadApiException(
          code: envelope['code'] as String? ?? 'UPLOAD_FAILED',
          message: envelope['message'] as String? ?? '上传失败',
          statusCode: response.statusCode,
        );
      }

      final envelope = _requireValidEnvelope(response);
      final data = envelope['data'];
      if (data is! Map<String, dynamic>) {
        throw const UploadApiException(
          code: 'INVALID_RESPONSE',
          message: '服务器响应格式异常',
        );
      }

      return UploadResult.fromJson(data);
    } on UploadApiException {
      rethrow;
    } on TimeoutException {
      throw const UploadApiException(
        code: 'NETWORK_TIMEOUT',
        message: '上传超时，请稍后重试',
      );
    } catch (_) {
      throw const UploadApiException(
        code: 'NETWORK_UNAVAILABLE',
        message: '无法连接服务器，请检查网络',
      );
    }
  }

  Map<String, dynamic> _tryDecode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  Map<String, dynamic> _requireValidEnvelope(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('response must be a JSON object');
      }
      final apiCode = decoded['code'];
      if (apiCode != 'OK') {
        throw UploadApiException(
          code: apiCode is String ? apiCode : 'REQUEST_FAILED',
          message: decoded['message'] is String
              ? decoded['message'] as String
              : '请求失败',
          statusCode: response.statusCode,
        );
      }
      return decoded;
    } on UploadApiException {
      rethrow;
    } on FormatException {
      throw UploadApiException(
        code: 'INVALID_RESPONSE',
        message: '服务器响应格式异常',
        statusCode: response.statusCode,
      );
    }
  }
}

final class UploadResult {
  const UploadResult({
    required this.url,
    required this.objectKey,
  });

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      url: json['url'] as String? ?? '',
      objectKey: json['objectKey'] as String? ?? '',
    );
  }

  final String url;
  final String objectKey;
}

final class UploadApiException implements Exception {
  const UploadApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'UploadApiException($code, status: $statusCode)';
}
