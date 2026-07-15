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
  }) => OwnerProfile(
    name: name ?? this.name,
    city: city ?? this.city,
    phone: phone ?? this.phone,
    decorationType: identical(decorationType, _notProvided)
        ? this.decorationType
        : decorationType as String?,
    address: identical(address, _notProvided)
        ? this.address
        : address as String?,
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

  final String name;
  final String categoryName;
  final String unit;
  final double unitPrice;
  final double quantity;

  double get subtotal => unitPrice * quantity;

  Map<String, dynamic> toJson() => {
    'name': name,
    'categoryName': categoryName,
    'unitPrice': unitPrice,
    'unit': unit,
    'quantity': quantity,
  };

  factory QuoteLineItem.fromJson(Map<String, dynamic> json) => QuoteLineItem(
    name: json['name'] as String,
    categoryName: json['categoryName'] as String,
    unitPrice: (json['unitPrice'] as num).toDouble(),
    unit: json['unit'] as String,
    quantity: (json['quantity'] as num).toDouble(),
  );
}

/// 收藏的报价单快照。
class SavedQuote {
  const SavedQuote({
    required this.id,
    required this.workerName,
    required this.tradeName,
    required this.items,
    required this.grandTotal,
    required this.savedAt,
  });

  final String id;
  final String workerName;
  final String tradeName;
  final List<QuoteLineItem> items;
  final double grandTotal;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'workerName': workerName,
    'tradeName': tradeName,
    'items': items.map((item) => item.toJson()).toList(),
    'grandTotal': grandTotal,
    'savedAt': savedAt.toIso8601String(),
  };

  factory SavedQuote.fromJson(Map<String, dynamic> json) => SavedQuote(
    id: json['id'] as String,
    workerName: json['workerName'] as String,
    tradeName: json['tradeName'] as String,
    items: (json['items'] as List<dynamic>)
        .map(
          (item) =>
              QuoteLineItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    grandTotal: (json['grandTotal'] as num).toDouble(),
    savedAt: DateTime.parse(json['savedAt'] as String),
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
