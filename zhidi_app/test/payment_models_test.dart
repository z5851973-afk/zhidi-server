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

  test('parses warranty retention balance and release status', () {
    final retention = WarrantyRetentionModel.fromJson({
      'id': 'retention-1',
      'workerUserId': 'worker-1',
      'ownerUserId': 'owner-1',
      'bookingId': 'booking-1',
      'paymentOrderId': 'order-1',
      'amount': 100,
      'releasedAmount': 70,
      'deductedAmount': 30,
      'remainingAmount': 0,
      'status': 'RELEASED',
      'deductionReason': '售后维修扣减',
      'releasedAt': '2026-07-30T08:00:00Z',
      'createdAt': '2026-07-29T08:00:00Z',
      'updatedAt': '2026-07-30T08:00:00Z',
    });

    expect(retention.amount, 100);
    expect(retention.deductedAmount, 30);
    expect(retention.releasedAmount, 70);
    expect(retention.remainingAmount, 0);
    expect(retention.statusLabel, '已释放');
  });

  test('parses after-sale warranty deduction result', () {
    final afterSale = AfterSaleModel.fromJson({
      'id': 'after-sale-1',
      'bookingId': 'booking-1',
      'ownerUserId': 'owner-1',
      'type': 'COMPLAINT',
      'reason': '水管返潮',
      'status': 'RESOLVED',
      'resolution': '平台判定返修，扣减质保金',
      'warrantyRetentionId': 'retention-1',
      'warrantyDeductionAmount': 30,
      'createdAt': '2026-07-30T00:00:00Z',
      'updatedAt': '2026-07-30T01:00:00Z',
    });

    expect(afterSale.statusLabel, '已解决');
    expect(afterSale.warrantyRetentionId, 'retention-1');
    expect(afterSale.warrantyDeductionAmount, 30);
  });
}
