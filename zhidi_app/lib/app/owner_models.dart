const _notProvided = Object();

class OwnerProfile {
  const OwnerProfile({
    required this.name,
    required this.city,
    this.phone = '',
    this.decorationType,
    this.address,
    this.area,
  });
  final String name;
  final String city;
  final String phone;
  final String? decorationType;
  final String? address;
  final double? area;

  bool get isProfileComplete =>
      name.isNotEmpty &&
      (decorationType != null && decorationType!.isNotEmpty) &&
      (address != null && address!.isNotEmpty) &&
      area != null;

  OwnerProfile copyWith({
    String? name,
    String? city,
    String? phone,
    Object? decorationType = _notProvided,
    Object? address = _notProvided,
    Object? area = _notProvided,
  }) =>
      OwnerProfile(
        name: name ?? this.name,
        city: city ?? this.city,
        phone: phone ?? this.phone,
        decorationType: identical(decorationType, _notProvided)
            ? this.decorationType
            : decorationType as String?,
        address:
            identical(address, _notProvided) ? this.address : address as String?,
        area: identical(area, _notProvided) ? this.area : area as double?,
      );
  Map<String, dynamic> toJson() => {
    'name': name,
    'city': city,
    'phone': phone,
    if (decorationType != null) 'decorationType': decorationType,
    if (address != null) 'address': address,
    if (area != null) 'area': area,
  };
  factory OwnerProfile.fromJson(Map<String, dynamic> json) => OwnerProfile(
    name: json['name'] as String,
    city: json['city'] as String,
    phone: json['phone'] as String? ?? '',
    decorationType: json['decorationType'] as String?,
    address: json['address'] as String?,
    area: (json['area'] as num?)?.toDouble(),
  );
}

class OwnerAddress {
  const OwnerAddress({
    required this.id,
    required this.recipient,
    required this.phone,
    required this.city,
    required this.district,
    required this.detail,
    this.isDefault = false,
  });
  final String id, recipient, phone, city, district, detail;
  final bool isDefault;
  OwnerAddress copyWith({
    String? id,
    String? recipient,
    String? phone,
    String? city,
    String? district,
    String? detail,
    bool? isDefault,
  }) => OwnerAddress(
    id: id ?? this.id,
    recipient: recipient ?? this.recipient,
    phone: phone ?? this.phone,
    city: city ?? this.city,
    district: district ?? this.district,
    detail: detail ?? this.detail,
    isDefault: isDefault ?? this.isDefault,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'recipient': recipient,
    'phone': phone,
    'city': city,
    'district': district,
    'detail': detail,
    'isDefault': isDefault,
  };
  factory OwnerAddress.fromJson(Map<String, dynamic> j) => OwnerAddress(
    id: j['id'] as String,
    recipient: j['recipient'] as String,
    phone: j['phone'] as String,
    city: j['city'] as String,
    district: j['district'] as String,
    detail: j['detail'] as String,
    isDefault: j['isDefault'] as bool? ?? false,
  );
}

class OwnerProject {
  const OwnerProject({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    required this.startDate,
    this.status = '进行中',
  });
  final String id, name, city, address, status;
  final DateTime startDate;
  OwnerProject copyWith({
    String? id,
    String? name,
    String? city,
    String? address,
    DateTime? startDate,
    String? status,
  }) => OwnerProject(
    id: id ?? this.id,
    name: name ?? this.name,
    city: city ?? this.city,
    address: address ?? this.address,
    startDate: startDate ?? this.startDate,
    status: status ?? this.status,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'city': city,
    'address': address,
    'startDate': startDate.toIso8601String(),
    'status': status,
  };
  factory OwnerProject.fromJson(Map<String, dynamic> j) => OwnerProject(
    id: j['id'] as String,
    name: j['name'] as String,
    city: j['city'] as String,
    address: j['address'] as String,
    startDate: DateTime.parse(j['startDate'] as String),
    status: j['status'] as String? ?? '进行中',
  );
}

