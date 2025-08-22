import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/inventory_item.dart';
import '../repositories/activity_repository.dart';
import '../models/activity.dart';

class InventoryRepository extends ChangeNotifier {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Stream<List<InventoryItem>> streamFilteredItems(
    String userId, {
    String sortBy = 'name',
    bool descending = false,
    bool lowStockOnly = false,
    int lowStockThreshold = 5,
  }) {
    Query query = firestore
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .where('isDeleted', isEqualTo: false);

    if (lowStockOnly) {
      query = query.where('quantity', isLessThanOrEqualTo: lowStockThreshold);
    }

    query = query.orderBy(sortBy, descending: descending);

    return query.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map(
            (doc) => InventoryItem.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
      return items;
    });
  }

  Stream<List<InventoryItem>> streamItems(String userId) {
    return firestore
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .where('isDeleted', isEqualTo: false)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => InventoryItem.fromFirestore(doc.data(), doc.id))
              .toList();
          return items;
        });
  }

  Future<List<InventoryItem>> getAllItems(String userId) async {
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .where('isDeleted', isEqualTo: false)
        .orderBy('name')
        .get();

    return snapshot.docs
        .map((doc) => InventoryItem.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<void> insertItem(InventoryItem item) async {
    try {
      final normalizedItem = item.copyWith(
        shortcut: item.shortcut?.trim().toUpperCase(),
      );

      notifyListeners(); // ✅ Immediately notify UI before Firestore call

      firestore
          .collection('users')
          .doc(item.userId)
          .collection('inventory')
          .add(normalizedItem.toFirestore())
          .then((_) {
            ActivityRepository().logActivity(
              Activity(
                userId: item.userId,
                type: 'inventory_add',
                description: 'Added inventory item: ${item.name}',
                timestamp: DateTime.now(),
                metadata: normalizedItem.toFirestore(),
              ),
            );
          })
          .catchError((e) {
            debugPrint('Firestore error on insertItem: $e');
          });
    } catch (e, st) {
      debugPrint('Error in insertItem (sync): $e\n$st');
    }
  }

  Future<void> updateItem(InventoryItem item) async {
    try {
      final normalizedItem = item.copyWith(
        shortcut: item.shortcut?.trim().toUpperCase(),
      );

      notifyListeners(); // ✅ Let UI proceed immediately

      if (item.firestoreId != null) {
        firestore
            .collection('users')
            .doc(item.userId)
            .collection('inventory')
            .doc(item.firestoreId)
            .update(normalizedItem.toFirestore());
      } else {
        firestore
            .collection('users')
            .doc(item.userId)
            .collection('inventory')
            .where('name', isEqualTo: item.name)
            .get()
            .then((query) {
              if (query.docs.isNotEmpty) {
                query.docs.first.reference.update(normalizedItem.toFirestore());
              }
            });
      }

      ActivityRepository().logActivity(
        Activity(
          userId: item.userId,
          type: 'inventory_edit',
          description: 'Edited inventory item: ${item.name}',
          timestamp: DateTime.now(),
          metadata: normalizedItem.toFirestore(),
        ),
      );
    } catch (e, st) {
      debugPrint('Error in updateItem (sync): $e\n$st');
    }
  }

  Future<void> deleteItem(String firestoreId, String userId) async {
    try {
      notifyListeners(); // ✅ Let UI reflect deletion immediately

      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .doc(firestoreId);

      docRef
          .update({'isDeleted': true})
          .then((_) async {
            final snapshot = await docRef.get();
            final item = InventoryItem.fromFirestore(
              snapshot.data()!,
              snapshot.id,
            );

            await ActivityRepository().logActivity(
              Activity(
                userId: userId,
                type: 'inventory_delete',
                description: 'Deleted inventory item: ${item.name}',
                timestamp: DateTime.now(),
                metadata: item.toFirestore(),
              ),
            );
          })
          .catchError((e) {
            debugPrint('Error deleting item: $e');
          });
    } catch (e, st) {
      debugPrint('Error in deleteItem (sync): $e\n$st');
    }
  }

  Future<List<InventoryItem>> searchItems(String query, String userId) async {
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .where('isDeleted', isEqualTo: false)
        .orderBy('name')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .get();

    return snapshot.docs
        .map((doc) => InventoryItem.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<void> deleteAllForUser(String userId) async {
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .get();

    for (var doc in snapshot.docs) {
      doc.reference.update({'isDeleted': true});
    }

    notifyListeners(); // ✅ Instant feedback
  }

  // Additional filters remain unchanged
  Future<List<InventoryItem>> getItemsSortedByName(String userId) async =>
      getAllItems(userId);

  Future<List<InventoryItem>> getItemsSortedByQuantity(String userId) async {
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .where('isDeleted', isEqualTo: false)
        .orderBy('quantity', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => InventoryItem.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<List<InventoryItem>> getLowStockItems(
    String userId, {
    int threshold = 5,
  }) async {
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .where('isDeleted', isEqualTo: false)
        .where('quantity', isLessThanOrEqualTo: threshold)
        .orderBy('quantity')
        .get();

    return snapshot.docs
        .map((doc) => InventoryItem.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<bool> isShortcutTaken(
    String userId,
    String shortcut, {
    String? excludeId,
  }) async {
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .where('isDeleted', isEqualTo: false)
        .where('shortcut', isEqualTo: shortcut.trim().toUpperCase())
        .get();

    return snapshot.docs.any((doc) => doc.id != excludeId);
  }

  Future<List<InventoryItem>> getFilteredItems(
    String userId, {
    String sortBy = 'name',
    bool descending = false,
    bool lowStockOnly = false,
    int lowStockThreshold = 5,
  }) async {
    Query query = firestore
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .where('isDeleted', isEqualTo: false);

    if (lowStockOnly) {
      query = query.where('quantity', isLessThanOrEqualTo: lowStockThreshold);
    }

    query = query.orderBy(sortBy, descending: descending);

    final snapshot = await query.get();

    return snapshot.docs
        .map(
          (doc) => InventoryItem.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  // 🔁 Aliases
  Future<void> saveInventoryItem(InventoryItem item) async {
    await insertItem(item);
  }

  Future<void> deleteInventoryItem(String firestoreId, String userId) async {
    await deleteItem(firestoreId, userId);
  }
}
