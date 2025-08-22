// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/bill_item.dart';
import '../models/bill.dart';

class BillRepository extends ChangeNotifier {
  /// Real-time stream of all active bills for a user
  Stream<List<Bill>> streamBills(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('bills')
        .where('isDeleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Bill(
          id: doc.id,
          date: DateTime.parse(data['date']),
          customerName: data['customerName'],
          paymentMethod: data['paymentMethod'],
          items: [], // Items will be loaded on-demand
          discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
          tax: (data['tax'] as num?)?.toDouble() ?? 0.0,
          subTotal: (data['subTotal'] as num?)?.toDouble(),
          total: (data['total'] as num?)?.toDouble(),
          isDeleted: data['isDeleted'] ?? false,
        );
      }).toList();
    });
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Insert a Bill and its items into Firestore
  Future<String> insertBillWithItems(Bill bill, String userId) async {
    final billRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('bills')
        .doc();
    final billId = billRef.id;

    final billMap = {
      'id': billId,
      'customerName': bill.customerName,
      'paymentMethod': bill.paymentMethod,
      'date': bill.date.toIso8601String(),
      'subTotal': bill.subTotal,
      'discount': bill.discount,
      'tax': bill.tax,
      'total': bill.total,
      'isDeleted': false,
    };

    final batch = _firestore.batch();
    batch.set(billRef, billMap);

    for (int i = 0; i < bill.items.length; i++) {
      final item = bill.items[i];
      if (item.name.trim().isEmpty || item.price <= 0 || item.quantity <= 0) {
        continue;
      }

      final itemRef = billRef.collection('items').doc();
      batch.set(itemRef, {
        'serialNo': i + 1,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'createdAt': DateTime.now().toIso8601String(),
        'isDeleted': false,
      });
    }

    // Fire-and-forget: do not await, support offline
    batch.commit().catchError((e) {
      debugPrint('Error inserting bill (may be offline): $e');
    });
    notifyListeners();
    return billId;
  }

  // Fetch all Bills with their items
  Future<List<Bill>> getAllBills(String userId) async {
    try {
      final billsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bills')
          .where('isDeleted', isEqualTo: false)
          .orderBy('date', descending: true)
          .get();

      final List<Bill> bills = [];

      for (final doc in billsSnapshot.docs) {
        final data = doc.data();
        final items = await getBillItems(userId, doc.id);

        bills.add(
          Bill(
            id: doc.id,
            date: DateTime.parse(data['date']),
            customerName: data['customerName'],
            paymentMethod: data['paymentMethod'],
            items: items,
            discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
            tax: (data['tax'] as num?)?.toDouble() ?? 0.0,
            subTotal: (data['subTotal'] as num?)?.toDouble(),
            total: (data['total'] as num?)?.toDouble(),
            isDeleted: data['isDeleted'] ?? false,
          ),
        );
      }
      return bills;
    } catch (e) {
      debugPrint('Error fetching bills: $e');
      rethrow;
    }
  }

  // Fetch BillItems for a specific Bill
  Stream<List<BillItem>> streamBillItems(String userId, String billId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('bills')
        .doc(billId)
        .collection('items')
        .where('isDeleted', isEqualTo: false)
        .orderBy('serialNo')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => BillItem.fromMap(doc.data())).toList());
  }

  Future<List<BillItem>> getBillItems(String userId, String billId) async {
    try {
      final itemsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bills')
          .doc(billId)
          .collection('items')
          .where('isDeleted', isEqualTo: false)
          .orderBy('serialNo')
          .get();

      return itemsSnapshot.docs
          .map((doc) => BillItem.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching bill items: $e');
      rethrow;
    }
  }

  // Soft delete a bill
  Future<void> softDeleteBill(String userId, String billId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bills')
          .doc(billId)
          .update({'isDeleted': true});
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting bill: $e');
      rethrow;
    }
  }

  // Update a bill item
  Future<void> updateBillItem(
    String userId,
    String billId,
    BillItem item,
  ) async {
    try {
      if (item.id == null) throw Exception('Cannot update item without ID');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bills')
          .doc(billId)
          .collection('items')
          .doc(item.id as String?)
          .update({
            'name': item.name,
            'price': item.price,
            'quantity': item.quantity,
            'updatedAt': DateTime.now().toIso8601String(),
          });

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating item: $e');
      rethrow;
    }
  }

  // Clear all bill items (for testing)
  Future<void> clearAllBillItems(String userId, String billId) async {
    final itemsRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('bills')
        .doc(billId)
        .collection('items');

    final snapshot = await itemsRef.get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // Fetch all bill items across all bills for user (reporting)
  Future<List<BillItem>> getAllBillItemsForUser(String userId) async {
    try {
      final billsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bills')
          .get();

      List<BillItem> allItems = [];

      for (final bill in billsSnapshot.docs) {
        final items = await bill.reference.collection('items').get();
        allItems.addAll(
          items.docs.map((doc) => BillItem.fromMap(doc.data())).toList(),
        );
      }

      return allItems;
    } catch (e) {
      debugPrint('Error fetching all bill items: $e');
      rethrow;
    }
  }
}