class OwnerReminder {
  const OwnerReminder({
    required this.id,
    required this.title,
    required this.dueAt,
    this.projectId,
    this.isCompleted = false,
  });
  final String id, title;
  final String? projectId;
  final DateTime dueAt;
  final bool isCompleted;
  OwnerReminder copyWith({
    String? id,
    String? title,
    Object? projectId = _notProvided,
    DateTime? dueAt,
    bool? isCompleted,
  }) => OwnerReminder(
    id: id ?? this.id,
    title: title ?? this.title,
    projectId: identical(projectId, _notProvided)
        ? this.projectId
        : projectId as String?,
    dueAt: dueAt ?? this.dueAt,
    isCompleted: isCompleted ?? this.isCompleted,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'projectId': projectId,
    'dueAt': dueAt.toIso8601String(),
    'isCompleted': isCompleted,
  };
  factory OwnerReminder.fromJson(Map<String, dynamic> j) => OwnerReminder(
    id: j['id'] as String,
    title: j['title'] as String,
    projectId: j['projectId'] as String?,
    dueAt: DateTime.parse(j['dueAt'] as String),
    isCompleted: j['isCompleted'] as bool? ?? false,
  );
}

class OwnerMessage {
  const OwnerMessage({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.createdAt,
    this.isRead = false,
  });
  final String id, title, content, category;
  final DateTime createdAt;
  final bool isRead;
  OwnerMessage copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    DateTime? createdAt,
    bool? isRead,
  }) => OwnerMessage(
    id: id ?? this.id,
    title: title ?? this.title,
    content: content ?? this.content,
    category: category ?? this.category,
    createdAt: createdAt ?? this.createdAt,
    isRead: isRead ?? this.isRead,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
  };
  factory OwnerMessage.fromJson(Map<String, dynamic> j) => OwnerMessage(
    id: j['id'] as String,
    title: j['title'] as String,
    content: j['content'] as String,
    category: j['category'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    isRead: j['isRead'] as bool? ?? false,
  );
}

class FavoriteWorker {
  const FavoriteWorker({
    required this.id,
    required this.name,
    required this.trade,
    required this.city,
    this.avatarUrl = '',
  });
  final String id, name, trade, city, avatarUrl;
  FavoriteWorker copyWith({
    String? id,
    String? name,
    String? trade,
    String? city,
    String? avatarUrl,
  }) => FavoriteWorker(
    id: id ?? this.id,
    name: name ?? this.name,
    trade: trade ?? this.trade,
    city: city ?? this.city,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'trade': trade,
    'city': city,
    'avatarUrl': avatarUrl,
  };
  factory FavoriteWorker.fromJson(Map<String, dynamic> j) => FavoriteWorker(
    id: j['id'] as String,
    name: j['name'] as String,
    trade: j['trade'] as String,
    city: j['city'] as String,
    avatarUrl: j['avatarUrl'] as String? ?? '',
  );
}

/// 报价行项目（保存时的快照）
class QuoteLineItem {
  const QuoteLineItem({
    required this.name,
    required this.categoryName,
    required this.unitPrice,
    required this.unit,
    required this.quantity,
  });
  final String name, categoryName, unit;
  final double unitPrice, quantity;
  double get subtotal => unitPrice * quantity;

  Map<String, dynamic> toJson() => {
    'name': name, 'categoryName': categoryName,
    'unitPrice': unitPrice, 'unit': unit, 'quantity': quantity,
  };
  factory QuoteLineItem.fromJson(Map<String, dynamic> j) => QuoteLineItem(
    name: j['name'] as String,
    categoryName: j['categoryName'] as String,
    unitPrice: (j['unitPrice'] as num).toDouble(),
    unit: j['unit'] as String,
    quantity: (j['quantity'] as num).toDouble(),
  );
}

