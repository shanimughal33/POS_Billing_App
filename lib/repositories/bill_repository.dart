import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/bill_item.dart';

class BillRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<BillItem> insertBillItem(BillItem item) async {
    try {
      return await _databaseHelper.withTransaction((txn) async {
        // Get next serial in transaction
        final nextSerial = await txn.rawQuery('''
          SELECT COALESCE(MAX(serialNo), 0) + 1 as nextSerial 
          FROM bill_items WHERE isDeleted = 0
        ''');
        final serialNo = nextSerial.first['nextSerial'] as int? ?? 1;

        final itemMap = {
          'serialNo': serialNo,
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'createdAt': DateTime.now().toIso8601String(),
          'isDeleted': 0,
        };

        final id = await txn.insert('bill_items', itemMap);
        if (id <= 0) throw Exception('Failed to insert item');

        debugPrint('Successfully inserted item with ID: $id');
        return BillItem.fromMap({...itemMap, 'id': id});
      });
    } catch (e) {
      debugPrint('Error inserting item: $e');
      rethrow;
    }
  }

  Future<void> softDeleteItem(int id) async {
    await _databaseHelper.withTransaction((txn) async {
      // First mark the item as deleted
      await txn.rawUpdate(
        'UPDATE bill_items SET isDeleted = 1, deletedAt = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), id],
      );

      // Get all active items
      final activeItems = await txn.query(
        'bill_items',
        where: 'isDeleted = 0',
        orderBy: 'serialNo ASC',
      );

      // Update serial numbers and rename default-named items
      final batch = txn.batch();
      for (int i = 0; i < activeItems.length; i++) {
        final newSerialNo = i + 1;
        final currentName = activeItems[i]['name'] as String;

        // Only rename if it follows the "Item X" pattern
        final String newName = currentName.startsWith('Item ')
            ? 'Item $newSerialNo'
            : currentName;

        batch.rawUpdate(
          'UPDATE bill_items SET serialNo = ?, name = ? WHERE id = ?',
          [newSerialNo, newName, activeItems[i]['id']],
        );
      }
      await batch.commit(noResult: true);
    });
  }

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

  Future<List<BillItem>> getAllBillItems() async {
    try {
      final db = await _databaseHelper.database;

      // First verify the table exists
      final tableCheck = await db.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type='table' AND name='bill_items'
      ''');

      if (tableCheck.isEmpty) {
        debugPrint('Table not found, returning empty list');
        return [];
      }

      // Get all pending items with one query
      final items = await db.rawQuery('''
        SELECT * FROM bill_items 
        WHERE status = 'pending' 
        ORDER BY serialNo ASC, createdAt ASC
      ''');

      debugPrint('Found ${items.length} pending items');

      return items.map((map) => BillItem.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error loading items: $e');
      rethrow;
    }
  }

  Future<void> clearAllBillItems() async {
    final db = await _databaseHelper.database;
    await db.delete('bill_items');
  }

  Future<void> markCurrentItemsAsCompleted() async {
    try {
      final db = await _databaseHelper.database;
      await db.rawUpdate(
        '''
        UPDATE bill_items 
        SET status = 'completed',
            isDeleted = 1, 
            deletedAt = ? 
        WHERE status = 'pending'
      ''',
        [DateTime.now().toIso8601String()],
      );
    } catch (e) {
      debugPrint('Error marking items as completed: $e');
      rethrow;
    }
  }
}
