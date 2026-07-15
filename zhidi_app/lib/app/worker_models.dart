// ============================================================
// 工匠端数据模型
// 严格对齐 owner_models.dart 的设计模式：每个模型含 toJson/fromJson/copyWith
// ============================================================

import '../models/renovation.dart';

const _notProvided = Object();

// ── 工匠基本资料 ──
class WorkerProfile {
  const WorkerProfile({
    required this.name,
    this.phone = '',
    this.avatar = '',
    required this.trade,
    this.experienceYears = 0,
    this.rating = 0.0,
    this.totalOrders = 0,
    this.certifications = const [],
    this.serviceAreas = const [],
    this.bio = '',
    this.idCard = '',
    this.isVerified = false,
  });

  final String name;
  final String phone;
  final String avatar;
  final Trade trade;
  final int experienceYears;
  final double rating;
  final int totalOrders;
  final List<String> certifications;
  final List<String> serviceAreas;
  final String bio;
  final String idCard;
  final bool isVerified;

  String get tradeLabel => trade.label;

  WorkerProfile copyWith({
    String? name,
    String? phone,
    String? avatar,
    Trade? trade,
    int? experienceYears,
    double? rating,
    int? totalOrders,
    List<String>? certifications,
    List<String>? serviceAreas,
    String? bio,
    String? idCard,
    bool? isVerified,
  }) =>
      WorkerProfile(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        avatar: avatar ?? this.avatar,
        trade: trade ?? this.trade,
        experienceYears: experienceYears ?? this.experienceYears,
        rating: rating ?? this.rating,
        totalOrders: totalOrders ?? this.totalOrders,
        certifications: certifications ?? this.certifications,
        serviceAreas: serviceAreas ?? this.serviceAreas,
        bio: bio ?? this.bio,
        idCard: idCard ?? this.idCard,
        isVerified: isVerified ?? this.isVerified,
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'avatar': avatar,
    'trade': trade.name,
    'experienceYears': experienceYears,
    'rating': rating,
    'totalOrders': totalOrders,
    'certifications': certifications,
    'serviceAreas': serviceAreas,
    'bio': bio,
    'idCard': idCard,
    'isVerified': isVerified,
  };

  factory WorkerProfile.fromJson(Map<String, dynamic> j) => WorkerProfile(
    name: j['name'] as String,
    phone: j['phone'] as String? ?? '',
    avatar: j['avatar'] as String? ?? '',
    trade: Trade.values.byName(j['trade'] as String),
    experienceYears: j['experienceYears'] as int? ?? 0,
    rating: (j['rating'] as num?)?.toDouble() ?? 0.0,
    totalOrders: j['totalOrders'] as int? ?? 0,
    certifications: List<String>.from((j['certifications'] as List<dynamic>?) ?? []),
    serviceAreas: List<String>.from((j['serviceAreas'] as List<dynamic>?) ?? []),
    bio: j['bio'] as String? ?? '',
    idCard: j['idCard'] as String? ?? '',
    isVerified: j['isVerified'] as bool? ?? false,
  );
}

// ── 工匠订单状态枚举 ──
enum WorkerOrderStatus {
  pending,   // 待接单
  accepted,  // 已接单
  inProgress,// 施工中
  completed, // 已完成
  cancelled, // 已取消
}

// ── 工匠订单（业主预约 → 工匠视角）──
class WorkerOrder {
  const WorkerOrder({
    required this.id,
    required this.ownerName,
    required this.ownerPhone,
    required this.ownerAddress,
    required this.area,
    required this.requirement,
    required this.description,
    required this.trade,
    this.status = WorkerOrderStatus.pending,
    this.quotedPrice,
    this.visitTime,
    this.hasVisited = false,
    this.createdAt,
    this.phaseIndex,
    this.phaseName,
    this.images = const [],
  });

  final String id;
  final String ownerName;
  final String ownerPhone;
  final String ownerAddress;
  final String area;
  final String requirement;
  final String description;
  final String trade;
  final WorkerOrderStatus status;
  final double? quotedPrice;
  final DateTime? visitTime;
  final bool hasVisited;
  final DateTime? createdAt;
  final int? phaseIndex;
  final String? phaseName;
  final List<String> images;

  String get statusLabel => switch (status) {
    WorkerOrderStatus.pending => '待接单',
    WorkerOrderStatus.accepted => '已接单',
    WorkerOrderStatus.inProgress => '施工中',
    WorkerOrderStatus.completed => '已完成',
    WorkerOrderStatus.cancelled => '已取消',
  };

