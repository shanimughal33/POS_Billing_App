import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/inventory_item.dart';
import '../models/bill_item.dart';
import '../repositories/inventory_repository.dart';

part 'inventory_state.dart';

class InventoryCubit extends Cubit<InventoryState> {
  final InventoryRepository repository;
  List<InventoryItem> _cachedItems = [];
  bool _isLoading = false;

  InventoryCubit(this.repository) : super(InventoryInitial());

  List<InventoryItem> get items => _cachedItems;
  List<InventoryItem> get unsoldItems =>
      _cachedItems.where((item) => item.isSold == false).toList();

  Future<void> loadInventory({bool silent = false}) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      if (!silent) emit(InventoryLoading());
      final items = await repository.getAllItems();
      _cachedItems = items;
      emit(InventoryLoaded(unsoldItems));
    } catch (e) {
      emit(InventoryError(e.toString()));
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refreshInventory() async {
    await loadInventory(silent: true);
  }

  Future<void> addItem(InventoryItem item) async {
    try {
      await repository.insertItem(item);
      await loadInventory();
      emit(InventoryLoaded(unsoldItems));
    } catch (e) {
      if (!isClosed) emit(InventoryError(e.toString()));
    }
  }

  Future<void> updateItem(InventoryItem item) async {
    try {
      await repository.updateItem(item);
      await loadInventory();
      emit(InventoryLoaded(unsoldItems));
    } catch (e) {
      if (!isClosed) emit(InventoryError(e.toString()));
    }
  }

  Future<void> deleteItem(int id) async {
    try {
      await repository.deleteItem(id);
      await loadInventory();
      emit(InventoryLoaded(unsoldItems));
    } catch (e) {
      if (!isClosed) emit(InventoryError(e.toString()));
    }
  }

  Future<void> updateInventoryAfterSale(List<BillItem> soldItems) async {
    try {
      final currentItems = state is InventoryLoaded
          ? (state as InventoryLoaded).items
          : [];

      for (final sold in soldItems) {
        final idx = currentItems.indexWhere((inv) {
          final invShortcut = (inv.shortcut ?? '').trim().toUpperCase();
          final soldName = (sold.name).trim().toUpperCase();
          final invName = (inv.name).trim().toUpperCase();
          // Match by shortcut or by name
          return invShortcut.isNotEmpty && invShortcut == soldName ||
              invName == soldName;
        });

        if (idx != -1) {
          final inv = currentItems[idx];
          final newQty = (inv.quantity - sold.quantity).clamp(
            0,
            double.infinity,
          );

          // Only mark as sold if quantity reaches 0
          final shouldMarkAsSold = newQty <= 0;

          final updated = inv.copyWith(
            quantity: newQty,
            isSold: shouldMarkAsSold, // Mark as sold only when quantity is 0
          );

          await repository.updateItem(updated);
        }
      }

      await loadInventory();
    } catch (e) {
      if (!isClosed) emit(InventoryError(e.toString()));
    }
  }

  Future<void> saveInventoryItem(InventoryItem item) async {
    try {
      await repository.saveInventoryItem(item);
      await refreshInventory();
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  Future<void> deleteInventoryItem(int id) async {
    try {
      await repository.deleteInventoryItem(id);
      await refreshInventory();
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  // This method is now deprecated - use updateInventoryAfterSale instead
  // Only mark items as sold when quantity reaches 0
  Future<void> markItemsAsSold(List<int> itemIds) async {
    try {
      for (final id in itemIds) {
        final matches = _cachedItems.where((i) => i.id == id);
        if (matches.isNotEmpty) {
          final item = matches.first;
          // Only mark as sold if quantity is 0
          if (item.quantity <= 0) {
            final updated = item.copyWith(isSold: true);
            await repository.updateItem(updated);
          }
        }
      }
      await loadInventory();
      emit(InventoryLoaded(unsoldItems));
    } catch (e) {
      if (!isClosed) emit(InventoryError(e.toString()));
    }
  }
}