/// 收藏的报价单
class SavedQuote {
  const SavedQuote({
    required this.id,
    required this.workerName,
    required this.tradeName,
    required this.items,
    required this.grandTotal,
    required this.savedAt,
  });
  final String id, workerName, tradeName;
  final List<QuoteLineItem> items;
  final double grandTotal;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'id': id, 'workerName': workerName, 'tradeName': tradeName,
    'items': items.map((e) => e.toJson()).toList(),
    'grandTotal': grandTotal,
    'savedAt': savedAt.toIso8601String(),
  };
  factory SavedQuote.fromJson(Map<String, dynamic> j) => SavedQuote(
    id: j['id'] as String,
    workerName: j['workerName'] as String,
    tradeName: j['tradeName'] as String,
    items: (j['items'] as List<dynamic>)
        .map((e) => QuoteLineItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    grandTotal: (j['grandTotal'] as num).toDouble(),
    savedAt: DateTime.parse(j['savedAt'] as String),
  );
}

class OwnerSettings {
  const OwnerSettings({
    this.pushNotifications = true,
    this.projectNotifications = true,
    this.marketingNotifications = false,
    this.hidePhone = true,
    this.darkMode = false,
  });
  final bool pushNotifications,
      projectNotifications,
      marketingNotifications,
      hidePhone,
      darkMode;
  OwnerSettings copyWith({
    bool? pushNotifications,
    bool? projectNotifications,
    bool? marketingNotifications,
    bool? hidePhone,
    bool? darkMode,
  }) => OwnerSettings(
    pushNotifications: pushNotifications ?? this.pushNotifications,
    projectNotifications: projectNotifications ?? this.projectNotifications,
    marketingNotifications:
        marketingNotifications ?? this.marketingNotifications,
    hidePhone: hidePhone ?? this.hidePhone,
    darkMode: darkMode ?? this.darkMode,
  );
  Map<String, dynamic> toJson() => {
    'pushNotifications': pushNotifications,
    'projectNotifications': projectNotifications,
    'marketingNotifications': marketingNotifications,
    'hidePhone': hidePhone,
    'darkMode': darkMode,
  };
  factory OwnerSettings.fromJson(Map<String, dynamic> j) => OwnerSettings(
    pushNotifications: j['pushNotifications'] as bool? ?? true,
    projectNotifications: j['projectNotifications'] as bool? ?? true,
    marketingNotifications: j['marketingNotifications'] as bool? ?? false,
    hidePhone: j['hidePhone'] as bool? ?? true,
    darkMode: j['darkMode'] as bool? ?? false,
  );
}

class AfterSalesRequest {
  const AfterSalesRequest({
    required this.id,
    required this.issueType,
    required this.description,
    required this.createdAt,
    this.status = '已提交',
  });
  final String id, issueType, description, status;
  final DateTime createdAt;
  AfterSalesRequest copyWith({
    String? id,
    String? issueType,
    String? description,
    DateTime? createdAt,
    String? status,
  }) => AfterSalesRequest(
    id: id ?? this.id,
    issueType: issueType ?? this.issueType,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
    status: status ?? this.status,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'issueType': issueType,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
  };
  factory AfterSalesRequest.fromJson(Map<String, dynamic> j) =>
      AfterSalesRequest(
        id: j['id'] as String,
        issueType: j['issueType'] as String,
        description: j['description'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        status: j['status'] as String? ?? '已提交',
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.text,
    required this.isMe,
    required this.createdAt,
  });

  final String id;
  final String workerId;
  final String workerName;
  final String text;
  final bool isMe;
  final DateTime createdAt;