  WorkerOrder copyWith({
    String? id,
    String? ownerName,
    String? ownerPhone,
    String? ownerAddress,
    String? area,
    String? requirement,
    String? description,
    String? trade,
    WorkerOrderStatus? status,
    double? quotedPrice,
    bool clearQuotedPrice = false,
    DateTime? visitTime,
    bool clearVisitTime = false,
    bool? hasVisited,
    DateTime? createdAt,
    bool clearCreatedAt = false,
    int? phaseIndex,
    bool clearPhaseIndex = false,
    String? phaseName,
    bool clearPhaseName = false,
    List<String>? images,
  }) =>
      WorkerOrder(
        id: id ?? this.id,
        ownerName: ownerName ?? this.ownerName,
        ownerPhone: ownerPhone ?? this.ownerPhone,
        ownerAddress: ownerAddress ?? this.ownerAddress,
        area: area ?? this.area,
        requirement: requirement ?? this.requirement,
        description: description ?? this.description,
        trade: trade ?? this.trade,
        status: status ?? this.status,
        quotedPrice: clearQuotedPrice ? null : (quotedPrice ?? this.quotedPrice),
        visitTime: clearVisitTime ? null : (visitTime ?? this.visitTime),
        hasVisited: hasVisited ?? this.hasVisited,
        createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
        phaseIndex: clearPhaseIndex ? null : (phaseIndex ?? this.phaseIndex),
        phaseName: clearPhaseName ? null : (phaseName ?? this.phaseName),
        images: images ?? this.images,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerName': ownerName,
    'ownerPhone': ownerPhone,
    'ownerAddress': ownerAddress,
    'area': area,
    'requirement': requirement,
    'description': description,
    'trade': trade,
    'status': status.name,
    if (quotedPrice != null) 'quotedPrice': quotedPrice,
    if (visitTime != null) 'visitTime': visitTime!.toIso8601String(),
    if (hasVisited) 'hasVisited': true,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (phaseIndex != null) 'phaseIndex': phaseIndex,
    if (phaseName != null) 'phaseName': phaseName,
    'images': images,
  };

  factory WorkerOrder.fromJson(Map<String, dynamic> j) => WorkerOrder(
    id: j['id'] as String,
    ownerName: j['ownerName'] as String,
    ownerPhone: j['ownerPhone'] as String,
    ownerAddress: j['ownerAddress'] as String,
    area: j['area'] as String,
    requirement: j['requirement'] as String,
    description: j['description'] as String,
    trade: j['trade'] as String,
    status: WorkerOrderStatus.values.byName(j['status'] as String),
    quotedPrice: (j['quotedPrice'] as num?)?.toDouble(),
    visitTime: j['visitTime'] != null ? DateTime.parse(j['visitTime'] as String) : null,
    hasVisited: (j['hasVisited'] as bool?) ?? false,
    createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt'] as String) : null,
    phaseIndex: j['phaseIndex'] as int?,
    phaseName: j['phaseName'] as String?,
    images: List<String>.from((j['images'] as List<dynamic>?) ?? []),
  );
}

// ── 工序进度（关联到某个订单的某个阶段）──
class WorkerPhaseProgress {
  const WorkerPhaseProgress({
    required this.phaseIndex,
    required this.phaseName,
    this.status = WorkerOrderStatus.inProgress,
    this.startedAt,
    this.completedAt,
    this.dailyReportCount = 0,
  });

  final int phaseIndex;
  final String phaseName;
  final WorkerOrderStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int dailyReportCount;

  String get statusLabel => switch (status) {
    WorkerOrderStatus.inProgress => '进行中',
    WorkerOrderStatus.completed => '已完成',
    _ => status.name,
  };

  WorkerPhaseProgress copyWith({
    int? phaseIndex,
    String? phaseName,
    WorkerOrderStatus? status,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    int? dailyReportCount,
  }) =>
      WorkerPhaseProgress(
        phaseIndex: phaseIndex ?? this.phaseIndex,
        phaseName: phaseName ?? this.phaseName,
        status: status ?? this.status,
        startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
        completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
        dailyReportCount: dailyReportCount ?? this.dailyReportCount,
      );

