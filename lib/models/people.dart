class People {
  final String? id;
  final String userId;
  final String name;
  final String phone;
  final String category; // customer, supplier, or custom
  final double balance;
  final DateTime lastTransactionDate;
  final String? description;
  final String? address;
  final String? notes;
  final bool isDeleted;

  People({
    this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.category,
    required this.balance,
    required this.lastTransactionDate,
    this.description,
    this.address,
    this.notes,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'phone': phone,
      'category': category,
      'balance': balance,
      'lastTransactionDate': lastTransactionDate.toIso8601String(),
      'description': description,
      'address': address,
      'notes': notes,
      'isDeleted': isDeleted,
    };
  }

  factory People.fromMap(Map<String, dynamic> map) {
    return People(
      id: map['id'], // will be overridden with doc.id in repository
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      category: map['category'] ?? '',
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      lastTransactionDate: map['lastTransactionDate'] != null
          ? DateTime.tryParse(map['lastTransactionDate']) ?? DateTime.now()
          : DateTime.now(),
      description: map['description'],
      address: map['address'],
      notes: map['notes'],
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  People copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? category,
    double? balance,
    DateTime? lastTransactionDate,
    String? description,
    String? address,
    String? notes,
    bool? isDeleted,
  }) {
    return People(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      category: category ?? this.category,
      balance: balance ?? this.balance,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
      description: description ?? this.description,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