  ChatMessage copyWith({
    String? id,
    String? workerId,
    String? workerName,
    String? text,
    bool? isMe,
    DateTime? createdAt,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        workerId: workerId ?? this.workerId,
        workerName: workerName ?? this.workerName,
        text: text ?? this.text,
        isMe: isMe ?? this.isMe,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'workerId': workerId,
    'workerName': workerName,
    'text': text,
    'isMe': isMe,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] as String,
    workerId: j['workerId'] as String,
    workerName: j['workerName'] as String,
    text: j['text'] as String,
    isMe: j['isMe'] as bool,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

class FeedbackEntry {
  const FeedbackEntry({
    required this.id,
    required this.category,
    required this.description,
    required this.createdAt,
  });
  final String id, category, description;
  final DateTime createdAt;
  FeedbackEntry copyWith({
    String? id,
    String? category,
    String? description,
    DateTime? createdAt,
  }) => FeedbackEntry(
    id: id ?? this.id,
    category: category ?? this.category,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
  };
  factory FeedbackEntry.fromJson(Map<String, dynamic> j) => FeedbackEntry(
    id: j['id'] as String,
    category: j['category'] as String,
    description: j['description'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

// ── 业主预约的师傅（工序管理核心模型）──
class BookedWorker {
  const BookedWorker({
    required this.id,
    required this.name,
    required this.trade,
    required this.phaseName,
    required this.phaseIndex,
    required this.rating,
    required this.completedOrders,
    required this.years,
    required this.avatarEmoji,
    required this.skills,
    this.status = '已接单待上门',
    this.bookedAt,
    this.distance = 0,
  });
  final String id, name, trade, phaseName;
  final int phaseIndex;
  final double rating;
  final int completedOrders, years;
  final String avatarEmoji;
  final List<String> skills;
  final String status;
  final DateTime? bookedAt;
  final double distance;

  /// 师傅已完成施工
  bool get isCompleted => status == '已完成';

  BookedWorker copyWith({
    String? id,
    String? name,
    String? trade,
    String? phaseName,
    int? phaseIndex,
    double? rating,
    int? completedOrders,
    int? years,
    String? avatarEmoji,
    List<String>? skills,
    String? status,
    DateTime? bookedAt,
    double? distance,
  }) =>
      BookedWorker(
        id: id ?? this.id,
        name: name ?? this.name,
        trade: trade ?? this.trade,
        phaseName: phaseName ?? this.phaseName,
        phaseIndex: phaseIndex ?? this.phaseIndex,
        rating: rating ?? this.rating,
        completedOrders: completedOrders ?? this.completedOrders,
        years: years ?? this.years,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        skills: skills ?? this.skills,
        status: status ?? this.status,
        bookedAt: bookedAt ?? this.bookedAt,
        distance: distance ?? this.distance,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'trade': trade,
    'phaseName': phaseName,
    'phaseIndex': phaseIndex,
    'rating': rating,
    'completedOrders': completedOrders,
    'years': years,
    'avatarEmoji': avatarEmoji,
    'skills': skills,
    'status': status,
    'bookedAt': bookedAt?.toIso8601String(),
    'distance': distance,
  };

  factory BookedWorker.fromJson(Map<String, dynamic> j) => BookedWorker(
    id: j['id'] as String,
    name: j['name'] as String,
    trade: j['trade'] as String,
    phaseName: j['phaseName'] as String,
    phaseIndex: j['phaseIndex'] as int,
    rating: (j['rating'] as num).toDouble(),
    completedOrders: j['completedOrders'] as int,
    years: j['years'] as int,
    avatarEmoji: j['avatarEmoji'] as String,
    skills: List<String>.from(j['skills'] as List),
    status: j['status'] as String? ?? '已接单待上门',
    bookedAt: j['bookedAt'] != null ? DateTime.parse(j['bookedAt'] as String) : null,
    distance: (j['distance'] as num?)?.toDouble() ?? 0,
  );
}

// ── 施工日报（师傅每日完工上传）──
class DailyReport {
  const DailyReport({
    required this.id,
    required this.workerId,
    required this.date,
    required this.imagePaths,
    required this.note,
    required this.phaseIndex,
  });

  final String id;
  final String workerId;
  final DateTime? date;
  final List<String> imagePaths;
  final String note;
  final int phaseIndex;

  DailyReport copyWith({
    String? id,
    String? workerId,
    DateTime? date,
    bool clearDate = false,
    List<String>? imagePaths,
    String? note,
    int? phaseIndex,
  }) =>
      DailyReport(
        id: id ?? this.id,
        workerId: workerId ?? this.workerId,
        date: clearDate ? null : (date ?? this.date),
        imagePaths: imagePaths ?? this.imagePaths,
        note: note ?? this.note,
        phaseIndex: phaseIndex ?? this.phaseIndex,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'workerId': workerId,
    'date': date?.toIso8601String(),
    'imagePaths': imagePaths,
    'note': note,
    'phaseIndex': phaseIndex,
  };

  factory DailyReport.fromJson(Map<String, dynamic> j) => DailyReport(
    id: j['id'] as String,
    workerId: j['workerId'] as String,
    date: j['date'] != null ? DateTime.parse(j['date'] as String) : null,
    imagePaths: List<String>.from(j['imagePaths'] as List),
    note: j['note'] as String? ?? '',
    phaseIndex: j['phaseIndex'] as int,
  );
}

// ── 验收请求 ──
enum InspectionStatus { pending, accepted, rejected }

class InspectionRequest {
  const InspectionRequest({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.phaseName,
    required this.phaseIndex,
    required this.requestedAt,
    this.status = InspectionStatus.pending,
    this.inspectorNote,
  });

  final String id;
  final String workerId;
  final String workerName;
  final String phaseName;
  final int phaseIndex;
  final DateTime requestedAt;
  final InspectionStatus status;
  final String? inspectorNote;

  InspectionRequest copyWith({
    String? id,
    String? workerId,
    String? workerName,
    String? phaseName,
    int? phaseIndex,
    DateTime? requestedAt,
    InspectionStatus? status,
    bool clearInspectorNote = false,
    String? inspectorNote,
  }) =>
      InspectionRequest(
        id: id ?? this.id,
        workerId: workerId ?? this.workerId,
        workerName: workerName ?? this.workerName,
        phaseName: phaseName ?? this.phaseName,
        phaseIndex: phaseIndex ?? this.phaseIndex,
        requestedAt: requestedAt ?? this.requestedAt,
        status: status ?? this.status,
        inspectorNote: clearInspectorNote ? null : (inspectorNote ?? this.inspectorNote),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'workerId': workerId,
    'workerName': workerName,
    'phaseName': phaseName,
    'phaseIndex': phaseIndex,
    'requestedAt': requestedAt.toIso8601String(),
    'status': status.name,
    'inspectorNote': inspectorNote,
  };

  factory InspectionRequest.fromJson(Map<String, dynamic> j) => InspectionRequest(
    id: j['id'] as String,
    workerId: j['workerId'] as String,
    workerName: j['workerName'] as String,
    phaseName: j['phaseName'] as String,
    phaseIndex: j['phaseIndex'] as int,
    requestedAt: DateTime.parse(j['requestedAt'] as String),
    status: InspectionStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => InspectionStatus.pending,
    ),
    inspectorNote: j['inspectorNote'] as String?,
  );
}

// ── 装修档案 ──
class RenovationArchive {
  const RenovationArchive({
    required this.id,
    required this.phaseName,
    required this.phaseIndex,
    required this.workerName,
    required this.trade,
    required this.completedAt,
    this.startedAt,
    this.rating,
    this.skills = const [],
    this.photoUrls = const [],
    this.dailyNotes = const [],
    this.inspectionNote,
    this.avatarEmoji,
  });

  final String id;
  final String phaseName;
  final int phaseIndex;
  final String workerName;
  final String trade;
  final DateTime completedAt;
  final DateTime? startedAt;
  final double? rating;
  final List<String> skills;
  final List<String> photoUrls;
  final List<String> dailyNotes;
  final String? inspectionNote;
  final String? avatarEmoji;

  Map<String, dynamic> toJson() => {
    'id': id,
    'phaseName': phaseName,
    'phaseIndex': phaseIndex,
    'workerName': workerName,
    'trade': trade,
    'completedAt': completedAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'rating': rating,
    'skills': skills,
    'photoUrls': photoUrls,
    'dailyNotes': dailyNotes,
    'inspectionNote': inspectionNote,
    'avatarEmoji': avatarEmoji,
  };

  factory RenovationArchive.fromJson(Map<String, dynamic> j) => RenovationArchive(
    id: j['id'] as String,
    phaseName: j['phaseName'] as String,
    phaseIndex: j['phaseIndex'] as int,
    workerName: j['workerName'] as String,
    trade: j['trade'] as String,
    completedAt: DateTime.parse(j['completedAt'] as String),
    startedAt: j['startedAt'] != null ? DateTime.parse(j['startedAt'] as String) : null,
    rating: (j['rating'] as num?)?.toDouble(),
    skills: List<String>.from((j['skills'] as List<dynamic>?) ?? []),
    photoUrls: List<String>.from((j['photoUrls'] as List<dynamic>?) ?? []),
    dailyNotes: List<String>.from((j['dailyNotes'] as List<dynamic>?) ?? []),
    inspectionNote: j['inspectionNote'] as String?,
    avatarEmoji: j['avatarEmoji'] as String?,
  );
}

// ============================================================
// 材料清单
// ============================================================

enum MaterialCategory { auxiliary, main }

enum EstimateStatus { pending, ordered, delivering, delivered, rejected }

class MaterialItem {
  const MaterialItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    this.imageUrl,
    this.spec,
    this.model,
    this.brand,
  });

  final String id;
  final String name;
  final MaterialCategory category;
  final String unit;
  final int quantity;
  final double unitPrice;
  final String? imageUrl;
  final String? spec;
  final String? model;
  final String? brand;

  double get totalPrice => quantity * unitPrice;

  String get categoryLabel => category == MaterialCategory.auxiliary ? '辅料' : '主材';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'unit': unit,
    'quantity': quantity,
    'unitPrice': unitPrice,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (spec != null) 'spec': spec,
    if (model != null) 'model': model,
    if (brand != null) 'brand': brand,
  };

  factory MaterialItem.fromJson(Map<String, dynamic> j) => MaterialItem(
    id: j['id'] as String,
    name: j['name'] as String,
    category: MaterialCategory.values.byName(j['category'] as String),
    unit: j['unit'] as String,
    quantity: j['quantity'] as int,
    unitPrice: (j['unitPrice'] as num).toDouble(),
    imageUrl: j['imageUrl'] as String?,
    spec: j['spec'] as String?,
    model: j['model'] as String?,
    brand: j['brand'] as String?,
  );

  MaterialItem copyWith({int? quantity}) => MaterialItem(
    id: id,
    name: name,
    category: category,
    unit: unit,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice,
    imageUrl: imageUrl,
    spec: spec,
    model: model,
    brand: brand,
  );
}

class MaterialEstimate {
  const MaterialEstimate({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.workerTrade,
    required this.phaseName,
    required this.phaseIndex,
    required this.createdAt,
    required this.items,
    this.status = EstimateStatus.pending,
    this.selectedItemIds = const <String>{},
    this.orderedAt,
    this.estimatedDelivery,
  });

