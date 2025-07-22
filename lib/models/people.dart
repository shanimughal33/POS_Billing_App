class People {
  final int? id;
  final String name;
  final String phone;
  final String category; // customer, supplier, or custom
  final double balance;
  final DateTime lastTransactionDate;
  final String? description;
  final String? address;
  final String? notes;
  final int isDeleted;

  People({
    this.id,
    required this.name,
    required this.phone,
    required this.category,
    required this.balance,
    required this.lastTransactionDate,
    this.description,
    this.address,
    this.notes,
    this.isDeleted = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'category': category,
      'balance': balance,
      'lastTransactionDate': lastTransactionDate.toIso8601String(),
      'isDeleted': isDeleted,
      'description': description,
      'address': address,
      'notes': notes,
    };
  }

  factory People.fromMap(Map<String, dynamic> map) {
    return People(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String,
      category: map['category'] as String,
      balance: (map['balance'] as num).toDouble(),
      lastTransactionDate: DateTime.parse(map['lastTransactionDate'] as String),
      description: map['description'],
      address: map['address'],
      notes: map['notes'],
      isDeleted: map['isDeleted'] == null ? 0 : (map['isDeleted'] as int),
    );
  }

  People copyWith({
    int? id,
    String? name,
    String? phone,
    String? category,
    double? balance,
    DateTime? lastTransactionDate,
    String? description,
    String? address,
    String? notes,
    int? isDeleted,
  }) {
    return People(
      id: id ?? this.id,
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
