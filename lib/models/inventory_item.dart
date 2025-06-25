class InventoryItem {
  final int? id;
  final String name;
  final double price;
  final double quantity;
  final double initialQuantity;
  final String? shortcut;
  final DateTime? createdAt;

  InventoryItem({
    this.id,
    required this.name,
    required this.price,
    required this.quantity,
    double? initialQuantity,
    this.shortcut,
    this.createdAt,
  }) : initialQuantity = initialQuantity ?? quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'initialQuantity': initialQuantity,
      'shortcut': shortcut,
      'createdAt':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      initialQuantity: map['initialQuantity'] != null
          ? (map['initialQuantity'] as num).toDouble()
          : (map['quantity'] as num).toDouble(),
      shortcut: map['shortcut'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }

  InventoryItem copyWith({
    int? id,
    String? name,
    double? price,
    double? quantity,
    double? initialQuantity,
    String? shortcut,
    DateTime? createdAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      shortcut: shortcut ?? this.shortcut,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
