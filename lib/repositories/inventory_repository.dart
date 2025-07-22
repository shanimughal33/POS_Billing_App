import '../database/database_helper.dart';
import '../models/inventory_item.dart';

class InventoryRepository {
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
    return await db.insert('inventory', normalizedItem.toMap());
  }

  Future<int> updateItem(InventoryItem item) async {
    final db = await dbHelper.database;
    final normalizedItem = item.copyWith(
      shortcut: item.shortcut?.trim().toUpperCase(),
    );
    return await db.update(
      'inventory',
      normalizedItem.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await dbHelper.database;
    return await db.delete('inventory', where: 'id = ?', whereArgs: [id]);
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
  }

  Future<void> saveInventoryItem(InventoryItem item) async {
    await dbHelper.insertInventoryItem(item);
  }
}
