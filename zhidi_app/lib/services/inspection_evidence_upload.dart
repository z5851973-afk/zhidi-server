import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import 'auth_api_client.dart';

typedef InspectionImagePicker = Future<List<File>> Function();
typedef InspectionImageUploader =
    Future<String> Function(File file, String accessToken, String nodeId);

Future<List<File>> pickInspectionImages() async {
  final images = await ImagePicker().pickMultiImage(imageQuality: 82);
  return images.map((image) => File(image.path)).toList(growable: false);
}

Future<String> uploadInspectionImage(
  File file,
  String accessToken,
  String nodeId,
) => InspectionEvidenceUploadClient().upload(
  file,
  accessToken: accessToken,
  nodeId: nodeId,
);

String inspectionEvidenceDisplayUrl(String rawUrl, {Uri? baseUrl}) {
  final parsed = Uri.tryParse(rawUrl);
  if (parsed != null && parsed.hasScheme) return rawUrl;
  return (baseUrl ?? Uri.parse(AuthApiClient.configuredBaseUrl))
      .resolve(rawUrl)
      .toString();
}

final class InspectionEvidenceUploadClient {
  InspectionEvidenceUploadClient({
    Uri? baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 30),
  }) : baseUrl = baseUrl ?? Uri.parse(AuthApiClient.configuredBaseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;

  Future<String> upload(
    File file, {
    required String accessToken,
    required String nodeId,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      baseUrl.resolve('/api/v1/inspection-nodes/$nodeId/evidence'),
    );
    request.headers['authorization'] = 'Bearer $accessToken';
    final bytes = await file.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.uri.pathSegments.last,
        contentType: _imageContentType(file.path),
      ),
    );

    try {
      final streamed = await _httpClient.send(request).timeout(requestTimeout);
      final response = await http.Response.fromStream(streamed);
      final envelope = _decodeEnvelope(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthApiException(
          code: envelope['code'] as String? ?? 'UPLOAD_FAILED',
          message: envelope['message'] as String? ?? '上传失败',
          statusCode: response.statusCode,
        );
      }
      if (envelope['code'] != 'OK' || envelope['data'] is! Map) {
        throw AuthApiException(
          code: 'INVALID_RESPONSE',
          message: '服务器响应格式异常',
          statusCode: response.statusCode,
        );
      }
      final data = Map<String, dynamic>.from(envelope['data'] as Map);
      final rawUrl = data['url'];
      if (rawUrl is! String || rawUrl.isEmpty) {
        throw AuthApiException(
          code: 'INVALID_RESPONSE',
          message: '服务器响应缺少验收照片地址',
          statusCode: response.statusCode,
        );
      }
      return rawUrl;
    } on AuthApiException {
      rethrow;
    } on TimeoutException {
      throw const AuthApiException(code: 'TIMEOUT', message: '上传超时，请稍后重试');
    } catch (_) {
      throw const AuthApiException(
        code: 'NETWORK_UNAVAILABLE',
        message: '无法连接服务器，请检查网络',
      );
    }
  }

  Map<String, dynamic> _decodeEnvelope(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应格式异常',
      statusCode: response.statusCode,
    );
  }

  MediaType _imageContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }
}
