import '../database/database_helper.dart';
import '../models/inventory_item.dart';
import 'package:flutter/foundation.dart';
import '../repositories/activity_repository.dart';
import '../models/activity.dart';

class InventoryRepository extends ChangeNotifier {
  final dbHelper = DatabaseHelper.instance;

  Future<List<InventoryItem>> getAllItems() async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'inventory',
      where: 'isSold = 0',
      orderBy: 'name ASC',
    );
    return maps.map((map) => InventoryItem.fromMap(map)).toList();
  }

  Future<int> insertItem(InventoryItem item) async {
    final db = await dbHelper.database;
    final normalizedItem = item.copyWith(
      shortcut: item.shortcut?.trim().toUpperCase(),
    );
    final result = await db.insert('inventory', normalizedItem.toMap());
    notifyListeners();
    // Log activity
    await ActivityRepository().logActivity(
      Activity(
        type: 'inventory_add',
        description: 'Added inventory item: ${item.name}',
        timestamp: DateTime.now(),
        metadata: item.toMap(),
      ),
    );
    return result;
  }

  Future<int> updateItem(InventoryItem item) async {
    final db = await dbHelper.database;
    final normalizedItem = item.copyWith(
      shortcut: item.shortcut?.trim().toUpperCase(),
    );
    final result = await db.update(
      'inventory',
      normalizedItem.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    notifyListeners();
    // Log activity
    await ActivityRepository().logActivity(
      Activity(
        type: 'inventory_edit',
        description: 'Edited inventory item: ${item.name}',
        timestamp: DateTime.now(),
        metadata: item.toMap(),
      ),
    );
    return result;
  }

  Future<int> deleteItem(int id) async {
    final db = await dbHelper.database;
    // Get item details before deleting for logging
    final items = await db.query('inventory', where: 'id = ?', whereArgs: [id]);
    final result = await db.delete('inventory', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
    // Log activity
    if (items.isNotEmpty) {
      await ActivityRepository().logActivity(
        Activity(
          type: 'inventory_delete',
          description: 'Deleted inventory item: ${items.first['name']}',
          timestamp: DateTime.now(),
          metadata: items.first,
        ),
      );
    }
    return result;
  }

  Future<List<InventoryItem>> searchItems(String query) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'inventory',
      where: 'name LIKE ? AND isSold = 0',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map((map) => InventoryItem.fromMap(map)).toList();
  }

  Future<void> deleteInventoryItem(int id) async {
    final db = await dbHelper.database;
    await db.delete('inventory', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  Future<void> saveInventoryItem(InventoryItem item) async {
    await dbHelper.insertInventoryItem(item);
    notifyListeners();
  }
}