  Map<String, dynamic> toJson() => {
    'phaseIndex': phaseIndex,
    'phaseName': phaseName,
    'status': status.name,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    'dailyReportCount': dailyReportCount,
  };

  factory WorkerPhaseProgress.fromJson(Map<String, dynamic> j) =>
      WorkerPhaseProgress(
        phaseIndex: j['phaseIndex'] as int,
        phaseName: j['phaseName'] as String,
        status: WorkerOrderStatus.values.byName(j['status'] as String),
        startedAt: j['startedAt'] != null
            ? DateTime.parse(j['startedAt'] as String)
            : null,
        completedAt: j['completedAt'] != null
            ? DateTime.parse(j['completedAt'] as String)
            : null,
        dailyReportCount: j['dailyReportCount'] as int? ?? 0,
      );
}

// ── 施工日报（工匠每日完工上传）──
enum WorkerReportStatus {
  submitted, // 已提交
  read,      // 已读（业主已查看）
}

class WorkerDailyReport {
  const WorkerDailyReport({
    required this.id,
    required this.orderId,
    required this.date,
    required this.title,
    required this.content,
    this.images = const [],
    this.status = WorkerReportStatus.submitted,
  });

  final String id;
  final String orderId;
  final DateTime date;
  final String title;
  final String content;
  final List<String> images;
  final WorkerReportStatus status;

  String get statusLabel => switch (status) {
    WorkerReportStatus.submitted => '已提交',
    WorkerReportStatus.read => '已读',
  };

  WorkerDailyReport copyWith({
    String? id,
    String? orderId,
    DateTime? date,
    String? title,
    String? content,
    List<String>? images,
    WorkerReportStatus? status,
  }) =>
      WorkerDailyReport(
        id: id ?? this.id,
        orderId: orderId ?? this.orderId,
        date: date ?? this.date,
        title: title ?? this.title,
        content: content ?? this.content,
        images: images ?? this.images,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'date': date.toIso8601String(),
    'title': title,
    'content': content,
    'images': images,
    'status': status.name,
  };

  factory WorkerDailyReport.fromJson(Map<String, dynamic> j) =>
      WorkerDailyReport(
        id: j['id'] as String,
        orderId: j['orderId'] as String,
        date: DateTime.parse(j['date'] as String),
        title: j['title'] as String,
        content: j['content'] as String,
        images: List<String>.from((j['images'] as List<dynamic>?) ?? []),
        status: WorkerReportStatus.values.byName(j['status'] as String),
      );
}

// ── 验收状态枚举 ──
enum WorkerInspectionStatus {
  pending, // 待验收
  passed,  // 已通过
  failed,  // 未通过
}

// ── 验收请求（工匠端视角）──
class WorkerInspectionRequest {
  const WorkerInspectionRequest({
    required this.id,
    required this.orderId,
    required this.phaseName,
    required this.requestTime,
    this.status = WorkerInspectionStatus.pending,
    this.comment,
    this.images = const [],
  });

  final String id;
  final String orderId;
  final String phaseName;
  final DateTime requestTime;
  final WorkerInspectionStatus status;
  final String? comment;
  final List<String> images;

  String get statusLabel => switch (status) {
    WorkerInspectionStatus.pending => '待验收',
    WorkerInspectionStatus.passed => '已通过',
    WorkerInspectionStatus.failed => '未通过',
  };

  WorkerInspectionRequest copyWith({
    String? id,
    String? orderId,
    String? phaseName,
    DateTime? requestTime,
    WorkerInspectionStatus? status,
    String? comment,
    bool clearComment = false,
    List<String>? images,
  }) =>
      WorkerInspectionRequest(
        id: id ?? this.id,
        orderId: orderId ?? this.orderId,
        phaseName: phaseName ?? this.phaseName,
        requestTime: requestTime ?? this.requestTime,
        status: status ?? this.status,
        comment: clearComment ? null : (comment ?? this.comment),
        images: images ?? this.images,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'phaseName': phaseName,
    'requestTime': requestTime.toIso8601String(),
    'status': status.name,
    if (comment != null) 'comment': comment,
    'images': images,
  };

  factory WorkerInspectionRequest.fromJson(Map<String, dynamic> j) =>
      WorkerInspectionRequest(
        id: j['id'] as String,
        orderId: j['orderId'] as String,
        phaseName: j['phaseName'] as String,
        requestTime: DateTime.parse(j['requestTime'] as String),
        status: WorkerInspectionStatus.values.byName(j['status'] as String),
        comment: j['comment'] as String?,
        images: List<String>.from((j['images'] as List<dynamic>?) ?? []),
      );
}

