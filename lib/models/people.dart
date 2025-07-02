class People {
  final int? id;
  final String name;
  final String phone;
  final String category; // customer, supplier, or custom
  final double balance;
  final DateTime lastTransactionDate;
  final int isDeleted;

  People({
    this.id,
    required this.name,
    required this.phone,
    required this.category,
    required this.balance,
    required this.lastTransactionDate,
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
      isDeleted: map['isDeleted'] == null ? 0 : (map['isDeleted'] as int),
    );
  }
}
