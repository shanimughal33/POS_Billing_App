import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import '../models/inventory_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  // Mutex for serializing DB writes
  Future<void> _writeLock = Future.value();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'forward_billing.db');

      _database = await openDatabase(
        path,
        version: 2,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          debugPrint('Database opened successfully');
          await db.rawQuery('PRAGMA journal_mode=WAL');
          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='bill_items'",
          );
          debugPrint('Found ${tables.length} tables');
        },
      );

      return _database!;
    } catch (e) {
      debugPrint('Database initialization error: $e');
      rethrow;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add status column to bill_items table
      await db.execute('''
        ALTER TABLE bill_items 
        ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'
      ''');

      // Update existing completed items
      await db.execute('''
        UPDATE bill_items 
        SET status = 'completed' 
        WHERE isDeleted = 1
      ''');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Create bill_items table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bill_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        serialNo INTEGER NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        createdAt TEXT NOT NULL,
        deletedAt TEXT NULL,
        updatedAt TEXT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create inventory table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity REAL NOT NULL,
        initialQuantity REAL,
        shortcut TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Simple indices for common queries
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_active_items ON bill_items(isDeleted, serialNo)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inventory_name ON inventory(name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bill_status ON bill_items(status)',
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  // Serializes all DB writes to avoid lock contention
  Future<T> withWriteLock<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeLock = _writeLock.then(
      (_) =>
          action().then(completer.complete).catchError(completer.completeError),
    );
    return completer.future;
  }

  Future<T> withTransaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    final db = await database;
    // Only serialize writes, not reads
    return await withWriteLock(
      () => db.transaction((txn) => action(txn), exclusive: true),
    );
  }

  Future<void> reorderSerialNumbersInTxn(Transaction txn) async {
    // Reset all serials in one query
    await txn.rawUpdate('UPDATE bill_items SET serialNo = 0');
    final activeItems = await txn.query(
      'bill_items',
      where: 'isDeleted = 0',
      orderBy: 'serialNo ASC, createdAt ASC',
    );
    final batch = txn.batch();
    for (int i = 0; i < activeItems.length; i++) {
      batch.rawUpdate('UPDATE bill_items SET serialNo = ? WHERE id = ?', [
        i + 1,
        activeItems[i]['id'],
      ]);
    }
    await batch.commit(noResult: true);
  }

  Future<int> getNextSerialNumberInTxn(Transaction txn) async {
    final result = await txn.rawQuery('''
      SELECT COALESCE(MAX(serialNo), 0) + 1 as nextSerial 
      FROM bill_items 
      WHERE isDeleted = 0
    ''');
    return (result.first['nextSerial'] as int?) ?? 1;
  }

  Future<int> insertInventoryItem(InventoryItem item) async {
    final db = await database;
    final values = item.toMap();
    // Ensure initialQuantity is set if not provided
    values['initialQuantity'] = values['initialQuantity'] ?? values['quantity'];
    return await db.insert(
      'inventory',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<InventoryItem>> getInventoryItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inventory',
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => InventoryItem.fromMap(maps[i]));
  }
}
