import 'dart:convert';
import 'dart:io';

/// 统一订单状态，业主端和工人端共用
enum SharedOrderStatus {
  pending, // 待接单
  accepted, // 已接单
  inProgress, // 施工中
  inspection, // 待验收
  completed, // 已完成
  cancelled, // 已取消
}

/// 统一订单模型
class SharedOrder {
  final String id;
  final String ownerName;
  final String ownerPhone;
  final String ownerAddress;
  final String area;
  final String description;
  final String trade; // 工种
  final int phaseIndex;
  final String phaseName;
  final String? workerId;
  final String workerName;

  SharedOrderStatus status;
  double? quotedPrice;
  String? visitTime;
  bool hasVisited;

  List<SharedDailyReport> dailyReports;
  List<SharedInspection> inspections;
  Map<String, dynamic>? quotation; // 报价单 JSON

  final DateTime createdAt;
  DateTime? acceptedAt;
  DateTime? startedAt;
  DateTime? completedAt;

  SharedOrder({
    required this.id,
    required this.ownerName,
    required this.ownerPhone,
    required this.ownerAddress,
    required this.area,
    required this.description,
    required this.trade,
    required this.phaseIndex,
    required this.phaseName,
    this.workerId,
    required this.workerName,
    this.status = SharedOrderStatus.pending,
    this.quotedPrice,
    this.visitTime,
    this.hasVisited = false,
    List<SharedDailyReport>? dailyReports,
    List<SharedInspection>? inspections,
    this.quotation,
    DateTime? createdAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
  })  : dailyReports = dailyReports ?? [],
        inspections = inspections ?? [],
        createdAt = createdAt ?? DateTime.now();

  factory SharedOrder.fromJson(Map<String, dynamic> json) {
    return SharedOrder(
      id: json['id'] as String,
      ownerName: json['ownerName'] as String,
      ownerPhone: json['ownerPhone'] as String,
      ownerAddress: json['ownerAddress'] as String,
      area: json['area'] as String,
      description: json['description'] as String? ?? '',
      trade: json['trade'] as String,
      phaseIndex: json['phaseIndex'] as int? ?? 0,
      phaseName: json['phaseName'] as String? ?? '',
      workerId: json['workerId'] as String?,
      workerName: json['workerName'] as String,
      status: SharedOrderStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'pending'),
        orElse: () => SharedOrderStatus.pending,
      ),
      quotedPrice: (json['quotedPrice'] as num?)?.toDouble(),
      visitTime: json['visitTime'] as String?,
      hasVisited: json['hasVisited'] as bool? ?? false,
      dailyReports: (json['dailyReports'] as List<dynamic>?)
              ?.map((e) =>
                  SharedDailyReport.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      inspections: (json['inspections'] as List<dynamic>?)
              ?.map((e) =>
                  SharedInspection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      quotation: json['quotation'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.parse(json['acceptedAt'] as String)
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerName': ownerName,
        'ownerPhone': ownerPhone,
        'ownerAddress': ownerAddress,
        'area': area,
        'description': description,
        'trade': trade,
        'phaseIndex': phaseIndex,
        'phaseName': phaseName,
        'workerId': workerId,
        'workerName': workerName,
        'status': status.name,
        'quotedPrice': quotedPrice,
        'visitTime': visitTime,
        'hasVisited': hasVisited,
        'dailyReports': dailyReports.map((e) => e.toJson()).toList(),
        'inspections': inspections.map((e) => e.toJson()).toList(),
        'quotation': quotation,
        'createdAt': createdAt.toIso8601String(),
        'acceptedAt': acceptedAt?.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };
}

/// 日报
class SharedDailyReport {
  final String id;
  final DateTime date;
  final String title;
  final String content;
  final List<String> images;
  final String status; // submitted / read

  SharedDailyReport({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
    List<String>? images,
    this.status = 'submitted',
  }) : images = images ?? [];

  factory SharedDailyReport.fromJson(Map<String, dynamic> json) {
    return SharedDailyReport(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      title: json['title'] as String,
      content: json['content'] as String,
      images:
          (json['images'] as List<dynamic>?)?.map((e) => e as String).toList(),
      status: json['status'] as String? ?? 'submitted',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'title': title,
        'content': content,
        'images': images,
        'status': status,
      };
}

/// 验收请求
class SharedInspection {
  final String id;
  final String phaseName;
  final int phaseIndex;
  final DateTime requestTime;
  String status; // pending / passed / failed
  String? comment;
  List<String> images;

  SharedInspection({
    required this.id,
    required this.phaseName,
    required this.phaseIndex,
    DateTime? requestTime,
    this.status = 'pending',
    this.comment,
    List<String>? images,
  })  : requestTime = requestTime ?? DateTime.now(),
        images = images ?? [];

  factory SharedInspection.fromJson(Map<String, dynamic> json) {
    return SharedInspection(
      id: json['id'] as String,
      phaseName: json['phaseName'] as String,
      phaseIndex: json['phaseIndex'] as int? ?? 0,
      requestTime: DateTime.parse(json['requestTime'] as String),
      status: json['status'] as String? ?? 'pending',
      comment: json['comment'] as String?,
      images:
          (json['images'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phaseName': phaseName,
        'phaseIndex': phaseIndex,
        'requestTime': requestTime.toIso8601String(),
        'status': status,
        'comment': comment,
        'images': images,
      };
}

/// 共享订单存储路径
String sharedOrdersPath() {
  return '/Users/liupei/Documents/zhidi/shared_orders.json';
}

/// 从文件读取所有订单
List<SharedOrder> loadSharedOrders() {
  try {
    final file = File(sharedOrdersPath());
    if (!file.existsSync()) return [];
    final text = file.readAsStringSync();
    final list = jsonDecode(text) as List<dynamic>;
    return list
        .map((e) => SharedOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

/// 保存所有订单到文件
void saveSharedOrders(List<SharedOrder> orders) {
  final file = File(sharedOrdersPath());
  final json = jsonEncode(orders.map((o) => o.toJson()).toList());
  file.writeAsStringSync(json);
}
