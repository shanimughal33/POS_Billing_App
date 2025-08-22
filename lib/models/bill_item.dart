class BillItem {
  final int? id;
  final int? billId;
  final int serialNo;
  final String name;
  final double price;
  final double quantity;
  final DateTime? createdAt;
  final bool isDeleted;

  BillItem({
    this.id,
    this.billId,
    required this.serialNo,
    required this.name,
    required this.price,
    required this.quantity,
    this.createdAt,
    this.isDeleted = false,
  });

  double get total => price * quantity;

  // Helper methods for int/double conversion
  int get priceAsInt => price.toInt();
  int get quantityAsInt => quantity.toInt();

  // Create from int values
  factory BillItem.fromInts({
    int? id,
    int? billId,
    required int serialNo,
    required String name,
    required int price,
    required int quantity,
    DateTime? createdAt,
    bool isDeleted = false,
  }) {
    return BillItem(
      id: id,
      billId: billId,
      serialNo: serialNo,
      name: name,
      price: price.toDouble(),
      quantity: quantity.toDouble(),
      createdAt: createdAt,
      isDeleted: isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'billId': billId,
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
    return BillItem(
      id: map['id'] != null
          ? (map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()))
          : null,
      billId: map['billId'] != null
          ? (map['billId'] is int
                ? map['billId']
                : int.tryParse(map['billId'].toString()))
          : null,
      name: map['name'],
      price: (map['price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      serialNo: map['serialNo'] != null
          ? (map['serialNo'] is int
                    ? map['serialNo']
                    : int.tryParse(map['serialNo'].toString())) ??
                0
          : 0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : null,
      isDeleted: map['isDeleted'] == 1 || map['isDeleted'] == true,
    );
  }

  BillItem copyWith({
    int? id,
    int? billId,
    int? serialNo,
    String? name,
    double? price,
    double? quantity,
    DateTime? createdAt,
    bool? isDeleted,
  }) {
    return BillItem(
      id: id ?? this.id,
      billId: billId ?? this.billId,
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
