class OrderItem {
  final String id;
  final String workerName;
  final String customerName;
  final String phone;
  final String address;
  final String area;
  final String description;
  final String visitTime;
  final String status;
  final DateTime createdAt;

  const OrderItem({
    required this.id,
    required this.workerName,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.area,
    required this.description,
    required this.visitTime,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'workerName': workerName,
    'customerName': customerName,
    'phone': phone,
    'address': address,
    'area': area,
    'description': description,
    'visitTime': visitTime,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt'] as String);
    final workerName = json['workerName'] as String;
    final id = json['id'] as String? ??
        'order-${createdAt.millisecondsSinceEpoch}-${workerName.hashCode.toRadixString(36)}';
    return OrderItem(
      id: id,
      workerName: workerName,
      customerName: json['customerName'] as String,
      phone: json['phone'] as String,
      address: json['address'] as String,
      area: json['area'] as String? ?? '',
      description: json['description'] as String,
      visitTime: json['visitTime'] as String,
      status: json['status'] as String? ?? '待师傅确认',
      createdAt: createdAt,
    );
  }
}
