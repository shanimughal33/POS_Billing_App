import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/inventory_item.dart';
import '../models/bill_item.dart';
import '../repositories/inventory_repository.dart';
import '../utils/refresh_manager.dart';
import 'package:flutter/foundation.dart';

part 'inventory_state.dart';

class InventoryCubit extends Cubit<InventoryState> {
  final InventoryRepository repository;
  List<InventoryItem> _cachedItems = [];
  bool _isLoading = false;

  InventoryCubit(this.repository) : super(InventoryInitial());

  List<InventoryItem> get items => _cachedItems;
  // List<InventoryItem> get unsoldItems =>
  //     _cachedItems.where((item) => item.isSold == false).toList();

  Future<void> loadInventory({
    required String userId,
    bool silent = false,
  }) async {
    debugPrint(
      'InventoryCubit: loadInventory called with userId=$userId, silent=$silent',
    );
    if (_isLoading) return;
    _isLoading = true;

    try {
      if (!silent) emit(InventoryLoading());
      final items = await repository.getAllItems(userId);
      _cachedItems = items;
      debugPrint(
        'InventoryCubit: Loaded ${items.length} items for userId=$userId',
      );
      emit(InventoryLoaded(_cachedItems));
    } catch (e) {
      debugPrint('InventoryCubit: Error in loadInventory: $e');
      emit(InventoryError(e.toString()));
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refreshInventory(String userId) async {
    debugPrint('InventoryCubit: refreshInventory called for userId=$userId');
    await loadInventory(userId: userId, silent: true);
  }

  Future<void> addItem(InventoryItem item, String userId) async {
    debugPrint('InventoryCubit: addItem called for userId=$userId, item=$item');
    try {
      await repository.insertItem(item);
      await loadInventory(userId: userId);
      debugPrint('InventoryCubit: addItem completed for userId=$userId');
      emit(InventoryLoaded(_cachedItems));

      // Trigger refresh for all screens
      RefreshManager().refreshInventory();
    } catch (e) {
      debugPrint('InventoryCubit: Error in addItem: $e');
      if (!isClosed) emit(InventoryError(e.toString()));
    }
  }

  Future<void> updateItem(InventoryItem item, String userId) async {
    debugPrint(
      'InventoryCubit: updateItem called for userId=$userId, item=$item',
    );
    try {
      await repository.updateItem(item);
      await loadInventory(userId: userId);
      debugPrint('InventoryCubit: updateItem completed for userId=$userId');
      emit(InventoryLoaded(_cachedItems));

      // Trigger refresh for all screens
      RefreshManager().refreshInventory();
    } catch (e) {
      debugPrint('InventoryCubit: Error in updateItem: $e');
      if (!isClosed) emit(InventoryError(e.toString()));
    }
  }

  Future<void> deleteItem(String firestoreId, String userId) async {
    debugPrint(
      'InventoryCubit: deleteItem called for userId=$userId, firestoreId=$firestoreId',
    );
    try {
      await repository.deleteItem(firestoreId, userId);
      await loadInventory(userId: userId);
      debugPrint('InventoryCubit: deleteItem completed for userId=$userId');
      emit(InventoryLoaded(_cachedItems));
      // Trigger refresh for all screens
      RefreshManager().refreshInventory();
    } catch (e) {
      debugPrint('InventoryCubit: Error in deleteItem: $e');
      if (!isClosed) emit(InventoryError(e.toString()));
    }
  }

  Future<void> updateInventoryAfterSale(
    List<BillItem> soldItems,
    String userId,
  ) async {
    debugPrint(
      'InventoryCubit: updateInventoryAfterSale called for userId=$userId, soldItems=${soldItems.length}',
    );
    try {
      final currentItems = state is InventoryLoaded
          ? (state as InventoryLoaded).items
          : [];

      for (final sold in soldItems) {
        final idx = currentItems.indexWhere((inv) {
          final invShortcut = (inv.shortcut ?? '').trim().toUpperCase();
          final soldName = (sold.name).trim().toUpperCase();
          final invName = (inv.name).trim().toUpperCase();
          return invShortcut.isNotEmpty && invShortcut == soldName ||
              invName == soldName;
        });

        if (idx != -1) {
          final inv = currentItems[idx];
          final newQty = (inv.quantity - sold.quantity).clamp(
            0,
            double.infinity,
          );

          final shouldMarkAsSold = newQty <= 0;

          final updated = inv.copyWith(
            quantity: newQty,
            isSold: shouldMarkAsSold,
          );

          await repository.updateItem(updated);
        }
      }

      await loadInventory(userId: userId);
      debugPrint(
        'InventoryCubit: updateInventoryAfterSale completed for userId=$userId',
      );
    } catch (e) {
      debugPrint('InventoryCubit: Error in updateInventoryAfterSale: $e');
      if (!isClosed) emit(InventoryError(e.toString()));
    }
  }

  Future<void> saveInventoryItem(InventoryItem item, String userId) async {
    debugPrint(
      'InventoryCubit: saveInventoryItem called for userId=$userId, item=$item',
    );
    try {
      await repository.saveInventoryItem(item);
      await refreshInventory(userId);
      debugPrint(
        'InventoryCubit: saveInventoryItem completed for userId=$userId',
      );

      // Trigger refresh for all screens
      RefreshManager().refreshInventory();
      RefreshManager().refreshDashboard();
    } catch (e) {
      debugPrint('InventoryCubit: Error in saveInventoryItem: $e');
      emit(InventoryError(e.toString()));
    }
  }

  Future<void> deleteInventoryItem(String firestoreId, String userId) async {
    debugPrint(
      'InventoryCubit: deleteInventoryItem called for userId=$userId, firestoreId=$firestoreId',
    );
    try {
      await repository.deleteInventoryItem(firestoreId, userId);
      await refreshInventory(userId);
      debugPrint(
        'InventoryCubit: deleteInventoryItem completed for userId=$userId',
      );
      // Trigger refresh for all screens
      RefreshManager().refreshInventory();
      RefreshManager().refreshDashboard();
    } catch (e) {
      debugPrint('InventoryCubit: Error in deleteInventoryItem: $e');
      emit(InventoryError(e.toString()));
    }
  }

  Future<void> deleteAllInventoryForUser(String userId) async {
    debugPrint(
      'InventoryCubit: deleteAllInventoryForUser called for userId=$userId',
    );
    try {
      await repository.deleteAllForUser(userId);
      await refreshInventory(userId);
      debugPrint(
        'InventoryCubit: deleteAllInventoryForUser completed for userId=$userId',
      );
    } catch (e) {
      debugPrint('InventoryCubit: Error in deleteAllInventoryForUser: $e');
      emit(InventoryError(e.toString()));
    }
  }

  // This method is now deprecated - use updateInventoryAfterSale instead
  // Only mark items as sold when quantity reaches 0
  Future<void> markItemsAsSold(List<String> firestoreIds, String userId) async {
    try {
      for (final firestoreId in firestoreIds) {
        final matches = _cachedItems.where((i) => i.firestoreId == firestoreId);
        if (matches.isNotEmpty) {
          final item = matches.first;
          // Only mark as sold if quantity is 0
          if (item.quantity <= 0) {
            final updated = item.copyWith(isSold: true);
            await repository.updateItem(updated);
          }
        }
      }
      await loadInventory(userId: userId);
      emit(InventoryLoaded(_cachedItems));
    } catch (e) {
      if (!isClosed) emit(InventoryError(e.toString()));
    }
  }
}
