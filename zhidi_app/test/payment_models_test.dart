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
      'workerSettlement': 180,
      'warrantyRetention': 20,
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
    expect(order.workerSettlement, 180);
    expect(order.warrantyRetention, 20);
  });

  test('calculates warranty retention for legacy payment responses', () {
    final order = PaymentOrderModel.fromJson({
      'id': 'order-legacy',
      'bookingId': 'booking-1',
      'ownerUserId': 'owner-1',
      'workerUserId': 'worker-1',
      'amount': 200,
      'platformFee': 0,
      'workerSettlement': 180,
      'status': 'PENDING',
      'paymentMethod': 'OFFLINE',
      'createdAt': '2026-07-22T00:00:00Z',
      'updatedAt': '2026-07-22T01:00:00Z',
    });

    expect(order.warrantyRetention, 20);
  });
}
