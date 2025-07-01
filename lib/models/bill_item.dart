class BillItem {
  final int? id;
  final int serialNo;
  final String name;
  final double price;
  final double quantity;
  final DateTime? createdAt;
  final bool isDeleted;

  BillItem({
    this.id,
    required this.serialNo,
    required this.name,
    required this.price,
    required this.quantity,
    this.createdAt,
    this.isDeleted = false,
  });

  double get total => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'serialNo': serialNo,
      'name': name,
      'price': price,
      'quantity': quantity,
      'createdAt':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  static BillItem fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return BillItem(
      id: map['id'] as int?,
      serialNo: map['serialNo'] is int
          ? map['serialNo'] as int
          : int.tryParse(map['serialNo'].toString()) ?? 0,
      name: map['name'] as String,
      price: parseDouble(map['price']),
      quantity: parseDouble(map['quantity']),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      isDeleted: (map['isDeleted'] is int
          ? map['isDeleted'] == 1
          : map['isDeleted'] == true),
    );
  }

  BillItem copyWith({
    int? id,
    int? serialNo,
    String? name,
    double? price,
    double? quantity,
    DateTime? createdAt,
    bool? isDeleted,
  }) {
    return BillItem(
      id: id ?? this.id,
      serialNo: serialNo ?? this.serialNo,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  static double calculateBillTotal(List<BillItem> items) {
    return items.fold(0, (sum, item) => sum + item.total);
  }
}
