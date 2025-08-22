import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/people.dart';

class PeopleRepository extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PeopleRepository() {
    // Make sure Firestore works offline
    _firestore.settings = const Settings(persistenceEnabled: true);
  }

  /// Real-time stream of all active people for a user
  Stream<List<People>> getPeopleStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('people')
        .where('isDeleted', isEqualTo: false)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => People.fromMap({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }

  /// Add a new person — store instantly without awaiting Firestore response
  Future<String> insertPerson(People person) async {
    final ref = _firestore
        .collection('users')
        .doc(person.userId)
        .collection('people')
        .doc();

    // Firestore will store offline if no network
    ref.set({...person.toMap(), 'isDeleted': false}).catchError((e) {
      debugPrint('Firestore insert error: $e');
    });

    notifyListeners();
    return ref.id; // return generated ID
  }

  /// Fetch all active people for a user (single read)
  Future<List<People>> getAllPeople(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('people')
          .where('isDeleted', isEqualTo: false)
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return People.fromMap({...data, 'id': doc.id});
      }).toList();
    } catch (e) {
      debugPrint('Error fetching people: $e');
      return [];
    }
  }

  /// Get a single person by Firestore doc ID
  Future<People?> getPersonById(String docId, String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('people')
          .doc(docId)
          .get();

      if (doc.exists) {
        return People.fromMap({...doc.data()!, 'id': doc.id});
      }
    } catch (e) {
      debugPrint('Error fetching person: $e');
    }
    return null;
  }

  /// Fetch people filtered by category
  Future<List<People>> getPeopleByCategory(
    String category,
    String userId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('people')
          .where('category', isEqualTo: category)
          .where('isDeleted', isEqualTo: false)
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) {
        return People.fromMap({...doc.data(), 'id': doc.id});
      }).toList();
    } catch (e) {
      debugPrint('Error fetching people by category: $e');
      return [];
    }
  }

  /// Update a person — don't await
  Future<void> updatePerson(People person) async {
    if (person.id == null) return;

    _firestore
        .collection('users')
        .doc(person.userId)
        .collection('people')
        .doc(person.id!)
        .update(person.toMap())
        .catchError((e) => debugPrint('Update error: $e'));

    notifyListeners();
  }

  /// Soft delete person — no await
  Future<void> deletePerson(String docId, String userId) async {
    _firestore
        .collection('users')
        .doc(userId)
        .collection('people')
        .doc(docId)
        .update({'isDeleted': true})
        .catchError((e) => debugPrint('Delete error: $e'));

    notifyListeners();
  }
}
