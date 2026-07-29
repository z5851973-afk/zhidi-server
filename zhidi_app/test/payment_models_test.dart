import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/models/payment_models.dart';

void main() {
  test('owner reported payment is not treated as paid', () {
    final order = PaymentOrderModel.fromJson({
      'id': 'order-1',
      'bookingId': 'booking-1',
      'ownerUserId': 'owner-1',
      'workerUserId': 'worker-1',
      'amount': 200,
      'platformFee': 0,
      'workerSettlement': 200,
      'status': 'OWNER_REPORTED_PAID',
      'paymentMethod': 'OFFLINE',
      'ownerReportedPaidAt': '2026-07-22T01:00:00Z',
      'offlinePaymentChannel': '银行卡转账',
      'paymentReference': '尾号 2318',
      'ownerPaymentNote': '已转账',
      'createdAt': '2026-07-22T00:00:00Z',
      'updatedAt': '2026-07-22T01:00:00Z',
    });

    expect(order.isPaid, isFalse);
    expect(order.isAwaitingWorkerReceipt, isTrue);
    expect(order.statusLabel, '待工人确认收款');
    expect(order.offlinePaymentChannel, '银行卡转账');
  });
}
