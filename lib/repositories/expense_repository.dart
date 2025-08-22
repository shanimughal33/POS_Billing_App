import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/expense.dart';

class ExpenseRepository extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ExpenseRepository() {
    // Enable offline persistence
    _firestore.settings = const Settings(persistenceEnabled: true);
  }

  /// Real-time stream of all expenses for a user
  Stream<List<Expense>> streamExpenses(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Expense.fromMap(doc.data(), docId: doc.id))
              .toList(),
        );
  }

  /// Insert without waiting for Firestore (offline safe)
  Future<void> insertExpense(Expense expense) async {
    debugPrint(
      'ExpenseRepository: insertExpense for userId=${expense.userId}, expense=$expense',
    );

    _firestore
        .collection('users')
        .doc(expense.userId)
        .collection('expenses')
        .add(expense.toMap())
        .catchError((e) => debugPrint('Insert error: $e'));

    notifyListeners();
  }

  /// Fetch all expenses (blocking)
  Future<List<Expense>> getAllExpenses(String userId) async {
    debugPrint('ExpenseRepository: getAllExpenses for userId=$userId');
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Expense.fromMap(doc.data(), docId: doc.id))
        .toList();
  }

  /// Get expenses by category (blocking)
  Future<List<Expense>> getExpensesByCategory(
    String category,
    String userId,
  ) async {
    debugPrint(
      'ExpenseRepository: getExpensesByCategory for userId=$userId, category=$category',
    );
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .where('category', isEqualTo: category)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Expense.fromMap(doc.data(), docId: doc.id))
        .toList();
  }

  /// Get single expense by ID (blocking)
  Future<Expense?> getExpenseById(String expenseId, String userId) async {
    debugPrint(
      'ExpenseRepository: getExpenseById for userId=$userId, id=$expenseId',
    );
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .doc(expenseId)
        .get();

    if (doc.exists) {
      return Expense.fromMap(doc.data()!, docId: doc.id);
    }
    return null;
  }

  /// Update expense — fire & forget
  Future<void> updateExpense(Expense expense) async {
    if (expense.id == null) {
      debugPrint('updateExpense failed: id is null');
      return;
    }

    debugPrint(
      'ExpenseRepository: updateExpense for userId=${expense.userId}, expense=$expense',
    );

    _firestore
        .collection('users')
        .doc(expense.userId)
        .collection('expenses')
        .doc(expense.id)
        .update(expense.toMap())
        .catchError((e) => debugPrint('Update error: $e'));

    notifyListeners();
  }

  /// Delete expense — fire & forget
  Future<void> deleteExpense(String id, String userId) async {
    debugPrint('ExpenseRepository: deleteExpense for userId=$userId, id=$id');

    _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .doc(id)
        .delete()
        .catchError((e) => debugPrint('Delete error: $e'));

    notifyListeners();
  }

  /// Calculate total expenses
  Future<double> getTotalExpenses(String userId) async {
    debugPrint('ExpenseRepository: getTotalExpenses for userId=$userId');

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .get();

    double total = 0.0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      total += (data['amount'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  /// Total by category
  Future<double> getTotalExpensesByCategory(
    String category,
    String userId,
  ) async {
    debugPrint(
      'ExpenseRepository: getTotalExpensesByCategory for userId=$userId, category=$category',
    );

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .where('category', isEqualTo: category)
        .get();

    double total = 0.0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      total += (data['amount'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }
}
