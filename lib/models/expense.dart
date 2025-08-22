class Expense {
  final String? id; // 🔄 Changed from int? to String?
  final String name;
  final DateTime date;
  final String category;
  final double amount;
  final String paymentMethod;
  final String? vendor;
  final String? referenceNumber;
  final String? description;
  final String userId;

  Expense({
    this.id,
    required this.userId,
    required this.name,
    required this.date,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    this.vendor,
    this.referenceNumber,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'date': date.toIso8601String(),
      'category': category,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'vendor': vendor,
      'referenceNumber': referenceNumber,
      'description': description,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Expense(
      id: docId,
      userId: map['user_id'] ?? '',
      name: map['name'] ?? '',
      date: DateTime.parse(map['date']),
      category: map['category'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] ?? '',
      vendor: map['vendor'],
      referenceNumber: map['referenceNumber'],
      description: map['description'],
    );
  }

  Expense copyWith({
    String? id,
    String? userId,
    String? name,
    DateTime? date,
    String? category,
    double? amount,
    String? paymentMethod,
    String? vendor,
    String? referenceNumber,
    String? description,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      date: date ?? this.date,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      vendor: vendor ?? this.vendor,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      description: description ?? this.description,
    );
  }
}
