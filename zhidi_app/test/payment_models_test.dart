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
    expect(order.fundingModel, 'LEGACY_OWNER_RETENTION');
    expect(order.isSplitOfflineV2, isFalse);
  });

  test('parses split offline payment component states', () {
    final order = PaymentOrderModel.fromJson({
      'id': 'order-v2',
      'bookingId': 'booking-2',
      'ownerUserId': 'owner-1',
      'workerUserId': 'worker-1',
      'amount': 11924,
      'platformFee': 1084,
      'workerSettlement': 10840,
      'warrantyRetention': 0,
      'fundingModel': 'OFFLINE_SPLIT_V2',
      'quoteAmount': 10840,
      'constructionPaymentStatus': 'REPORTED',
      'platformFeeStatus': 'REPORTED',
      'status': 'UNDER_REVIEW',
      'createdAt': '2026-08-06T00:00:00Z',
      'updatedAt': '2026-08-06T00:00:00Z',
    });

    expect(order.fundingModel, 'OFFLINE_SPLIT_V2');
    expect(order.isSplitOfflineV2, isTrue);
    expect(order.quoteAmount, 10840);
    expect(order.warrantyRetention, 0);
    expect(order.constructionPaymentStatus, 'REPORTED');
    expect(order.platformFeeStatus, 'REPORTED');
    expect(order.isAwaitingWorkerReceipt, isTrue);
    expect(order.isAwaitingPlatformFeeReview, isFalse);

    final awaitingPlatformReview = PaymentOrderModel.fromJson({
      'id': 'order-v2-confirmed',
      'bookingId': 'booking-2',
      'ownerUserId': 'owner-1',
      'workerUserId': 'worker-1',
      'amount': 11924,
      'platformFee': 1084,
      'workerSettlement': 10840,
      'warrantyRetention': 0,
      'fundingModel': 'OFFLINE_SPLIT_V2',
      'quoteAmount': 10840,
      'constructionPaymentStatus': 'CONFIRMED',
      'platformFeeStatus': 'REPORTED',
      'status': 'UNDER_REVIEW',
      'createdAt': '2026-08-06T00:00:00Z',
      'updatedAt': '2026-08-06T00:05:00Z',
    });

    expect(awaitingPlatformReview.isAwaitingWorkerReceipt, isFalse);
    expect(awaitingPlatformReview.isAwaitingPlatformFeeReview, isTrue);
  });

  test('parses worker warranty account and outstanding contribution', () {
    final account = WorkerWarrantyAccountModel.fromJson({
      'id': 'account-1',
      'workerUserId': 'worker-1',
      'effectiveBalance': 3084,
      'deductedTotal': 0,
      'releasedTotal': 0,
      'capAmount': 10000,
      'outstandingAmount': 1084,
      'status': 'TOP_UP_REQUIRED',
      'canAcceptNewJobs': false,
    });
    final contribution = WorkerWarrantyContributionModel.fromJson({
      'id': 'contribution-1',
      'workerUserId': 'worker-1',
      'paymentOrderId': 'order-v2',
      'bookingId': 'booking-2',
      'amountDue': 1084,
      'status': 'DUE',
    });

    expect(account.effectiveBalance, 3084);
    expect(account.outstandingAmount, 1084);
    expect(account.canAcceptNewJobs, isFalse);
    expect(contribution.amountDue, 1084);
    expect(contribution.status, 'DUE');
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

  test(
    'labels refund after-sale records as a claim, not a completed refund',
    () {
      final afterSale = AfterSaleModel.fromJson({
        'id': 'after-sale-refund-1',
        'bookingId': 'booking-1',
        'ownerUserId': 'owner-1',
        'type': 'REFUND',
        'reason': '申请平台核实费用',
        'status': 'OPEN',
        'createdAt': '2026-08-09T00:00:00Z',
        'updatedAt': '2026-08-09T00:00:00Z',
      });

      expect(afterSale.typeLabel, '退款诉求');
    },
  );

  test('parses after-sale order context SLA and append-only timeline', () {
    final detail = AfterSaleDetailModel.fromJson({
      'ticket': {
        'id': 'after-sale-1',
        'bookingId': 'booking-1',
        'ownerUserId': 'owner-1',
        'workerUserId': 'worker-1',
        'type': 'COMPLAINT',
        'reason': '木作开裂',
        'evidenceUrls': ['/uploads/after-sales/create.jpg'],
        'status': 'PLATFORM_PROCESSING',
        'acceptedAt': '2026-08-09T01:10:00Z',
        'dueAt': '2026-08-12T01:00:00Z',
        'lastActivityAt': '2026-08-09T01:20:00Z',
        'createdAt': '2026-08-09T01:00:00Z',
        'updatedAt': '2026-08-09T01:20:00Z',
      },
      'context': {
        'bookingId': 'booking-1',
        'bookingStatus': 'COMPLETED',
        'trade': 'carpentry',
        'ownerName': '张女士',
        'workerName': '李师傅',
        'serviceCity': '成都市',
        'serviceAddress': '武侯区一号',
        'quoteId': 'quote-1',
        'quoteAmount': 10840,
        'paymentOrderId': 'payment-1',
        'paymentAmount': 11924,
        'paymentStatus': 'PAID',
        'inspection': {'status': 'PASSED', 'passedCount': 1, 'totalCount': 1},
      },
      'timeline': [
        {
          'id': 'event-1',
          'afterSaleId': 'after-sale-1',
          'actorUserId': 'owner-1',
          'actorRole': 'OWNER',
          'type': 'CREATED',
          'content': '木作开裂',
          'evidenceUrls': ['/uploads/after-sales/create.jpg'],
          'idempotencyKey': 'created-after-sale-1',
          'createdAt': '2026-08-09T01:00:00Z',
        },
        {
          'id': 'event-2',
          'afterSaleId': 'after-sale-1',
          'actorUserId': 'admin-1',
          'actorRole': 'ADMIN',
          'type': 'PLATFORM_ACCEPTED',
          'content': '平台已受理',
          'evidenceUrls': <String>[],
          'idempotencyKey': 'accept-after-sale-1',
          'createdAt': '2026-08-09T01:10:00Z',
        },
      ],
    });

    expect(detail.ticket.workerUserId, 'worker-1');
    expect(detail.ticket.evidenceUrls, ['/uploads/after-sales/create.jpg']);
    expect(detail.ticket.dueAt, '2026-08-12T01:00:00Z');
    expect(detail.context.workerName, '李师傅');
    expect(detail.context.bookingStatus, 'COMPLETED');
    expect(detail.context.quoteAmount, 10840);
    expect(detail.context.paymentStatus, 'PAID');
    expect(detail.context.inspection.status, 'PASSED');
    expect(detail.timeline.map((event) => event.type), [
      'CREATED',
      'PLATFORM_ACCEPTED',
    ]);
  });
}
