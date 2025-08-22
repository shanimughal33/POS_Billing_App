import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_item.dart';

class FirebaseStorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper to access user's inventory collection
  CollectionReference<Map<String, dynamic>> _userInventory(String userId) {
    return _firestore.collection('users').doc(userId).collection('inventory');
  }

  /// Adds item to Firestore under correct user
  Future<DocumentReference> addItem(InventoryItem item) async {
    return await _userInventory(item.userId).add(item.toFirestore());
  }

  /// Updates Firestore document using its Firestore ID
  Future<void> updateItem(InventoryItem item) async {
    if (item.firestoreId == null) {
      throw Exception('Cannot update: Firestore ID is null.');
    }

    await _userInventory(
      item.userId,
    ).doc(item.firestoreId).update(item.toFirestore());
  }

  /// Deletes Firestore item by firestoreId
  Future<void> deleteItem(String userId, String firestoreId) async {
    await _userInventory(userId).doc(firestoreId).delete();
  }

  /// Real-time stream of items for specific user
  Stream<List<InventoryItem>> getItemsForUser(String userId) {
    return _userInventory(userId).orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return InventoryItem.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }
}
