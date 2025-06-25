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

  Future<void> loadInventory({bool silent = false}) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      if (!silent) emit(InventoryLoading());
      final items = await repository.getAllItems();
      _cachedItems = items;
      emit(InventoryLoaded(items));
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
    } catch (e) {
      if (!isClosed) emit(InventoryError(e.toString()));
    }
  }

  Future<void> updateItem(InventoryItem item) async {
    try {
      await repository.updateItem(item);
      await loadInventory();
    } catch (e) {
      if (!isClosed) emit(InventoryError(e.toString()));
    }
  }

  Future<void> deleteItem(int id) async {
    try {
      await repository.deleteItem(id);
      await loadInventory();
    } catch (e) {
      if (!isClosed) emit(InventoryError(e.toString()));
    }
  }

  Future<void> updateInventoryAfterSale(List<BillItem> billItems) async {
    try {
      for (final billItem in billItems) {
        final inventoryItem = _cachedItems.firstWhere(
          (item) => item.name == billItem.name,
          orElse: () => throw Exception('Item not found in inventory'),
        );

        final updatedItem = InventoryItem(
          id: inventoryItem.id,
          name: inventoryItem.name,
          price: inventoryItem.price,
          quantity: inventoryItem.quantity - billItem.quantity,
          initialQuantity: inventoryItem.initialQuantity,
          shortcut: inventoryItem.shortcut,
        );

        await repository.updateItem(updatedItem);
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
}
