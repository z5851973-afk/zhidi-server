import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/my_home_page.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/daily_report_api_client.dart';

void main() {
  testWidgets('owner daily report section loads remote reports', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(_validSession()),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: DailyReportSection(
              bookingId: 'booking-1',
              workerName: '张师傅',
              api: _FakeDailyReportApi(),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.text('施工日报'), findsOneWidget);
    expect(find.text('2026-07-18'), findsOneWidget);
    expect(find.text('onsite precheck done, prepare carpentry work'), findsOneWidget);
  });
}

AuthSession _validSession() => AuthSession(
      accessToken: 'owner-jwt',
      tokenType: 'Bearer',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      userId: 'owner-1',
      phone: '13812345678',
      roles: const ['OWNER'],
    );

final class _FakeDailyReportApi implements DailyReportApi {
  @override
  Future<RemoteDailyReport> submitReport(
    String accessToken,
    String bookingId,
    String reportDate,
    String content,
    List<String> photos,
  ) =>
      throw UnimplementedError();

  @override
  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  ) async {
    expect(accessToken, 'owner-jwt');
    expect(bookingId, 'booking-1');
    return [
      RemoteDailyReport(
        id: 'report-1',
        bookingId: bookingId,
        workerUserId: 'worker-1',
        reportDate: '2026-07-18',
        content: 'onsite precheck done, prepare carpentry work',
        photos: const [],
        createdAt: DateTime.utc(2026, 7, 18),
      ),
    ];
  }
}
