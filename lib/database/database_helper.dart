// ignore_for_file: avoid_print

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
      final path = join(dbPath, 'billing.db');

      print('Initializing database at: $path');

      _database = await openDatabase(
        path,
        version: 10, // Increment version to trigger schema update
        onCreate: (db, version) async {
          print('Creating new database...');
          await _createDB(db, version);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          print('Upgrading database from version $oldVersion to $newVersion');
          await _upgradeDB(db, oldVersion, newVersion);
        },
        onOpen: (db) async {
          print('Database opened successfully');
          // Enable foreign key constraints
          await db.execute('PRAGMA foreign_keys = ON');
          print('Foreign key constraints enabled');
        },
      );

      return _database!;
    } catch (e) {
      print('Database initialization error: $e');
      rethrow;
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Create bills table first
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        billNumber TEXT,
        customerName TEXT NOT NULL,
        paymentMethod TEXT NOT NULL,
        date TEXT NOT NULL,
        subTotal REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create bill_items table with proper foreign key constraint
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bill_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        billId INTEGER NOT NULL,
        serialNo INTEGER NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity REAL NOT NULL,
        createdAt TEXT NOT NULL,
        deletedAt TEXT NULL,
        updatedAt TEXT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (billId) REFERENCES bills(id) ON DELETE CASCADE
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
        isSold INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    // Create people table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS people (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        category TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        lastTransactionDate TEXT NOT NULL,
        description TEXT,
        address TEXT,
        notes TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create expenses table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        paymentMethod TEXT NOT NULL,
        vendor TEXT,
        referenceNumber TEXT,
        description TEXT
      )
    ''');

    // Create indexes
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bill_items_billId ON bill_items(billId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bill_items_isDeleted ON bill_items(isDeleted)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bills_isDeleted ON bills(isDeleted)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inventory_name ON inventory(name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date)',
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add the inventory table if upgrading from v1
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
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inventory_name ON inventory(name)',
      );
      await db.execute(
        'UPDATE inventory SET initialQuantity = quantity WHERE initialQuantity IS NULL',
      );
    }

    if (oldVersion < 3) {
      // Add shortcut column if upgrading from v2
      try {
        await db.execute('ALTER TABLE inventory ADD COLUMN shortcut TEXT');
      } catch (e) {
        print('Shortcut column might already exist: $e');
      }
    }

    if (oldVersion < 4) {
      // Create people table
      await db.execute('''
              CREATE TABLE IF NOT EXISTS people (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                phone TEXT NOT NULL,
                category TEXT NOT NULL,
          balance REAL NOT NULL DEFAULT 0,
                lastTransactionDate TEXT NOT NULL,
          description TEXT,
          address TEXT,
          notes TEXT,
                isDeleted INTEGER NOT NULL DEFAULT 0
              )
            ''');
    }

    if (oldVersion < 5) {
      // Add isDeleted column to people if not present
      try {
        final columns = await db.rawQuery('PRAGMA table_info(people)');
        final hasIsDeleted = columns.any((col) => col['name'] == 'isDeleted');
        if (!hasIsDeleted) {
          await db.execute(
            'ALTER TABLE people ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0',
          );
        }
      } catch (e) {
        print('Error checking/adding isDeleted column: $e');
      }
    }

    if (oldVersion < 6) {
      // Add expenses table
      await db.execute('''
              CREATE TABLE IF NOT EXISTS expenses (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                date TEXT NOT NULL,
                category TEXT NOT NULL,
                amount REAL NOT NULL,
                paymentMethod TEXT NOT NULL,
                vendor TEXT,
                referenceNumber TEXT,
                description TEXT
              )
            ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date)',
      );
    }

    if (oldVersion < 7) {
      // Add new fields to people table
      try {
        await db.execute('ALTER TABLE people ADD COLUMN description TEXT');
        await db.execute('ALTER TABLE people ADD COLUMN address TEXT');
        await db.execute('ALTER TABLE people ADD COLUMN notes TEXT');
      } catch (e) {
        print('Error adding new people fields: $e');
      }
    }

    if (oldVersion < 8) {
      // Add name column to expenses
      try {
        await db.execute(
          'ALTER TABLE expenses ADD COLUMN name TEXT NOT NULL DEFAULT "Expense"',
        );
      } catch (e) {
        print('Error adding name column to expenses: $e');
      }
    }

    if (oldVersion < 9) {
      // Create bills table with proper structure
      await db.execute('''
              CREATE TABLE IF NOT EXISTS bills (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                billNumber TEXT,
          customerName TEXT NOT NULL,
          paymentMethod TEXT NOT NULL,
          date TEXT NOT NULL,
          subTotal REAL NOT NULL DEFAULT 0,
          discount REAL NOT NULL DEFAULT 0,
          tax REAL NOT NULL DEFAULT 0,
          total REAL NOT NULL DEFAULT 0,
          isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

      // Create bill_items table with proper foreign key
      await db.execute('''
      CREATE TABLE IF NOT EXISTS bill_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
          billId INTEGER NOT NULL,
        serialNo INTEGER NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity REAL NOT NULL,
        createdAt TEXT NOT NULL,
        deletedAt TEXT NULL,
        updatedAt TEXT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (billId) REFERENCES bills(id) ON DELETE CASCADE
      )
    ''');

      // Create indexes for bills and bill_items
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bill_items_billId ON bill_items(billId)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bill_items_isDeleted ON bill_items(isDeleted)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bills_isDeleted ON bills(isDeleted)',
      );
    }

    if (oldVersion < 10) {
      // Ensure foreign key constraints are properly set up
      try {
        // Drop and recreate bill_items table to ensure proper foreign key constraint
        await db.execute('DROP TABLE IF EXISTS bill_items');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS bill_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
            billId INTEGER NOT NULL,
            serialNo INTEGER NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity REAL NOT NULL,
            createdAt TEXT NOT NULL,
            deletedAt TEXT NULL,
            updatedAt TEXT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (billId) REFERENCES bills(id) ON DELETE CASCADE
      )
    ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_bill_items_billId ON bill_items(billId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_bill_items_isDeleted ON bill_items(isDeleted)',
        );
        print('Recreated bill_items table with proper foreign key constraint');
      } catch (e) {
        print('Error recreating bill_items table: $e');
      }
    }

    if (oldVersion < 11) {
      // Add isSold column to inventory if not present
      try {
        await db.execute(
          'ALTER TABLE inventory ADD COLUMN isSold INTEGER NOT NULL DEFAULT 0',
        );
      } catch (e) {
        print('isSold column might already exist: ' + e.toString());
      }
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  // Method to reset database cache (useful for testing)
  Future<void> resetDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Method to delete and recreate database (for testing)
  Future<void> deleteDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'billing.db');

    try {
      await databaseFactory.deleteDatabase(path);
      print('Database deleted successfully');
    } catch (e) {
      print('Error deleting database: $e');
    }
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
