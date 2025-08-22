import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/activity.dart';

class ActivityRepository {
  static final ActivityRepository _instance = ActivityRepository._internal();
  factory ActivityRepository() => _instance;
  ActivityRepository._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'forward_billing.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS activities (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT,
            type TEXT,
            description TEXT,
            timestamp TEXT,
            metadata TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add user_id column if it doesn't exist
          await db.execute('''
            ALTER TABLE activities ADD COLUMN user_id TEXT;
          ''');
        }
      },
    );
  }

  Future<void> logActivity(Activity activity) async {
    final db = await database;
    await db.insert(
      'activities',
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    Activity.notifyNewActivity(activity);
  }

  Future<List<Activity>> getRecentActivities({required String userId, int limit = 20}) async {
    final db = await database;
    final maps = await db.query(
      'activities',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((m) => Activity.fromMap(m)).toList();
  }

  Stream<List<Activity>> getRecentActivitiesStream({required String userId, int limit = 20}) async* {
    while (true) {
      final db = await database;
      final maps = await db.query(
        'activities',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      yield maps.map((m) => Activity.fromMap(m)).toList();
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<List<Activity>> getAllActivities() async {
    final db = await database;
    final maps = await db.query('activities', orderBy: 'timestamp DESC');
    return maps.map((m) => Activity.fromMap(m)).toList();
  }
}
