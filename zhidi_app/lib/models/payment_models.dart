class PaymentOrderModel {
  final String id;
  final String bookingId;
  final String ownerUserId;
  final String workerUserId;
  final String? quoteId;
  final double amount;
  final double platformFee;
  final double workerSettlement;
  final double warrantyRetention;
  final String fundingModel;
  final double quoteAmount;
  final String constructionPaymentStatus;
  final String platformFeeStatus;
  final String
  status; // PENDING/OWNER_REPORTED_PAID/PAID/CANCELLED/REFUNDED/FAILED
  final String? paymentMethod;
  final String? transactionId;
  final String? paidAt;
  final String? ownerReportedPaidAt;
  final String? offlinePaymentChannel;
  final String? paymentReference;
  final String? ownerPaymentNote;
  final String? workerConfirmedReceivedAt;
  final String? constructionPaymentChannel;
  final String? constructionPaymentReference;
  final String? constructionReportedAt;
  final String? constructionConfirmedAt;
  final String? platformFeeChannel;
  final String? platformFeeReference;
  final String? platformFeeReportedAt;
  final String? platformFeeVerifiedAt;
  final String? platformFeeRejectionReason;
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
    required this.warrantyRetention,
    required this.fundingModel,
    required this.quoteAmount,
    required this.constructionPaymentStatus,
    required this.platformFeeStatus,
    required this.status,
    this.paymentMethod,
    this.transactionId,
    this.paidAt,
    this.ownerReportedPaidAt,
    this.offlinePaymentChannel,
    this.paymentReference,
    this.ownerPaymentNote,
    this.workerConfirmedReceivedAt,
    this.constructionPaymentChannel,
    this.constructionPaymentReference,
    this.constructionReportedAt,
    this.constructionConfirmedAt,
    this.platformFeeChannel,
    this.platformFeeReference,
    this.platformFeeReportedAt,
    this.platformFeeVerifiedAt,
    this.platformFeeRejectionReason,
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
      warrantyRetention:
          (json['warrantyRetention'] as num?)?.toDouble() ??
          _calculateWarrantyRetention(json),
      fundingModel: json['fundingModel'] as String? ?? 'LEGACY_OWNER_RETENTION',
      quoteAmount:
          (json['quoteAmount'] as num?)?.toDouble() ??
          ((json['amount'] as num).toDouble() -
              (json['platformFee'] as num).toDouble()),
      constructionPaymentStatus:
          json['constructionPaymentStatus'] as String? ?? 'NOT_REPORTED',
      platformFeeStatus: json['platformFeeStatus'] as String? ?? 'NOT_REPORTED',
      status: json['status'] as String,
      paymentMethod: json['paymentMethod'] as String?,
      transactionId: json['transactionId'] as String?,
      paidAt: json['paidAt'] as String?,
      ownerReportedPaidAt: json['ownerReportedPaidAt'] as String?,
      offlinePaymentChannel: json['offlinePaymentChannel'] as String?,
      paymentReference: json['paymentReference'] as String?,
      ownerPaymentNote: json['ownerPaymentNote'] as String?,
      workerConfirmedReceivedAt: json['workerConfirmedReceivedAt'] as String?,
      constructionPaymentChannel: json['constructionPaymentChannel'] as String?,
      constructionPaymentReference:
          json['constructionPaymentReference'] as String?,
      constructionReportedAt: json['constructionReportedAt'] as String?,
      constructionConfirmedAt: json['constructionConfirmedAt'] as String?,
      platformFeeChannel: json['platformFeeChannel'] as String?,
      platformFeeReference: json['platformFeeReference'] as String?,
      platformFeeReportedAt: json['platformFeeReportedAt'] as String?,
      platformFeeVerifiedAt: json['platformFeeVerifiedAt'] as String?,
      platformFeeRejectionReason: json['platformFeeRejectionReason'] as String?,
      refundedAt: json['refundedAt'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isAwaitingWorkerReceipt =>
      status == 'OWNER_REPORTED_PAID' ||
      (isSplitOfflineV2 &&
          status == 'UNDER_REVIEW' &&
          constructionPaymentStatus == 'REPORTED');
  bool get isAwaitingPlatformFeeReview =>
      isSplitOfflineV2 &&
      status == 'UNDER_REVIEW' &&
      constructionPaymentStatus == 'CONFIRMED' &&
      platformFeeStatus == 'REPORTED';
  bool get isPaid => status == 'PAID';
  bool get isRefunded => status == 'REFUNDED';
  bool get isSplitOfflineV2 => fundingModel == 'OFFLINE_SPLIT_V2';
  bool get canReportConstructionPayment =>
      constructionPaymentStatus == 'NOT_REPORTED' ||
      constructionPaymentStatus == 'REJECTED';
  bool get canReportPlatformFee =>
      platformFeeStatus == 'NOT_REPORTED' || platformFeeStatus == 'REJECTED';
  bool get hasReportableSplitPaymentComponent =>
      canReportConstructionPayment || canReportPlatformFee;
  bool get isConstructionReported =>
      constructionPaymentStatus != 'NOT_REPORTED';
  bool get isConstructionConfirmed => constructionPaymentStatus == 'CONFIRMED';
  bool get isPlatformFeeVerified => platformFeeStatus == 'VERIFIED';

  String get statusLabel {
    return switch (status) {
      'PENDING' => '待支付',
      'OWNER_REPORTED_PAID' => '待工人确认收款',
      'PARTIALLY_REPORTED' => '部分付款已报备',
      'UNDER_REVIEW' => '付款核验中',
      'PAID' => '已支付',
      'CANCELLED' => '已取消',
      'REFUNDED' => '已退款',
      'FAILED' => '支付失败',
      _ => status,
    };
  }
}

class OfflinePaymentInstructionsModel {
  final String orderId;
  final double quoteAmount;
  final double platformFee;
  final double constructionAmount;
  final String workerName;
  final String contactAction;
  final double platformFeeAmount;
  final String companyAccountName;
  final String companyBankName;
  final String companyBankAccount;

  const OfflinePaymentInstructionsModel({
    required this.orderId,
    required this.quoteAmount,
    required this.platformFee,
    required this.constructionAmount,
    required this.workerName,
    required this.contactAction,
    required this.platformFeeAmount,
    required this.companyAccountName,
    required this.companyBankName,
    required this.companyBankAccount,
  });

  factory OfflinePaymentInstructionsModel.fromJson(Map<String, dynamic> json) {
    final construction = json['constructionPayment'] as Map<String, dynamic>;
    final fee = json['platformFeePayment'] as Map<String, dynamic>;
    return OfflinePaymentInstructionsModel(
      orderId: json['orderId'] as String,
      quoteAmount: (json['quoteAmount'] as num).toDouble(),
      platformFee: (json['platformFee'] as num).toDouble(),
      constructionAmount: (construction['amount'] as num).toDouble(),
      workerName: construction['workerName'] as String,
      contactAction: construction['contactAction'] as String,
      platformFeeAmount: (fee['amount'] as num).toDouble(),
      companyAccountName: fee['accountName'] as String,
      companyBankName: fee['bankName'] as String,
      companyBankAccount: fee['bankAccount'] as String,
    );
  }
}

class WorkerWarrantyAccountModel {
  final String? id;
  final String workerUserId;
  final double effectiveBalance;
  final double deductedTotal;
  final double releasedTotal;
  final double capAmount;
  final double outstandingAmount;
  final String status;
  final bool canAcceptNewJobs;
  final String? createdAt;
  final String? updatedAt;

  const WorkerWarrantyAccountModel({
    this.id,
    required this.workerUserId,
    required this.effectiveBalance,
    required this.deductedTotal,
    required this.releasedTotal,
    required this.capAmount,
    required this.outstandingAmount,
    required this.status,
    required this.canAcceptNewJobs,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkerWarrantyAccountModel.fromJson(Map<String, dynamic> json) {
    return WorkerWarrantyAccountModel(
      id: json['id'] as String?,
      workerUserId: json['workerUserId'] as String,
      effectiveBalance: (json['effectiveBalance'] as num).toDouble(),
      deductedTotal: (json['deductedTotal'] as num).toDouble(),
      releasedTotal: (json['releasedTotal'] as num).toDouble(),
      capAmount: (json['capAmount'] as num).toDouble(),
      outstandingAmount: (json['outstandingAmount'] as num).toDouble(),
      status: json['status'] as String,
      canAcceptNewJobs: json['canAcceptNewJobs'] as bool,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class WorkerWarrantyContributionModel {
  final String id;
  final String workerUserId;
  final String? paymentOrderId;
  final String? bookingId;
  final String? afterSaleId;
  final double amountDue;
  final String status;
  final String? paymentChannel;
  final String? paymentReference;
  final String? reportedAt;
  final String? rejectionReason;
  final String? createdAt;
  final String? updatedAt;

  const WorkerWarrantyContributionModel({
    required this.id,
    required this.workerUserId,
    this.paymentOrderId,
    this.bookingId,
    this.afterSaleId,
    required this.amountDue,
    required this.status,
    this.paymentChannel,
    this.paymentReference,
    this.reportedAt,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkerWarrantyContributionModel.fromJson(Map<String, dynamic> json) {
    return WorkerWarrantyContributionModel(
      id: json['id'] as String,
      workerUserId: json['workerUserId'] as String,
      paymentOrderId: json['paymentOrderId'] as String?,
      bookingId: json['bookingId'] as String?,
      afterSaleId: json['afterSaleId'] as String?,
      amountDue: (json['amountDue'] as num).toDouble(),
      status: json['status'] as String,
      paymentChannel: json['paymentChannel'] as String?,
      paymentReference: json['paymentReference'] as String?,
      reportedAt: json['reportedAt'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class WorkerWarrantyPaymentInstructionsModel {
  final String accountName;
  final String bankName;
  final String bankAccount;

  const WorkerWarrantyPaymentInstructionsModel({
    required this.accountName,
    required this.bankName,
    required this.bankAccount,
  });

  factory WorkerWarrantyPaymentInstructionsModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return WorkerWarrantyPaymentInstructionsModel(
      accountName: json['accountName'] as String,
      bankName: json['bankName'] as String,
      bankAccount: json['bankAccount'] as String,
    );
  }
}

double _calculateWarrantyRetention(Map<String, dynamic> json) {
  final amount = (json['amount'] as num).toDouble();
  final platformFee = (json['platformFee'] as num).toDouble();
  final workerSettlement = (json['workerSettlement'] as num).toDouble();
  final retained = amount - platformFee - workerSettlement;
  return retained <= 0 ? 0 : double.parse(retained.toStringAsFixed(2));
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

class WarrantyRetentionModel {
  final String id;
  final String workerUserId;
  final String ownerUserId;
  final String bookingId;
  final String paymentOrderId;
  final double amount;
  final double releasedAmount;
  final double deductedAmount;
  final double remainingAmount;
  final String status; // HELD/RELEASED/DEDUCTED
  final String? deductionReason;
  final String? releasedAt;
  final String createdAt;
  final String updatedAt;

  const WarrantyRetentionModel({
    required this.id,
    required this.workerUserId,
    required this.ownerUserId,
    required this.bookingId,
    required this.paymentOrderId,
    required this.amount,
    required this.releasedAmount,
    required this.deductedAmount,
    required this.remainingAmount,
    required this.status,
    this.deductionReason,
    this.releasedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WarrantyRetentionModel.fromJson(Map<String, dynamic> json) {
    return WarrantyRetentionModel(
      id: json['id'] as String,
      workerUserId: json['workerUserId'] as String,
      ownerUserId: json['ownerUserId'] as String,
      bookingId: json['bookingId'] as String,
      paymentOrderId: json['paymentOrderId'] as String,
      amount: (json['amount'] as num).toDouble(),
      releasedAmount: (json['releasedAmount'] as num).toDouble(),
      deductedAmount: (json['deductedAmount'] as num).toDouble(),
      remainingAmount: (json['remainingAmount'] as num).toDouble(),
      status: json['status'] as String,
      deductionReason: json['deductionReason'] as String?,
      releasedAt: json['releasedAt'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  String get statusLabel {
    return switch (status) {
      'HELD' => '质保冻结中',
      'RELEASED' => '已释放',
      'DEDUCTED' => '已扣减',
      _ => status,
    };
  }
}

class AfterSaleModel {
  final String id;
  final String bookingId;
  final String ownerUserId;
  final String? workerUserId;
  final String type; // REFUND/COMPLAINT/DISPUTE
  final String reason;
  final List<String> evidenceUrls;
  final String status; // OPEN/PLATFORM_PROCESSING/RESOLVED/CLOSED
  final String? resolution;
  final String? warrantyRetentionId;
  final double? warrantyDeductionAmount;
  final String? acceptedAt;
  final String? dueAt;
  final String? resolvedAt;
  final String? closedAt;
  final String? lastActivityAt;
  final String createdAt;
  final String updatedAt;

  const AfterSaleModel({
    required this.id,
    required this.bookingId,
    required this.ownerUserId,
    this.workerUserId,
    required this.type,
    required this.reason,
    this.evidenceUrls = const [],
    required this.status,
    this.resolution,
    this.warrantyRetentionId,
    this.warrantyDeductionAmount,
    this.acceptedAt,
    this.dueAt,
    this.resolvedAt,
    this.closedAt,
    this.lastActivityAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AfterSaleModel.fromJson(Map<String, dynamic> json) {
    return AfterSaleModel(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      ownerUserId: json['ownerUserId'] as String,
      workerUserId: json['workerUserId'] as String?,
      type: json['type'] as String,
      reason: json['reason'] as String,
      evidenceUrls: _stringList(
        json['evidenceUrls'] ??
            (json['evidence'] is String
                ? [json['evidence']]
                : json['evidence']),
      ),
      status: json['status'] as String,
      resolution: json['resolution'] as String?,
      warrantyRetentionId: json['warrantyRetentionId'] as String?,
      warrantyDeductionAmount: (json['warrantyDeductionAmount'] as num?)
          ?.toDouble(),
      acceptedAt: json['acceptedAt'] as String?,
      dueAt: json['dueAt'] as String?,
      resolvedAt: json['resolvedAt'] as String?,
      closedAt: json['closedAt'] as String?,
      lastActivityAt: json['lastActivityAt'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  String get typeLabel {
    return switch (type) {
      'REFUND' => '退款诉求',
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

class AfterSaleEventModel {
  final String id;
  final String afterSaleId;
  final String? actorUserId;
  final String actorRole;
  final String type;
  final String? content;
  final List<String> evidenceUrls;
  final String idempotencyKey;
  final String createdAt;

  const AfterSaleEventModel({
    required this.id,
    required this.afterSaleId,
    this.actorUserId,
    required this.actorRole,
    required this.type,
    this.content,
    this.evidenceUrls = const [],
    required this.idempotencyKey,
    required this.createdAt,
  });

  factory AfterSaleEventModel.fromJson(Map<String, dynamic> json) {
    return AfterSaleEventModel(
      id: json['id'] as String,
      afterSaleId: json['afterSaleId'] as String,
      actorUserId: json['actorUserId'] as String?,
      actorRole: json['actorRole'] as String,
      type: json['type'] as String,
      content: json['content'] as String?,
      evidenceUrls: _stringList(json['evidenceUrls']),
      idempotencyKey: json['idempotencyKey'] as String,
      createdAt: json['createdAt'] as String,
    );
  }

  String get actorLabel => switch (actorRole) {
    'OWNER' => '业主',
    'WORKER' => '师傅',
    'ADMIN' => '平台',
    'SYSTEM' => '系统',
    _ => actorRole,
  };

  String get typeLabel => switch (type) {
    'CREATED' => '提交售后',
    'PARTICIPANT_MESSAGE' => '追加说明',
    'PLATFORM_ACCEPTED' => '平台受理',
    'PLATFORM_REPLY' => '平台回复',
    'RESOLVED' => '已解决',
    'CLOSED' => '已关闭',
    _ => type,
  };
}

class AfterSaleInspectionSummaryModel {
  final String status;
  final int passedCount;
  final int totalCount;

  const AfterSaleInspectionSummaryModel({
    required this.status,
    required this.passedCount,
    required this.totalCount,
  });

  factory AfterSaleInspectionSummaryModel.fromJson(Map<String, dynamic> json) {
    return AfterSaleInspectionSummaryModel(
      status: json['status'] as String,
      passedCount: (json['passedCount'] as num).toInt(),
      totalCount: (json['totalCount'] as num).toInt(),
    );
  }

  String get label => switch (status) {
    'PASSED' => '验收已通过',
    'FAILED' => '验收未通过',
    'INSPECTING' => '验收中',
    'PENDING' => '待验收',
    'NOT_AVAILABLE' => '暂无验收记录',
    _ => status,
  };
}

class AfterSaleOrderContextModel {
  final String bookingId;
  final String? bookingStatus;
  final String trade;
  final String? ownerName;
  final String? workerName;
  final String? serviceCity;
  final String? serviceAddress;
  final String? quoteId;
  final double? quoteAmount;
  final String? paymentOrderId;
  final double? paymentAmount;
  final String? paymentStatus;
  final AfterSaleInspectionSummaryModel inspection;

  const AfterSaleOrderContextModel({
    required this.bookingId,
    this.bookingStatus,
    required this.trade,
    this.ownerName,
    this.workerName,
    this.serviceCity,
    this.serviceAddress,
    this.quoteId,
    this.quoteAmount,
    this.paymentOrderId,
    this.paymentAmount,
    this.paymentStatus,
    required this.inspection,
  });

  factory AfterSaleOrderContextModel.fromJson(Map<String, dynamic> json) {
    return AfterSaleOrderContextModel(
      bookingId: json['bookingId'] as String,
      bookingStatus: json['bookingStatus'] as String?,
      trade: json['trade'] as String? ?? '',
      ownerName: json['ownerName'] as String?,
      workerName: json['workerName'] as String?,
      serviceCity: json['serviceCity'] as String?,
      serviceAddress: json['serviceAddress'] as String?,
      quoteId: json['quoteId'] as String?,
      quoteAmount: (json['quoteAmount'] as num?)?.toDouble(),
      paymentOrderId: json['paymentOrderId'] as String?,
      paymentAmount: (json['paymentAmount'] as num?)?.toDouble(),
      paymentStatus: json['paymentStatus'] as String?,
      inspection: AfterSaleInspectionSummaryModel.fromJson(
        Map<String, dynamic>.from(json['inspection'] as Map),
      ),
    );
  }

  String get tradeLabel => switch (trade.toLowerCase()) {
    'carpentry' || 'woodwork' => '木工',
    'plumbing' || 'water_electricity' => '水电',
    'painting' || 'paint' => '油漆',
    'waterproofing' => '防水',
    'tiling' || 'masonry' => '泥瓦',
    'demolition' => '拆除',
    _ => trade,
  };

  String get paymentLabel => switch (paymentStatus) {
    'PAID' => '已支付',
    'OWNER_REPORTED_PAID' => '待师傅确认收款',
    'PENDING' => '待付款',
    null => '无付款记录',
    _ => paymentStatus!,
  };
}

class AfterSaleDetailModel {
  final AfterSaleModel ticket;
  final AfterSaleOrderContextModel context;
  final List<AfterSaleEventModel> timeline;

  const AfterSaleDetailModel({
    required this.ticket,
    required this.context,
    required this.timeline,
  });

  factory AfterSaleDetailModel.fromJson(Map<String, dynamic> json) {
    return AfterSaleDetailModel(
      ticket: AfterSaleModel.fromJson(
        Map<String, dynamic>.from(json['ticket'] as Map),
      ),
      context: AfterSaleOrderContextModel.fromJson(
        Map<String, dynamic>.from(json['context'] as Map),
      ),
      timeline: (json['timeline'] as List? ?? const [])
          .map(
            (value) => AfterSaleEventModel.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}
