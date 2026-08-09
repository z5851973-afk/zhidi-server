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
          tradeType: '泥工师傅',
          serviceAddress: '杭州市西湖区测试路 1 号',
        ),
      ),
    );

    expect(find.text('预约已提交'), findsOneWidget);
    expect(find.text('上门时间待双方确认'), findsWidgets);
    expect(find.textContaining('10分钟'), findsNothing);
    expect(find.textContaining('30分钟'), findsNothing);
    expect(find.text('4.8'), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.text('联系师傅'), findsNothing);
    expect(find.text('取消预约'), findsNothing);
    expect(find.text('师傅已接单，将尽快与您联系'), findsNothing);
    expect(find.text('已接单·正在联系您'), findsNothing);
  });
}
