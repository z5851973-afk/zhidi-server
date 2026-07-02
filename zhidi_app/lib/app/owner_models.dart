const _notProvided = Object();

class OwnerProfile {
  const OwnerProfile({required this.name, required this.city, this.phone = ''});
  final String name;
  final String city;
  final String phone;
  OwnerProfile copyWith({String? name, String? city, String? phone}) =>
      OwnerProfile(
        name: name ?? this.name,
        city: city ?? this.city,
        phone: phone ?? this.phone,
      );
  Map<String, dynamic> toJson() => {'name': name, 'city': city, 'phone': phone};
  factory OwnerProfile.fromJson(Map<String, dynamic> json) => OwnerProfile(
    name: json['name'] as String,
    city: json['city'] as String,
    phone: json['phone'] as String? ?? '',
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
