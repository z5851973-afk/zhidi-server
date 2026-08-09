import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/services/daily_report_api_client.dart';

void main() {
  test('parses append-only report revision from server response', () {
    final report = RemoteDailyReport.fromJson({
      'id': 'report-2',
      'bookingId': 'booking-1',
      'workerUserId': 'worker-1',
      'reportDate': '2026-08-09',
      'reportRevision': 2,
      'content': '第二版施工记录',
      'photos': <String>[],
      'createdAt': '2026-08-09T01:00:00Z',
    });

    expect(report.reportRevision, 2);
  });

  test('treats legacy report without revision as first version', () {
    final report = RemoteDailyReport.fromJson({
      'id': 'report-legacy',
      'bookingId': 'booking-1',
      'workerUserId': 'worker-1',
      'reportDate': '2026-08-08',
      'content': '旧日报',
      'photos': <String>[],
      'createdAt': '2026-08-08T01:00:00Z',
    });

    expect(report.reportRevision, 1);
  });
}
