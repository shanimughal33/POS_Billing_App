class InventoryItem {
  final String userId;
  final String name;
  final double price;
  final double quantity;
  final double initialQuantity;
  final String? shortcut;
  final DateTime? createdAt;
  final bool isSold;
  final String? firestoreId;
  final bool isDeleted;

  InventoryItem({
    required this.userId,
    required this.name,
    required this.price,
    required this.quantity,
    double? initialQuantity,
    this.shortcut,
    this.createdAt,
    this.isSold = false,
    this.isDeleted = false,
    this.firestoreId,
  }) : initialQuantity = initialQuantity ?? quantity;

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'initialQuantity': initialQuantity,
      'shortcut': shortcut,
      'createdAt':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'isSold': isSold,
      'isDeleted': isDeleted,
    };
  }

  factory InventoryItem.fromFirestore(Map<String, dynamic> doc, String docId) {
    return InventoryItem(
      firestoreId: docId,
      userId: doc['user_id'] ?? '',
      name: doc['name'] ?? '',
      price: (doc['price'] as num).toDouble(),
      quantity: (doc['quantity'] as num).toDouble(),
      initialQuantity: doc['initialQuantity'] != null
          ? (doc['initialQuantity'] as num).toDouble()
          : (doc['quantity'] as num).toDouble(),
      shortcut: doc['shortcut'],
      createdAt: doc['createdAt'] != null
          ? DateTime.tryParse(doc['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isSold: doc['isSold'] ?? false,
      isDeleted: doc['isDeleted'] ?? false,
    );
  }

  int get priceAsInt => price.toInt();
  int get quantityAsInt => quantity.toInt();
  int get initialQuantityAsInt => initialQuantity.toInt();

  factory InventoryItem.fromInts({
    required String userId,
    required String name,
    required int price,
    required int quantity,
    int? initialQuantity,
    String? shortcut,
    DateTime? createdAt,
    bool isSold = false,
    bool isDeleted = false,
  }) {
    return InventoryItem(
      userId: userId,
      name: name,
      price: price.toDouble(),
      quantity: quantity.toDouble(),
      initialQuantity: initialQuantity?.toDouble(),
      shortcut: shortcut,
      createdAt: createdAt,
      isSold: isSold,
      isDeleted: isDeleted,
    );
  }

  InventoryItem copyWith({
    String? firestoreId,
    String? userId,
    String? name,
    double? price,
    double? quantity,
    double? initialQuantity,
    String? shortcut,
    DateTime? createdAt,
    bool? isSold,
    bool? isDeleted,
  }) {
    return InventoryItem(
      firestoreId: firestoreId ?? this.firestoreId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      shortcut: shortcut ?? this.shortcut,
      createdAt: createdAt ?? this.createdAt,
      isSold: isSold ?? this.isSold,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
