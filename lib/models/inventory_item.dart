class InventoryItem {
  final int? id;
  final String name;
  final double price;
  final double quantity;
  final double initialQuantity;
  final String? shortcut;
  final DateTime? createdAt;
  final bool isSold; // Added isSold property

  InventoryItem({
    this.id,
    required this.name,
    required this.price,
    required this.quantity,
    double? initialQuantity,
    this.shortcut,
    this.createdAt,
    this.isSold = false, // Default value is false
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
      'isSold': isSold ? 1 : 0, // Convert bool to int for SQLite
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    // Defensive: always parse as double for price, quantity, initialQuantity
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return InventoryItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: parseDouble(map['price']),
      quantity: parseDouble(map['quantity']),
      initialQuantity: map['initialQuantity'] != null
          ? parseDouble(map['initialQuantity'])
          : parseDouble(map['quantity']),
      shortcut: map['shortcut'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      isSold: map['isSold'] == 1, // Convert int to bool from SQLite
    );
  }

  get stockQuantity => null;

  InventoryItem copyWith({
    int? id,
    String? name,
    double? price,
    double? quantity,
    double? initialQuantity,
    String? shortcut,
    DateTime? createdAt,
    bool? isSold, // Added isSold to copyWith
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      shortcut: shortcut ?? this.shortcut,
      createdAt: createdAt ?? this.createdAt,
      isSold: isSold ?? this.isSold, // Include isSold in copyWith
    );
  }
}
