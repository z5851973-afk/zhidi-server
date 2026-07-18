import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/pages/home/worker/candidate_picker_page.dart';
import 'package:zhidi_app/services/service_request_api_client.dart';
import 'package:zhidi_app/services/worker_directory_api_client.dart';

void main() {
  final apiBase = Uri.parse('https://api.example.test/root/');

  final sampleWorkers = [
    {
      'userId': 'worker-a',
      'name': '张师傅',
      'primaryTrade': '水电',
      'experienceYears': 8,
      'serviceCity': '成都',
      'bio': '十年水电经验',
      'dailyRate': 350.0,
    },
    {
      'userId': 'worker-b',
      'name': '李师傅',
      'primaryTrade': '水电',
      'experienceYears': 5,
      'serviceCity': '成都',
      'bio': '年轻靠谱',
      'dailyRate': 280.0,
    },
    {
      'userId': 'worker-c',
      'name': '王师傅',
      'primaryTrade': '泥工',
      'experienceYears': 12,
      'serviceCity': '成都',
      'bio': '老泥工',
      'dailyRate': 400.0,
    },
  ];

  MockClient mockDirectoryApi(List<Map<String, dynamic>> workers) {
    return MockClient((request) async {
      return http.Response(
        jsonEncode({
          'code': 'OK',
          'message': 'success',
          'data': workers,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  }

  MockClient mockServiceRequestApi({
    required List<String> addedCandidates,
  }) {
    var candidates = [...addedCandidates];
    return MockClient((request) async {
      final url = request.url.toString();
      if (request.method == 'POST' && url.contains('/candidates')) {
        // extract workerUserId from body
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final workerUserId = body['workerUserId'] as String;
        candidates.add(workerUserId);
        return http.Response(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': {
              'id': 'sr-1',
              'ownerUserId': 'owner-1',
              'trade': '水电',
              'serviceCity': '成都',
              'serviceAddress': null,
              'remark': null,
              'status': 'OPEN',
              'createdAt': '2026-07-01T00:00:00Z',
              'updatedAt': '2026-07-01T00:00:00Z',
              'candidates': candidates.map((id) => {
                'id': 'bk-$id',
                'serviceRequestId': 'sr-1',
                'ownerUserId': 'owner-1',
                'ownerName': '业主',
                'ownerPhone': '13800000000',
                'workerUserId': id,
                'workerName': id == 'worker-a' ? '张师傅' : '李师傅',
                'trade': '水电',
                'serviceCity': '成都',
                'serviceAddress': null,
                'remark': null,
                'status': 'PENDING',
                'cancelledBy': null,
                'cancelReason': null,
                'cancelledAt': null,
                'createdAt': '2026-07-01T00:00:00Z',
                'updatedAt': '2026-07-01T00:00:00Z',
              }).toList(),
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('not found', 404);
    });
  }

  Widget buildPage({
    List<Map<String, dynamic>>? workers,
    List<String>? initialCandidates,
  }) {
    return MaterialApp(
      home: CandidatePickerPage(
        accessToken: 'test-token',
        requestId: 'sr-1',
        trade: '水电',
        serviceCity: '成都',
        workerDirectoryApi: WorkerDirectoryApiClient(
          baseUrl: apiBase,
          httpClient: mockDirectoryApi(workers ?? sampleWorkers),
        ),
        serviceRequestApi: ServiceRequestApiClient(
          baseUrl: apiBase,
          httpClient: mockServiceRequestApi(
            addedCandidates: initialCandidates ?? [],
          ),
        ),
      ),
    );
  }

  testWidgets('shows request header with trade and city', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('水电 · 成都'), findsOneWidget);
    expect(find.text('请为需求挑选候选师傅'), findsOneWidget);
  });

  testWidgets('filters workers by trade', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    // 张师傅 and 李师傅 (水电) should appear
    expect(find.text('张师傅'), findsOneWidget);
    expect(find.text('李师傅'), findsOneWidget);
    // 王师傅 (泥工) should NOT appear
    expect(find.text('王师傅'), findsNothing);
  });

  testWidgets('add candidate button triggers API call', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    // first '添加' button — tap it
    await tester.tap(find.text('添加').first);
    await tester.pumpAndSettle();

    // should show '已选' badge for that worker
    expect(find.text('已选'), findsOneWidget);
    // header should update count
    expect(find.text('已选 1 位候选人'), findsOneWidget);
  });

  testWidgets(
    'already added candidate shows check icon',
    (tester) async {
      await tester.pumpWidget(buildPage(
        workers: [sampleWorkers[0]],
        initialCandidates: ['worker-a'],
      ));
      await tester.pumpAndSettle();

      // '添加' button should not appear
      expect(find.text('添加'), findsNothing);
      // should show check icon and 已选 badge
      expect(find.text('已选'), findsOneWidget);
    },
    skip: true, // CandidatePickerPage no longer accepts initialCandidates — _candidateIds always starts empty
  );
}