  final String id;
  final String workerId;
  final String workerName;
  final String workerTrade;
  final String phaseName;
  final int phaseIndex;
  final DateTime createdAt;
  final List<MaterialItem> items;
  final EstimateStatus status;
  final Set<String> selectedItemIds;
  final DateTime? orderedAt;
  final DateTime? estimatedDelivery;

  List<MaterialItem> get auxiliaryItems =>
      items.where((it) => it.category == MaterialCategory.auxiliary).toList();

  List<MaterialItem> get mainItems =>
      items.where((it) => it.category == MaterialCategory.main).toList();

  double get selectedTotal {
    double t = 0;
    for (final item in items) {
      if (selectedItemIds.contains(item.id)) t += item.totalPrice;
    }
    return t;
  }

  int get selectedCount => selectedItemIds.length;

  String get statusLabel => switch (status) {
    EstimateStatus.pending => '待确认',
    EstimateStatus.ordered => '已下单',
    EstimateStatus.delivering => '配送中',
    EstimateStatus.delivered => '已送达',
    EstimateStatus.rejected => '已拒绝',
  };

  String get deliveryInfo {
    if (estimatedDelivery == null) return '';
    final now = DateTime.now();
    if (status == EstimateStatus.delivered) return '已签收';
    if (status == EstimateStatus.delivering) {
      final remain = estimatedDelivery!.difference(now);
      if (remain.inMinutes <= 0) return '即将送达';
      if (remain.inMinutes < 60) return '预计 ${remain.inMinutes} 分钟送达';
      if (remain.inHours < 24) return '预计 ${remain.inHours} 小时后送达';
      return '预计 ${estimatedDelivery!.month}月${estimatedDelivery!.day}日送达';
    }
    return '预计 ${estimatedDelivery!.month}月${estimatedDelivery!.day}日送达';
  }

