import 'bill_item.dart';

class Bill {
  final String? id;
  final DateTime date;
  final String customerName;
  final String paymentMethod;
  final List<BillItem> items;
  final double subTotal;
  final double discount;
  final double tax;
  final double total;

  Bill({
    this.id,
    required this.date,
    required this.customerName,
    required this.paymentMethod,
    required this.items,
    this.discount = 0,
    this.tax = 0,
  }) : subTotal = items.fold(0.0, (double sum, item) => sum + item.total),
       total =
           items.fold(0.0, (double sum, item) => sum + item.total) +
           (items.fold(0.0, (double sum, item) => sum + item.total) *
               tax /
               100) -
           discount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'customerName': customerName,
      'paymentMethod': paymentMethod,
      'items': items.map((item) => item.toMap()).toList(),
      'subTotal': subTotal,
      'discount': discount,
      'tax': tax,
      'total': total,
    };
  }

  static Bill fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'] as String?,
      date: DateTime.parse(map['date'] as String),
      customerName: map['customerName'] as String,
      paymentMethod: map['paymentMethod'] as String,
      items: (map['items'] as List)
          .map((item) => BillItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      discount: map['discount'] as double,
      tax: map['tax'] as double,
    );
  }
}
