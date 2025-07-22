import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/bill_item.dart';
import '../models/inventory_item.dart';
import '../repositories/bill_repository.dart';
import '../utils/shortcut_validator.dart';

part 'sales_state.dart';

class SalesCubit extends Cubit<SalesState> {
  final List<InventoryItem> inventory;
  final BillRepository billRepository = BillRepository();

  // Build the shortcut map once at construction for instant lookup
  late final Map<String, InventoryItem> _shortcutMap = _createShortcutMap();
  Map<String, InventoryItem> _createShortcutMap() {
    final map = <String, InventoryItem>{};
    for (final item in inventory) {
      if (item.shortcut != null && item.shortcut!.trim().isNotEmpty) {
        final shortcut = item.shortcut!.trim().toUpperCase();
        map[shortcut] = item;
        // Also parse and add normalized shortcut (e.g. A1, B2, etc)
        final result = ShortcutValidator.parseShortcut(shortcut);
        if (result.isValid) {
          final normalizedShortcut = '${result.category}${result.code}';
          map[normalizedShortcut] = item;
        }
      }
    }
    return map;
  }

  SalesCubit(this.inventory) : super(SalesInitial());

  final List<BillItem> _items = [];

  List<BillItem> get items =>
      List.unmodifiable(_items.where((item) => !_isSold(item)));

  bool _isSold(BillItem item) {
    // Check if the item exists in inventory and is marked as sold
    final matches = inventory.where(
      (inv) => inv.name.trim().toLowerCase() == item.name.trim().toLowerCase(),
    );
    return matches.isNotEmpty && matches.first.isSold == true;
  }

  Future<void> loadSalesFromDb() async {
    try {
      final dbItems = await billRepository.getAllBillItems();
      _items.clear();
      _items.addAll(dbItems);
      if (!isClosed) {
        emit(SalesUpdated(_items.where((item) => !_isSold(item)).toList()));
      }
    } catch (e) {
      if (!isClosed) emit(SalesError('Failed to load sales items: $e'));
    }
  }

  Future<void> addItemFromShortcut(String shortcut) async {
    final normalized = shortcut.trim().toUpperCase();
    final result = ShortcutValidator.parseShortcut(normalized);
    if (!result.isValid) {
      if (!isClosed) {
        emit(SalesError(result.error ?? 'Invalid shortcut format'));
      }
      return;
    }

    // Try exact match first (robust, in-memory)
    final exactMatch = _shortcutMap[normalized];
    if (exactMatch != null) {
      await _addInventoryItemToBill(exactMatch, result.quantity);
      return;
    }

    // Try normalized match (robust, in-memory)
    final normalizedShortcut = '${result.category}${result.code}';
    final normalizedMatch = _shortcutMap[normalizedShortcut];
    if (normalizedMatch != null) {
      await _addInventoryItemToBill(normalizedMatch, result.quantity);
      return;
    }

    if (!isClosed) {
      emit(SalesError('No inventory item found for shortcut $shortcut'));
    }
  }

  Future<void> _addInventoryItemToBill(
    InventoryItem inv,
    double? quantity,
  ) async {
    final billItem = BillItem(
      serialNo: _items.length + 1,
      name: inv.name,
      price: inv.price,
      quantity: quantity ?? inv.quantity,
    );
    _items.add(billItem);
    // Don't insert to DB here - items will be inserted when bill is created
    if (!isClosed) {
      emit(SalesUpdated(_items.where((item) => !_isSold(item)).toList()));
    }
  }

  Future<void> clearItems() async {
    _items.clear();
    // Don't clear DB here - only clear in-memory items
    if (!isClosed) emit(SalesUpdated([]));
  }

  Future<void> removeItem(BillItem item) async {
    _items.removeWhere((i) => i.id == item.id);
    _reorderSerialsAndNames();
    if (!isClosed) {
      emit(SalesUpdated(_items.where((item) => !_isSold(item)).toList()));
    }
  }

  Future<void> updateItem(BillItem updatedItem) async {
    final idx = _items.indexWhere((i) => i.id == updatedItem.id);
    if (idx != -1) {
      _items[idx] = updatedItem;
      // Don't update DB here - only update in-memory item
      if (!isClosed) {
        emit(SalesUpdated(_items.where((item) => !_isSold(item)).toList()));
      }
    }
  }

  void searchItems(String query) {
    if (query.isEmpty) {
      if (!isClosed) {
        emit(SalesUpdated(_items.where((item) => !_isSold(item)).toList()));
      }
    } else {
      final filtered = _items
          .where(
            (item) => item.name.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
      if (!isClosed) {
        emit(SalesUpdated(filtered.where((item) => !_isSold(item)).toList()));
      }
    }
  }

  BillItem? _editingItem;
  BillItem? get editingItem => _editingItem;
  void startEdit(BillItem item) {
    _editingItem = item;
    if (!isClosed) {
      emit(SalesUpdated(_items.where((item) => !_isSold(item)).toList()));
    }
  }

  InventoryItem? getInventoryItemByShortcut(String shortcut) {
    final normalized = shortcut.trim().toUpperCase();
    // Try exact match first (robust, in-memory)
    final exactMatch = _shortcutMap[normalized];
    if (exactMatch != null) return exactMatch;

    // Try normalized match (robust, in-memory)
    final result = ShortcutValidator.parseShortcut(normalized);
    if (!result.isValid) return null;

    final normalizedShortcut = '${result.category}${result.code}';
    return _shortcutMap[normalizedShortcut];
  }

  Future<void> addBillItem(BillItem item) async {
    // Add to in-memory list only - will be saved when bill is created
    _items.add(item);
    if (!isClosed) {
      emit(SalesUpdated(_items.where((item) => !_isSold(item)).toList()));
    }
  }

  void updateInventory(List<InventoryItem> newInventory) {
    inventory
      ..clear()
      ..addAll(newInventory);
    emit(SalesUpdated(_items.where((item) => !_isSold(item)).toList()));
  }

  Future<void> removeItemByFields(
    String name,
    double price,
    double quantity,
    int serialNo,
  ) async {
    _items.removeWhere(
      (i) =>
          (i.id == null) &&
          i.name == name &&
          i.price == price &&
          i.quantity == quantity &&
          i.serialNo == serialNo,
    );
    _reorderSerialsAndNames();
    if (!isClosed) {
      emit(SalesUpdated(_items.where((item) => !_isSold(item)).toList()));
    }
  }

  void _reorderSerialsAndNames() {
    int serial = 1;
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      // Only update name if it matches the default pattern
      final isDefault = RegExp(r'^Item \d+ ?$').hasMatch(item.name);
      _items[i] = item.copyWith(
        serialNo: serial,
        name: isDefault ? 'Item $serial' : item.name,
      );
      serial++;
    }
  }
}