  String get deliveryProgressLabel {
    switch (status) {
      case EstimateStatus.pending:
        return '待确认';
      case EstimateStatus.ordered:
        return '商家备货中';
      case EstimateStatus.delivering:
        return '配送中';
      case EstimateStatus.delivered:
        return '已签收';
      case EstimateStatus.rejected:
        return '已取消';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'workerId': workerId,
    'workerName': workerName,
    'workerTrade': workerTrade,
    'phaseName': phaseName,
    'phaseIndex': phaseIndex,
    'createdAt': createdAt.toIso8601String(),
    'items': items.map((it) => it.toJson()).toList(),
    'status': status.name,
    'selectedItemIds': selectedItemIds.toList(),
    if (orderedAt != null) 'orderedAt': orderedAt!.toIso8601String(),
    if (estimatedDelivery != null) 'estimatedDelivery': estimatedDelivery!.toIso8601String(),
  };

  factory MaterialEstimate.fromJson(Map<String, dynamic> j) => MaterialEstimate(
    id: j['id'] as String,
    workerId: j['workerId'] as String,
    workerName: j['workerName'] as String,
    workerTrade: j['workerTrade'] as String,
    phaseName: j['phaseName'] as String,
    phaseIndex: j['phaseIndex'] as int,
    createdAt: DateTime.parse(j['createdAt'] as String),
    items: (j['items'] as List<dynamic>)
        .map((e) => MaterialItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    status: EstimateStatus.values.byName(j['status'] as String),
    selectedItemIds: Set<String>.from(
      (j['selectedItemIds'] as List<dynamic>?)?.map((e) => e as String) ?? [],
    ),
    orderedAt: j['orderedAt'] != null ? DateTime.parse(j['orderedAt'] as String) : null,
    estimatedDelivery: j['estimatedDelivery'] != null
        ? DateTime.parse(j['estimatedDelivery'] as String)
        : null,
  );

  MaterialEstimate copyWith({
    EstimateStatus? status,
    Set<String>? selectedItemIds,
    DateTime? orderedAt,
    DateTime? estimatedDelivery,
  }) => MaterialEstimate(
    id: id,
    workerId: workerId,
    workerName: workerName,
    workerTrade: workerTrade,
    phaseName: phaseName,
    phaseIndex: phaseIndex,
    createdAt: createdAt,
    items: items,
    status: status ?? this.status,
    selectedItemIds: selectedItemIds ?? this.selectedItemIds,
    orderedAt: orderedAt ?? this.orderedAt,
    estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
  );
}
