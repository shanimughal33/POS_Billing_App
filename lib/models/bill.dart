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
  final bool isDeleted;

  Bill({
    this.id,
    required this.date,
    required this.customerName,
    required this.paymentMethod,
    required this.items,
    double? subTotal,
    this.discount = 0,
    this.tax = 0,
    double? total,
    this.isDeleted = false,
  }) : subTotal =
           subTotal ?? items.fold(0.0, (double sum, item) => sum + item.total),
       total =
           total ??
           (items.fold(0.0, (double sum, item) => sum + item.total) +
               (items.fold(0.0, (double sum, item) => sum + item.total) *
                   tax /
                   100) -
               discount);

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
      'isDeleted': isDeleted,
    };
  }

  static Bill fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'] as String?,
      date: DateTime.parse(map['date'] as String),
      customerName: map['customerName'] as String,
      paymentMethod: map['paymentMethod'] as String,
      items:
          (map['items'] as List?)
              ?.map((item) => BillItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      subTotal: (map['subTotal'] as num?)?.toDouble(),
      discount: map['discount'] is double
          ? map['discount']
          : (map['discount'] as num?)?.toDouble() ?? 0.0,
      tax: map['tax'] is double
          ? map['tax']
          : (map['tax'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble(),
      isDeleted: (map['isDeleted'] is int
          ? map['isDeleted'] == 1
          : map['isDeleted'] == true),
    );
  }

  Bill copyWith({
    String? id,
    DateTime? date,
    String? customerName,
    String? paymentMethod,
    List<BillItem>? items,
    double? discount,
    double? tax,
    bool? isDeleted,
  }) {
    return Bill(
      id: id ?? this.id,
      date: date ?? this.date,
      customerName: customerName ?? this.customerName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items ?? this.items,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
