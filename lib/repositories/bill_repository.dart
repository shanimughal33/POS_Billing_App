// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings

import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/bill_item.dart';
import '../models/bill.dart';

class BillRepository extends ChangeNotifier {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  // Insert a Bill and its items in a transaction with proper foreign key relationship
  Future<int> insertBillWithItems(Bill bill) async {
    return await _databaseHelper.withTransaction((txn) async {
      // Step 1: Insert Bill first
      final billMap = {
        'billNumber': bill.id ?? '',
        'customerName': bill.customerName,
        'paymentMethod': bill.paymentMethod,
        'date': bill.date.toIso8601String(),
        'subTotal': bill.subTotal,
        'discount': bill.discount,
        'tax': bill.tax,
        'total': bill.total,
      };

      print('[DEBUG] Inserting bill: ' + billMap.toString());
      final billId = await txn.insert('bills', billMap);
      print('[DEBUG] Inserted bill with ID: $billId');

      // Step 2: Insert all BillItems with the correct billId
      int serial = 1;
      print('[DEBUG] Bill items count: ' + bill.items.length.toString());

      for (final item in bill.items) {
        print('[DEBUG] Processing item: ' + item.toMap().toString());

        // Validate item data
        if (item.name.trim().isEmpty || item.price <= 0 || item.quantity <= 0) {
          print('[DEBUG] Skipping invalid item: ' + item.name);
          continue;
        }

        // Create item map with the correct billId
        final itemMap = {
          'billId': billId, // This is the key - link to the bill
          'serialNo': serial,
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'createdAt': DateTime.now().toIso8601String(),
          'isDeleted': 0,
        };

        print('[DEBUG] Inserting bill item: ' + itemMap.toString());
        final itemId = await txn.insert('bill_items', itemMap);
        print(
          '[DEBUG] Successfully inserted item with ID: $itemId and billId: $billId',
        );

        serial++;
      }

      return billId;
    });
  }

  // Fetch all Bills with their items
  Future<List<Bill>> getAllBills() async {
    final db = await _databaseHelper.database;
    final billRows = await db.query(
      'bills',
      where: 'isDeleted = 0',
      orderBy: 'date DESC',
    );

    List<Bill> bills = [];
    for (final row in billRows) {
      print('[DEBUG] getAllBills row: ' + row.toString());
      final billId = row['id'] as int;
      final items = await getBillItems(billId);
      print('[DEBUG] Found ${items.length} items for bill $billId');

      bills.add(
        Bill(
          id: row['id'].toString(),
          date: DateTime.parse(row['date'] as String),
          customerName: row['customerName'] as String,
          paymentMethod: row['paymentMethod'] as String,
          items: items,
          discount: (row['discount'] as num?)?.toDouble() ?? 0.0,
          tax: (row['tax'] as num?)?.toDouble() ?? 0.0,
          subTotal: (row['subTotal'] as num?)?.toDouble(),
          total: (row['total'] as num?)?.toDouble(),
          isDeleted: (row['isDeleted'] is int
              ? row['isDeleted'] == 1
              : row['isDeleted'] == true),
        ),
      );
    }
    return bills;
  }

  // Fetch BillItems for a specific Bill
  Future<List<BillItem>> getBillItems(int billId) async {
    print('[DEBUG] getBillItems called with billId: $billId');
    final db = await _databaseHelper.database;

    // Use a raw query to ensure we get all items for this bill
    final items = await db.rawQuery(
      'SELECT * FROM bill_items WHERE billId = ? AND isDeleted = 0 ORDER BY serialNo ASC',
      [billId],
    );

    print('[DEBUG] getBillItems raw result: ' + items.toString());

    return items.map((map) {
      print('[DEBUG] Creating BillItem from map: ' + map.toString());
      return BillItem.fromMap(map);
    }).toList();
  }

  // Get all bill items (for reports)
  Future<List<BillItem>> getAllBillItems() async {
    try {
      print('[DEBUG] getAllBillItems called');
      final db = await _databaseHelper.database;

      // Get all active items
      final items = await db.rawQuery('''
        SELECT * FROM bill_items 
        WHERE isDeleted = 0 
        ORDER BY serialNo ASC, createdAt ASC
      ''');

      print('[DEBUG] Found ${items.length} active items: ' + items.toString());
      return items.map((map) => BillItem.fromMap(map)).toList();
    } catch (e) {
      print('[DEBUG] Error loading items: $e');
      rethrow;
    }
  }

  // Get all sold items (for reports)
  Future<List<BillItem>> getAllSoldItems() async {
    final db = await _databaseHelper.database;
    final items = await db.query(
      'bill_items',
      where: 'billId IS NOT NULL AND isDeleted = 0',
      orderBy: 'createdAt DESC',
    );
    return items.map((map) => BillItem.fromMap(map)).toList();
  }

  // Soft delete a bill
  Future<void> softDeleteBill(int billId) async {
    final db = await _databaseHelper.database;
    await db.update(
      'bills',
      {'isDeleted': 1},
      where: 'id = ?',
      whereArgs: [billId],
    );
  }

  // Update a bill item
  Future<void> updateBillItem(BillItem item) async {
    await _databaseHelper.withTransaction((txn) async {
      if (item.id == null) throw Exception('Cannot update item without ID');

      final itemMap = {
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final result = await txn.update(
        'bill_items',
        itemMap,
        where: 'id = ? AND isDeleted = 0',
        whereArgs: [item.id],
      );

      if (result <= 0) throw Exception('Failed to update item');
    });
  }

  // Clear all bill items (for testing)
  Future<void> clearAllBillItems() async {
    final db = await _databaseHelper.database;
    await db.delete('bill_items');
  }
}
