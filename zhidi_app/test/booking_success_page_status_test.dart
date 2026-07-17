import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/pages/renovation/booking_success_page.dart';

void main() {
  testWidgets('booking success page shows pending confirmation copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BookingSuccessPage(
          workerName: '预约联调周师傅',
          workerJob: '泥工师傅',
          rating: 4.8,
          renovationStage: '基础施工',
          tradeType: '泥工师傅',
          serviceAddress: '杭州市西湖区测试路 1 号',
          estimatedTime: '下单后30分钟内',
        ),
      ),
    );

    expect(find.text('预约已提交'), findsOneWidget);
    expect(find.text('等待师傅确认，确认后将尽快与您联系'), findsOneWidget);
    expect(find.text('待确认·等待师傅响应'), findsOneWidget);
    expect(find.text('师傅已接单，将尽快与您联系'), findsNothing);
    expect(find.text('已接单·正在联系您'), findsNothing);
  });
}
