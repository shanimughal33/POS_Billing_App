import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/bill_item.dart';
import '../models/inventory_item.dart';
import '../repositories/bill_repository.dart';
import '../utils/shortcut_validator.dart';

part 'sales_state.dart';

class SalesCubit extends Cubit<SalesState> {
  final List<InventoryItem> inventory;
  final BillRepository billRepository = BillRepository();
  SalesCubit(this.inventory) : super(SalesInitial());

  final List<BillItem> _items = [];

  Map<String, InventoryItem> get _shortcutMap {
    final map = <String, InventoryItem>{};
    for (final item in inventory) {
      if (item.shortcut != null) {
        final shortcut = item.shortcut!.trim().toUpperCase();
        map[shortcut] = item;

        final result = ShortcutValidator.parseShortcut(shortcut);
        if (result.isValid) {
          final normalizedShortcut = '${result.category}${result.code}';
          map[normalizedShortcut] = item;
        }
      }
    }
    return map;
  }

  List<BillItem> get items => List.unmodifiable(_items);

  Future<void> loadSalesFromDb() async {
    try {
      final dbItems = await billRepository.getAllBillItems();
      _items.clear();
      _items.addAll(dbItems);
      if (!isClosed) emit(SalesUpdated(List.from(_items)));
    } catch (e) {
      if (!isClosed) emit(SalesError('Failed to load sales items: $e'));
    }
  }

  Future<void> addBillItem(BillItem item) async {
    try {
      final newItem = await billRepository.insertBillItem(item);
      _items.add(newItem);
      if (!isClosed) emit(SalesUpdated(List.from(_items)));
    } catch (e) {
      if (!isClosed) emit(SalesError('Failed to add item: $e'));
    }
  }

  void removeItem(BillItem item) {
    try {
      if (item.id != null) {
        billRepository.softDeleteItem(item.id!);
      }
      _items.removeWhere((i) => i.id == item.id);
      if (!isClosed) emit(SalesUpdated(List.from(_items)));
    } catch (e) {
      if (!isClosed) emit(SalesError('Failed to remove item: $e'));
    }
  }

  void clearItems() {
    _items.clear();
    if (!isClosed) emit(SalesUpdated(List.from(_items)));
  }

  Future<void> completeBill() async {
    try {
      await billRepository.markCurrentItemsAsCompleted();
      _items.clear();
      if (!isClosed) emit(SalesUpdated(List.from(_items)));
    } catch (e) {
      if (!isClosed) emit(SalesError('Failed to complete bill: $e'));
    }
  }

  void searchItems(String query) {
    if (!isClosed) emit(SalesUpdated(List.from(_items)));
  }

  Future<void> updateBillItem(BillItem item) async {
    try {
      await billRepository.updateBillItem(item);
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        _items[index] = item;
        if (!isClosed) emit(SalesUpdated(List.from(_items)));
      }
    } catch (e) {
      if (!isClosed) emit(SalesError('Failed to update item: $e'));
    }
  }

  void startEdit(BillItem item) {
    if (!isClosed) emit(SalesEditing(item));
  }

  void cancelEdit() {
    if (!isClosed) emit(SalesUpdated(List.from(_items)));
  }

  InventoryItem? getInventoryItemByShortcut(String shortcut) {
    return _shortcutMap[shortcut.toUpperCase()];
  }

  void addItemFromShortcut(String shortcut) {
    final item = getInventoryItemByShortcut(shortcut);
    if (item != null) {
      final billItem = BillItem(
        serialNo: _items.length + 1,
        name: item.name,
        price: item.price,
        quantity: 1,
      );
      addBillItem(billItem);
    }
  }
}
