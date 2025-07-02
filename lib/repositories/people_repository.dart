import 'package:sqflite/sqflite.dart';
import '../models/people.dart';
import '../database/database_helper.dart';

class PeopleRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<int> insertPerson(People person) async {
    final db = await dbHelper.database;
    print('Inserting person: \\n${person.toMap()}');
    final id = await db.insert(
      'people',
      person.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('Inserted person with id: $id');
    return id;
  }

  Future<List<People>> getAllPeople() async {
    final db = await dbHelper.database;
    print('Fetching all people (not deleted)...');
    final List<Map<String, dynamic>> maps = await db.query(
      'people',
      where: 'isDeleted = 0 OR isDeleted IS NULL',
      orderBy: 'name ASC',
    );
    final people = List.generate(maps.length, (i) => People.fromMap(maps[i]));
    print('Fetched ${people.length} people:');
    for (final p in people) {
      print(p.toMap());
    }
    return people;
  }

  Future<People?> getPersonById(int id) async {
    final db = await dbHelper.database;
    print('Fetching person by id: $id');
    final List<Map<String, dynamic>> maps = await db.query(
      'people',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      print('Found person: ${maps.first}');
      return People.fromMap(maps.first);
    }
    print('No person found with id: $id');
    return null;
  }

  Future<List<People>> getPeopleByCategory(String category) async {
    final db = await dbHelper.database;
    print('Fetching people by category: $category (not deleted)');
    final List<Map<String, dynamic>> maps = await db.query(
      'people',
      where: '(isDeleted = 0 OR isDeleted IS NULL) AND category = ?',
      whereArgs: [category],
      orderBy: 'name ASC',
    );
    final people = List.generate(maps.length, (i) => People.fromMap(maps[i]));
    print('Fetched ${people.length} people in category $category:');
    for (final p in people) {
      print(p.toMap());
    }
    return people;
  }

  Future<int> updatePerson(People person) async {
    final db = await dbHelper.database;
    print('Updating person id ${person.id}: \\n${person.toMap()}');
    final count = await db.update(
      'people',
      person.toMap(),
      where: 'id = ?',
      whereArgs: [person.id],
    );
    print('Updated $count record(s)');
    return count;
  }

  Future<int> deletePerson(int id) async {
    final db = await dbHelper.database;
    print('Flagging person as deleted with id: $id');
    final count = await db.update(
      'people',
      {'isDeleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    print('Flagged $count record(s) as deleted');
    return count;
  }
}
