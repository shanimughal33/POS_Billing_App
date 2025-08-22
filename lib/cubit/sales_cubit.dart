import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/bill_item.dart';
import '../models/inventory_item.dart';
import '../repositories/bill_repository.dart';
import '../utils/shortcut_validator.dart';
import 'package:flutter/foundation.dart';

part 'sales_state.dart';

class SalesCubit extends Cubit<SalesState> {
  final List<InventoryItem> inventory;
  final BillRepository billRepository = BillRepository();

  // Per-user in-memory cart isolation
  final Map<String, List<BillItem>> _userCarts = {};
  String? _currentUserId;

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

  List<BillItem> get _items => _userCarts[_currentUserId] ?? <BillItem>[];
  set _items(List<BillItem> value) {
    if (_currentUserId != null) {
      _userCarts[_currentUserId!] = value;
    }
  }

  List<BillItem> get items => List.unmodifiable(
    _items.where((item) {
      final matches = inventory.where(
        (inv) =>
            inv.name.trim().toLowerCase() == item.name.trim().toLowerCase(),
      );
      // Custom filtering: only show items that are not sold
      return matches.isEmpty ||
          (matches.isNotEmpty && matches.first.isSold == false);
    }),
  );

  // Set the current user and switch cart
  void setCurrentUser(String userId) {
    _currentUserId = userId;
    // Ensure a cart exists for this user
    _userCarts.putIfAbsent(userId, () => <BillItem>[]);
    emit(SalesUpdated(_items.where((item) => !_isSold(item)).toList()));
  }

  bool _isSold(BillItem item) {
    // Check if the item exists in inventory and is marked as sold
    final matches = inventory.where(
      (inv) => inv.name.trim().toLowerCase() == item.name.trim().toLowerCase(),
    );
    return matches.isNotEmpty && matches.first.isSold == true;
  }

  Future<void> loadSalesFromDb(String userId) async {
    debugPrint('SalesCubit: loadSalesFromDb called for userId=$userId');
    try {
      final dbItems = await billRepository.getAllBillItemsForUser(userId);
      _userCarts[userId] = dbItems;
      debugPrint('SalesCubit: Loaded ${dbItems.length} bill items for userId=$userId');
      if (!isClosed) {
        emit(SalesUpdated(_items.where((item) => !_isSold(item)).toList()));
      }
    } catch (e) {
      debugPrint('SalesCubit: Error in loadSalesFromDb: $e');
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
    final list = List<BillItem>.from(_items);
    list.add(billItem);
    _items = list;
    // Don't insert to DB here - items will be inserted when bill is created
    if (!isClosed) {
      emit(SalesUpdated(_items.where((item) => !_isSold(item)).toList()));
    }
  }

  Future<void> clearItems() async {
    _items = <BillItem>[];
    // Don't clear DB here - only clear in-memory items
    if (!isClosed) emit(SalesUpdated([]));
  }

  Future<void> removeItem(BillItem item) async {
    final list = List<BillItem>.from(_items);
    if (item.id != null) {
      list.removeWhere((i) => i.id == item.id);
    } else {
      list.removeWhere((i) =>
        i.id == null &&
        i.name == item.name &&
        i.price == item.price &&
        i.quantity == item.quantity &&
        i.serialNo == item.serialNo
      );
    }
    _items = list;
    _reorderSerialsAndNames();
    if (!isClosed) {
      emit(SalesUpdated(_items.where((item) => !_isSold(item)).toList()));
    }
  }

  Future<void> updateItem(BillItem updatedItem) async {
    final list = List<BillItem>.from(_items);
    final idx = list.indexWhere((i) => i.id == updatedItem.id);
    if (idx != -1) {
      list[idx] = updatedItem;
      _items = list;
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
    final list = List<BillItem>.from(_items);
    list.add(item);
    _items = list;
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

  Future<void> updateCartItem(BillItem oldItem, BillItem newItem) async {
    // Match by all fields except id (for unsaved items)
    final idx = _items.indexWhere((i) =>
      i.id == null &&
      i.name == oldItem.name &&
      i.price == oldItem.price &&
      i.quantity == oldItem.quantity &&
      i.serialNo == oldItem.serialNo
    );
    if (idx != -1) {
      _items[idx] = newItem;
      if (!isClosed) {
        emit(SalesUpdated(_items.where((item) => !_isSold(item)).toList()));
      }
    }
  }

  void _reorderSerialsAndNames() {
    int serial = 1;
    // After every operation, check if all items are default names
    final allDefault = _items.isNotEmpty && _items.every((item) => RegExp(r'^Item \d+ ?$').hasMatch(item.name));
    if (allDefault) {
      // Rename all to strict sequence
      for (var i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(
          serialNo: serial,
          name: 'Item $serial',
        );
        serial++;
      }
    } else {
    for (var i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(
        serialNo: serial,
      );
      serial++;
      }
    }
  }
}
