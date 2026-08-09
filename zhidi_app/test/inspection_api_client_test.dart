import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/services/inspection_api_client.dart';
import 'package:zhidi_app/services/inspection_evidence_upload.dart';

void main() {
  test(
    'inspection evidence upload is scoped to node and bearer session',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'code': 'OK',
            'message': 'ok',
            'data': {
              'url':
                  '/uploads/inspection-evidence/booking/node/worker/proof.jpg',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final directory = await Directory.systemTemp.createTemp(
        'inspection-evidence-test-',
      );
      final file = File('${directory.path}/proof.jpg');
      await file.writeAsBytes(const [0xff, 0xd8, 0xff, 0xd9]);
      addTearDown(() => directory.delete(recursive: true));
      final api = InspectionEvidenceUploadClient(
        baseUrl: Uri.parse('https://api.example.com'),
        httpClient: client,
      );

      final url = await api.upload(
        file,
        accessToken: 'fresh-worker-token',
        nodeId: 'node-42',
      );

      expect(captured.method, 'POST');
      expect(
        captured.url.toString(),
        'https://api.example.com/api/v1/inspection-nodes/node-42/evidence',
      );
      expect(captured.headers['authorization'], 'Bearer fresh-worker-token');
      expect(
        captured.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      expect(
        latin1.decode(captured.bodyBytes),
        contains('filename="proof.jpg"'),
      );
      expect(url, '/uploads/inspection-evidence/booking/node/worker/proof.jpg');
      expect(
        inspectionEvidenceDisplayUrl(
          url,
          baseUrl: Uri.parse('https://api.example.com'),
        ),
        'https://api.example.com/uploads/inspection-evidence/booking/node/worker/proof.jpg',
      );
    },
  );

  test('request inspection sends worker evidence to the server', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'code': 'OK',
          'message': 'ok',
          'data': {
            'id': 'node-1',
            'bookingId': 'booking-1',
            'name': '木工验收',
            'status': 'INSPECTING',
            'sortOrder': 1,
            'createdAt': '2026-08-08T01:00:00Z',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = InspectionApiClient(
      baseUrl: Uri.parse('https://api.example.com'),
      httpClient: client,
    );

    final node = await api.requestInspectionWithEvidence(
      'worker-token',
      'node-1',
      '  已完成整改  ',
      const ['https://api.example.com/uploads/inspection-evidence/proof.jpg'],
    );

    expect(captured.method, 'PUT');
    expect(
      captured.url.toString(),
      'https://api.example.com/api/v1/inspection-nodes/node-1/request-inspection',
    );
    expect(captured.headers['authorization'], 'Bearer worker-token');
    expect(jsonDecode(captured.body), {
      'note': '已完成整改',
      'photos': [
        'https://api.example.com/uploads/inspection-evidence/proof.jpg',
      ],
    });
    expect(node.status, 'INSPECTING');
  });

  test(
    'timeline parser keeps worker submission and owner decision rounds',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/inspection-nodes/node-1/timeline');
        return http.Response(
          jsonEncode({
            'code': 'OK',
            'message': 'ok',
            'data': [
              {
                'id': 'submission-1',
                'nodeId': 'node-1',
                'type': 'WORKER_SUBMISSION',
                'actorRole': 'WORKER',
                'actorUserId': 'worker-1',
                'round': 2,
                'result': null,
                'note': '第二次整改完成',
                'photos': ['/uploads/inspection-evidence/worker-2.jpg'],
                'createdAt': '2026-08-08T02:00:00Z',
              },
              {
                'id': 'decision-1',
                'nodeId': 'node-1',
                'type': 'OWNER_DECISION',
                'actorRole': 'OWNER',
                'actorUserId': 'owner-1',
                'round': 2,
                'result': 'PASS',
                'note': '复验通过',
                'photos': [],
                'createdAt': '2026-08-08T03:00:00Z',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = InspectionApiClient(
        baseUrl: Uri.parse('https://api.example.com'),
        httpClient: client,
      );

      final timeline = await api.getInspectionTimeline('token', 'node-1');

      expect(timeline, hasLength(2));
      expect(timeline.first.isWorkerSubmission, isTrue);
      expect(timeline.first.version, 2);
      expect(timeline.first.note, '第二次整改完成');
      expect(timeline.last.isOwnerDecision, isTrue);
      expect(timeline.last.isPassed, isTrue);
    },
  );
}
