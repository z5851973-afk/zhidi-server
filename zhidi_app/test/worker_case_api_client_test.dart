import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/worker_case_api_client.dart';

void main() {
  final baseUrl = Uri.parse('https://api.example.test/root/');
  const caseJson = {
    'id': 'case-1',
    'workerUserId': 'worker-1',
    'title': '旧房水电改造',
    'description': '全屋重新布线并完成验收',
    'serviceCity': '成都',
    'completionYear': 2026,
    'imageUrls': ['https://api.example.test/uploads/cases/demo.jpg'],
    'createdAt': '2026-07-16T10:00:00Z',
    'updatedAt': '2026-07-16T10:00:00Z',
  };

  test('public list uses worker id without authorization', () async {
    late http.BaseRequest captured;
    final api = WorkerCaseApiClient(
      baseUrl: baseUrl,
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': [caseJson],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final cases = await api.listPublicCases('worker-1');

    expect(captured.method, 'GET');
    expect(
      captured.url,
      Uri.parse('https://api.example.test/api/v1/workers/worker-1/cases'),
    );
    expect(captured.headers.containsKey('authorization'), isFalse);
    expect(cases.single.title, '旧房水电改造');
    expect(cases.single.completionYear, 2026);
  });

  test('create sends bearer token and complete case body', () async {
    late http.Request captured;
    final api = WorkerCaseApiClient(
      baseUrl: baseUrl,
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'code': 'OK', 'message': 'success', 'data': caseJson}),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    const draft = WorkerCaseDraft(
      title: '旧房水电改造',
      description: '全屋重新布线并完成验收',
      serviceCity: '成都',
      completionYear: 2026,
      imageUrls: ['https://api.example.test/uploads/cases/demo.jpg'],
    );

    await api.createCase('jwt-token', draft);

    expect(captured.method, 'POST');
    expect(captured.headers['authorization'], 'Bearer jwt-token');
    expect(jsonDecode(captured.body), draft.toJson());
  });

  test(
    'image upload sends authenticated multipart with file metadata',
    () async {
      late http.MultipartRequest captured;
      final captureClient = _MultipartCaptureClient();
      final api = WorkerCaseApiClient(
        baseUrl: baseUrl,
        httpClient: captureClient,
      );
      final url = await api.uploadImage(
        'jwt-token',
        filename: '现场.jpg',
        bytes: [0xff, 0xd8, 0xff, 1],
      );
      captured = captureClient.captured as http.MultipartRequest;

      expect(captured.headers['authorization'], 'Bearer jwt-token');
      expect(captured.files.single.field, 'file');
      expect(captured.files.single.filename, '现场.jpg');
      expect(captured.files.single.contentType.toString(), 'image/jpeg');
      expect(url, 'https://api.example.test/uploads/cases/generated.jpg');
    },
  );

  test('preserves backend case error', () async {
    final api = WorkerCaseApiClient(
      baseUrl: baseUrl,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 'WORKER_CASE_INVALID_IMAGE',
            'message': 'case images must be uploaded by the platform',
            'data': null,
          }),
          400,
        ),
      ),
    );

    await expectLater(
      api.listMyCases('jwt-token'),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.code,
          'code',
          'WORKER_CASE_INVALID_IMAGE',
        ),
      ),
    );
  });
}

final class _MultipartCaptureClient extends http.BaseClient {
  http.BaseRequest? captured;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    captured = request;
    final body = utf8.encode(
      jsonEncode({
        'code': 'OK',
        'message': 'success',
        'data': {'url': 'https://api.example.test/uploads/cases/generated.jpg'},
      }),
    );
    return http.StreamedResponse(
      Stream<List<int>>.value(body),
      201,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