// ── 收入类型枚举 ──
enum EarningType {
  deposit,  // 定金
  balance,  // 尾款
  bonus,    // 奖励
}

// ── 收入结算状态枚举 ──
enum EarningSettlementStatus {
  pending,   // 待结算
  settled,   // 已到账
}

// ── 收入记录 ──
class EarningRecord {
  const EarningRecord({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.type,
    required this.time,
    required this.orderTitle,
    this.status = EarningSettlementStatus.pending,
  });

  final String id;
  final String orderId;
  final double amount;
  final EarningType type;
  final DateTime time;
  final String orderTitle;
  final EarningSettlementStatus status;

  String get typeLabel => switch (type) {
    EarningType.deposit => '定金',
    EarningType.balance => '尾款',
    EarningType.bonus => '奖励',
  };

  String get statusLabel => switch (status) {
    EarningSettlementStatus.pending => '待结算',
    EarningSettlementStatus.settled => '已到账',
  };

  EarningRecord copyWith({
    String? id,
    String? orderId,
    double? amount,
    EarningType? type,
    DateTime? time,
    String? orderTitle,
    EarningSettlementStatus? status,
  }) =>
      EarningRecord(
        id: id ?? this.id,
        orderId: orderId ?? this.orderId,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        time: time ?? this.time,
        orderTitle: orderTitle ?? this.orderTitle,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'amount': amount,
    'type': type.name,
    'time': time.toIso8601String(),
    'orderTitle': orderTitle,
    'status': status.name,
  };

  factory EarningRecord.fromJson(Map<String, dynamic> j) => EarningRecord(
    id: j['id'] as String,
    orderId: j['orderId'] as String,
    amount: (j['amount'] as num).toDouble(),
    type: EarningType.values.byName(j['type'] as String),
    time: DateTime.parse(j['time'] as String),
    orderTitle: j['orderTitle'] as String,
    status: EarningSettlementStatus.values.byName(j['status'] as String),
  );
}

// ── 消息 ──
class WorkerMessage {
  const WorkerMessage({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.createdAt,
    this.isRead = false,
    this.orderId,
  });

  final String id;
  final String title;
  final String content;
  final String category;
  final DateTime createdAt;
  final bool isRead;
  final String? orderId;

  WorkerMessage copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    DateTime? createdAt,
    bool? isRead,
    String? orderId,
    bool clearOrderId = false,
  }) =>
      WorkerMessage(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        category: category ?? this.category,
        createdAt: createdAt ?? this.createdAt,
        isRead: isRead ?? this.isRead,
        orderId: clearOrderId ? null : (orderId ?? this.orderId),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
    if (orderId != null) 'orderId': orderId,
  };

  factory WorkerMessage.fromJson(Map<String, dynamic> j) => WorkerMessage(
    id: j['id'] as String,
    title: j['title'] as String,
    content: j['content'] as String,
    category: j['category'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    isRead: j['isRead'] as bool? ?? false,
    orderId: j['orderId'] as String?,
  );
}

// ── 工匠设置 ──
class WorkerSettings {
  const WorkerSettings({
    this.acceptOrders = true,
    this.pushNotifications = true,
    this.orderNotifications = true,
    this.inspectionNotifications = true,
    this.serviceAreas = const [],
  });

  final bool acceptOrders;
  final bool pushNotifications;
  final bool orderNotifications;
  final bool inspectionNotifications;
  final List<String> serviceAreas;

  WorkerSettings copyWith({
    bool? acceptOrders,
    bool? pushNotifications,
    bool? orderNotifications,
    bool? inspectionNotifications,
    List<String>? serviceAreas,
  }) =>
      WorkerSettings(
        acceptOrders: acceptOrders ?? this.acceptOrders,
        pushNotifications: pushNotifications ?? this.pushNotifications,
        orderNotifications: orderNotifications ?? this.orderNotifications,
        inspectionNotifications:
            inspectionNotifications ?? this.inspectionNotifications,
        serviceAreas: serviceAreas ?? this.serviceAreas,
      );

  Map<String, dynamic> toJson() => {
    'acceptOrders': acceptOrders,
    'pushNotifications': pushNotifications,
    'orderNotifications': orderNotifications,
    'inspectionNotifications': inspectionNotifications,
    'serviceAreas': serviceAreas,
  };

