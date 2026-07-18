class PaymentOrderModel {
  final String id;
  final String bookingId;
  final String ownerUserId;
  final String workerUserId;
  final String? quoteId;
  final double amount;
  final double platformFee;
  final double workerSettlement;
  final String status; // PENDING/PAID/CANCELLED/REFUNDED/FAILED
  final String? paymentMethod;
  final String? transactionId;
  final String? paidAt;
  final String? refundedAt;
  final String createdAt;
  final String updatedAt;

  const PaymentOrderModel({
    required this.id,
    required this.bookingId,
    required this.ownerUserId,
    required this.workerUserId,
    this.quoteId,
    required this.amount,
    required this.platformFee,
    required this.workerSettlement,
    required this.status,
    this.paymentMethod,
    this.transactionId,
    this.paidAt,
    this.refundedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentOrderModel.fromJson(Map<String, dynamic> json) {
    return PaymentOrderModel(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      ownerUserId: json['ownerUserId'] as String,
      workerUserId: json['workerUserId'] as String,
      quoteId: json['quoteId'] as String?,
      amount: (json['amount'] as num).toDouble(),
      platformFee: (json['platformFee'] as num).toDouble(),
      workerSettlement: (json['workerSettlement'] as num).toDouble(),
      status: json['status'] as String,
      paymentMethod: json['paymentMethod'] as String?,
      transactionId: json['transactionId'] as String?,
      paidAt: json['paidAt'] as String?,
      refundedAt: json['refundedAt'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isPaid => status == 'PAID';
  bool get isRefunded => status == 'REFUNDED';

  String get statusLabel {
    return switch (status) {
      'PENDING' => '待支付',
      'PAID' => '已支付',
      'CANCELLED' => '已取消',
      'REFUNDED' => '已退款',
      'FAILED' => '支付失败',
      _ => status,
    };
  }
}

class SettlementModel {
  final String id;
  final String workerUserId;
  final String bookingId;
  final String paymentOrderId;
  final double amount;
  final String status; // PENDING/SETTLEABLE/SETTLED/FROZEN
  final String? frozenReason;
  final String? settledAt;
  final String createdAt;
  final String updatedAt;

  const SettlementModel({
    required this.id,
    required this.workerUserId,
    required this.bookingId,
    required this.paymentOrderId,
    required this.amount,
    required this.status,
    this.frozenReason,
    this.settledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SettlementModel.fromJson(Map<String, dynamic> json) {
    return SettlementModel(
      id: json['id'] as String,
      workerUserId: json['workerUserId'] as String,
      bookingId: json['bookingId'] as String,
      paymentOrderId: json['paymentOrderId'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      frozenReason: json['frozenReason'] as String?,
      settledAt: json['settledAt'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  String get statusLabel {
    return switch (status) {
      'PENDING' => '待结算',
      'SETTLEABLE' => '可结算',
      'SETTLED' => '已结算',
      'FROZEN' => '已冻结',
      _ => status,
    };
  }
}

class AfterSaleModel {
  final String id;
  final String bookingId;
  final String ownerUserId;
  final String type; // REFUND/COMPLAINT/DISPUTE
  final String reason;
  final String? evidence;
  final String status; // OPEN/PLATFORM_PROCESSING/RESOLVED/CLOSED
  final String? resolution;
  final String createdAt;
  final String updatedAt;

  const AfterSaleModel({
    required this.id,
    required this.bookingId,
    required this.ownerUserId,
    required this.type,
    required this.reason,
    this.evidence,
    required this.status,
    this.resolution,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AfterSaleModel.fromJson(Map<String, dynamic> json) {
    return AfterSaleModel(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      ownerUserId: json['ownerUserId'] as String,
      type: json['type'] as String,
      reason: json['reason'] as String,
      evidence: json['evidence'] as String?,
      status: json['status'] as String,
      resolution: json['resolution'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  String get typeLabel {
    return switch (type) {
      'REFUND' => '退款',
      'COMPLAINT' => '投诉',
      'DISPUTE' => '争议',
      _ => type,
    };
  }

  String get statusLabel {
    return switch (status) {
      'OPEN' => '待处理',
      'PLATFORM_PROCESSING' => '平台处理中',
      'RESOLVED' => '已解决',
      'CLOSED' => '已关闭',
      _ => status,
    };
  }
}
