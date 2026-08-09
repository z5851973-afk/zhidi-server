class OrderItem {
  final String id;
  final String? bookingId;
  final String? serviceRequestId;
  final String workerName;
  final String customerName;
  final String phone;
  final String address;
  final String area;
  final String description;
  final String visitTime;
  final DateTime? scheduledVisitAt;
  final DateTime? actualOnSiteAt;
  final String status;
  final DateTime createdAt;

  const OrderItem({
    required this.id,
    this.bookingId,
    this.serviceRequestId,
    required this.workerName,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.area,
    required this.description,
    required this.visitTime,
    this.scheduledVisitAt,
    this.actualOnSiteAt,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    if (bookingId != null) 'bookingId': bookingId,
    if (serviceRequestId != null) 'serviceRequestId': serviceRequestId,
    'workerName': workerName,
    'customerName': customerName,
    'phone': phone,
    'address': address,
    'area': area,
    'description': description,
    'visitTime': visitTime,
    if (scheduledVisitAt != null)
      'scheduledVisitAt': scheduledVisitAt!.toUtc().toIso8601String(),
    if (actualOnSiteAt != null)
      'actualOnSiteAt': actualOnSiteAt!.toUtc().toIso8601String(),
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt'] as String);
    final workerName = json['workerName'] as String;
    final id =
        json['id'] as String? ??
        'order-${createdAt.millisecondsSinceEpoch}-${workerName.hashCode.toRadixString(36)}';
    return OrderItem(
      id: id,
      bookingId: json['bookingId'] as String?,
      serviceRequestId: json['serviceRequestId'] as String?,
      workerName: workerName,
      customerName: json['customerName'] as String,
      phone: json['phone'] as String,
      address: json['address'] as String,
      area: json['area'] as String? ?? '',
      description: json['description'] as String,
      visitTime: json['visitTime'] as String,
      scheduledVisitAt: json['scheduledVisitAt'] != null
          ? DateTime.parse(json['scheduledVisitAt'] as String).toUtc()
          : null,
      actualOnSiteAt: json['actualOnSiteAt'] != null
          ? DateTime.parse(json['actualOnSiteAt'] as String).toUtc()
          : null,
      status: json['status'] as String? ?? '待师傅确认',
      createdAt: createdAt,
    );
  }
}