  factory WorkerSettings.fromJson(Map<String, dynamic> j) => WorkerSettings(
    acceptOrders: j['acceptOrders'] as bool? ?? true,
    pushNotifications: j['pushNotifications'] as bool? ?? true,
    orderNotifications: j['orderNotifications'] as bool? ?? true,
    inspectionNotifications: j['inspectionNotifications'] as bool? ?? true,
    serviceAreas: List<String>.from((j['serviceAreas'] as List<dynamic>?) ?? []),
  );
}

// ═══════════════════════════════════════════
// 报价单
// ═══════════════════════════════════════════
enum QuotationItemCategory { labor, auxiliary, mainMaterial }

extension QuotationItemCategoryExt on QuotationItemCategory {
  String get label => switch (this) {
    QuotationItemCategory.labor => '人工费',
    QuotationItemCategory.auxiliary => '辅料',
    QuotationItemCategory.mainMaterial => '主材',
  };
}

class QuotationItem {
  const QuotationItem({
    required this.name,
    required this.category,
    this.spec = '',
    required this.unitPrice,
    required this.quantity,
    this.unit = '项',
  });

  final String name;
  final QuotationItemCategory category;
  final String spec;
  final double unitPrice;
  final double quantity;
  final String unit;

  double get total => unitPrice * quantity;

  QuotationItem copyWith({
    String? name,
    QuotationItemCategory? category,
    String? spec,
    double? unitPrice,
    double? quantity,
    String? unit,
  }) =>
      QuotationItem(
        name: name ?? this.name,
        category: category ?? this.category,
        spec: spec ?? this.spec,
        unitPrice: unitPrice ?? this.unitPrice,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category.name,
    'spec': spec,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'unit': unit,
  };

  factory QuotationItem.fromJson(Map<String, dynamic> j) => QuotationItem(
    name: j['name'] as String,
    category: QuotationItemCategory.values.firstWhere(
      (c) => c.name == j['category'],
      orElse: () => QuotationItemCategory.labor,
    ),
    spec: (j['spec'] as String?) ?? '',
    unitPrice: (j['unitPrice'] as num).toDouble(),
    quantity: (j['quantity'] as num).toDouble(),
    unit: (j['unit'] as String?) ?? '项',
  );
}

class Quotation {
  const Quotation({
    required this.id,
    required this.orderId,
    required this.items,
    required this.createdAt,
    this.confirmedAt,
  });

  final String id;
  final String orderId;
  final List<QuotationItem> items;
  final DateTime createdAt;
  final DateTime? confirmedAt;

  bool get isConfirmed => confirmedAt != null;

  double get laborTotal => items
      .where((i) => i.category == QuotationItemCategory.labor)
      .fold(0, (s, i) => s + i.total);

  double get auxiliaryTotal => items
      .where((i) => i.category == QuotationItemCategory.auxiliary)
      .fold(0, (s, i) => s + i.total);

  double get mainMaterialTotal => items
      .where((i) => i.category == QuotationItemCategory.mainMaterial)
      .fold(0, (s, i) => s + i.total);

  double get grandTotal => laborTotal + auxiliaryTotal + mainMaterialTotal;

  Quotation copyWith({
    String? id,
    String? orderId,
    List<QuotationItem>? items,
    DateTime? createdAt,
    Object clearConfirmed = _notProvided,
    DateTime? confirmedAt,
  }) =>
      Quotation(
        id: id ?? this.id,
        orderId: orderId ?? this.orderId,
        items: items ?? this.items,
        createdAt: createdAt ?? this.createdAt,
        confirmedAt: clearConfirmed == _notProvided
            ? (confirmedAt ?? this.confirmedAt)
            : (clearConfirmed is DateTime ? clearConfirmed : null),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'items': items.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    if (confirmedAt != null) 'confirmedAt': confirmedAt!.toIso8601String(),
  };

  factory Quotation.fromJson(Map<String, dynamic> j) => Quotation(
    id: j['id'] as String,
    orderId: j['orderId'] as String,
    items: (j['items'] as List<dynamic>)
        .map((e) => QuotationItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(j['createdAt'] as String),
    confirmedAt: j['confirmedAt'] != null
        ? DateTime.parse(j['confirmedAt'] as String)
        : null,
  );
}
