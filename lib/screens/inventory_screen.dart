import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forward_billing_app/repositories/inventory_repository.dart';
import 'package:forward_billing_app/utils/app_theme.dart';
import 'package:forward_billing_app/utils/auth_utils.dart';
import '../models/inventory_item.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/inventory_cubit.dart';
import '../themes/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../cubit/notification_cubit.dart';
import '../models/notification_model.dart';
import '../services/notification_repository.dart';
import '../models/activity.dart';
import '../repositories/activity_repository.dart';
import '../screens/login_screen.dart';
import 'dart:async'; // Import Timer

// Enforces shortcut typing rules without clearing input:
//  - Max length 5
//  - First char: A-D
//  - Rest: digits only
class _ShortcutInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toUpperCase();

    // Limit length to 5
    if (text.length > 5) return oldValue;

    if (text.isEmpty) {
      return newValue.copyWith(text: text);
    }

    // First character must be A-D
    final first = text[0];
    if (!RegExp(r'^[A-D]$').hasMatch(first)) {
      return oldValue;
    }

    // Remaining characters must be digits only
    final rest = text.length > 1 ? text.substring(1) : '';
    if (rest.isNotEmpty && !RegExp(r'^[0-9]*$').hasMatch(rest)) {
      return oldValue;
    }

    // All good, return uppercased value preserving selection
    return TextEditingValue(
      text: text,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InventoryView();
  }
}

class InventoryView extends StatefulWidget {
  const InventoryView({Key? key}) : super(key: key);

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  // Legacy state retained for compatibility but no longer used for rebuilds
  String _sortBy = 'name'; // or 'quantity'
  bool _sortDescending = false;
  bool _showLowStockOnly = false;
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier('');
  // New: filter notifiers so only the list rebuilds on change
  final ValueNotifier<String> _sortByNotifier = ValueNotifier('name');
  final ValueNotifier<bool> _sortDescendingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _lowStockOnlyNotifier = ValueNotifier(false);
  String? shortcutErrorText;
  Timer? _shortcutDebounce;
  String? _shortcutDuplicateMsg; // validator-driven duplicate error
  String? _lastShortcutChecked; // value used for last dup check

  // Keep last-seen quantities to detect transitions
  final Map<String, double> _prevQuantities = <String, double>{};
  // Persisted low-stock dedupe across sessions
  final NotificationRepository _notificationRepository =
      NotificationRepository();
  final Set<String> _persistedLowStockIds = <String>{};
  bool _lowStockDedupeReady = false;
  // Persisted zero-qty dedupe across sessions
  final Set<String> _persistedZeroQtyIds = <String>{};
  bool _zeroQtyDedupeReady = false;

  @override
  void initState() {
    super.initState();

    // Always load inventory when this screen is opened
    Future.microtask(() async {
      final userId = await getCurrentUserUid();
      if (userId != null) {
        // context.read<InventoryCubit>().loadInventory(userId: userId);
      }
      // Load persisted low-stock notified IDs
      final ids = await _notificationRepository.getLowStockNotifiedIds();
      // Backfill with already-saved low-stock notifications so we don't re-notify
      final existing = await _notificationRepository.getNotifications();
      for (final n in existing) {
        if (n.category == 'inventory' && n.data != null) {
          final type = n.data!['type'];
          final itemId = n.data!['item_id'];
          if (type == 'low_stock' && itemId is String) {
            ids.add(itemId);
          }
        }
      }
      if (mounted) {
        setState(() {
          _persistedLowStockIds
            ..clear()
            ..addAll(ids);
          _lowStockDedupeReady = true;
        });
      }

      // Load persisted zero-qty notified IDs
      final zeroIds = await _notificationRepository.getZeroQtyNotifiedIds();
      // Backfill from stored notifications
      for (final n in existing) {
        if (n.category == 'inventory' && n.data != null) {
          final type = n.data!['type'];
          final itemId = n.data!['item_id'];
          if (type == 'zero_quantity' && itemId is String) {
            zeroIds.add(itemId);
          }
        }
      }
      if (mounted) {
        setState(() {
          _persistedZeroQtyIds
            ..clear()
            ..addAll(zeroIds);
          _zeroQtyDedupeReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _shortcutDebounce?.cancel();
    _searchQueryNotifier.dispose();
    _sortByNotifier.dispose();
    _sortDescendingNotifier.dispose();
    _lowStockOnlyNotifier.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Unfocus the search bar when returning to this screen
    _searchFocusNode.unfocus();
  }

  void _search(String query) {
    _searchQueryNotifier.value = query;
  }

  bool _isLowStock(InventoryItem item) {
    // Calculate 20% of the initial quantity
    final lowStockThreshold = item.initialQuantity * 0.2;
    return item.quantity <= lowStockThreshold;
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    // Convert PKR text to Rupee symbol
    final displayValue = value.startsWith('PKR')
        ? '₨ ${value.substring(4)}'
        : value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          displayValue,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  double _calculateTotalValue(List<InventoryItem> items) {
    return items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  Future<void> _notifyZeroQuantity(
    BuildContext context,
    InventoryItem item,
  ) async {
    final id = item.firestoreId ?? '${item.userId}:${item.name}';
    if (_persistedZeroQtyIds.contains(id)) return; // dedupe across sessions
    _persistedZeroQtyIds.add(id);
    Future.microtask(() => _notificationRepository.addZeroQtyNotifiedId(id));

    final notification = NotificationModel(
      id: 'inv_${id}_zero_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Stock Exhausted',
      body: '“${item.name}” is out of stock (qty = 0). Consider restocking.',
      category: 'inventory',
      action: 'view_item',
      data: {'type': 'zero_quantity', 'item_id': id, 'name': item.name},
      timestamp: DateTime.now(),
      isRead: false,
    );

    // Avoid interfering with the current build
    Future.microtask(() {
      context.read<NotificationCubit>().addNotification(notification);
    });
  }

  Future<void> _notifyLowStock(BuildContext context, InventoryItem item) async {
    final id = item.firestoreId ?? '${item.userId}:${item.name}';
    if (_persistedLowStockIds.contains(id)) return; // dedupe across sessions
    _persistedLowStockIds.add(id);
    // Persist immediately (async, non-blocking)
    Future.microtask(() => _notificationRepository.addLowStockNotifiedId(id));

    final lowStockThreshold = (item.initialQuantity) * 0.2;
    final notification = NotificationModel(
      id: 'inv_${id}_low_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Low Stock Alert',
      body:
          '“${item.name}” is running low. Only ${item.quantity.toStringAsFixed(0)} left (≤ ${(lowStockThreshold).toStringAsFixed(0)}).',
      category: 'inventory',
      action: 'view_item',
      data: {'type': 'low_stock', 'item_id': id, 'name': item.name},
      timestamp: DateTime.now(),
      isRead: false,
    );

    Future.microtask(() {
      context.read<NotificationCubit>().addNotification(notification);
    });
  }

  Widget _buildItemCard(InventoryItem item) {
    final isLowStock = _isLowStock(item);
    final isExhausted = item.quantity == 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark
          ? (isExhausted
                ? const Color.fromARGB(255, 250, 28, 28)
                : const Color(0xFF013A63))
          : (isExhausted ? const Color.fromARGB(255, 250, 35, 35) : null),
      child: InkWell(
        onTap: () => _showItemDialog(context, item: item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row only
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? (isExhausted ? Colors.white : Colors.white)
                            : (isExhausted
                                  ? Colors.white
                                  : AppTheme.getPrimaryColor(context)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '₨${item.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? (isExhausted ? Colors.white : Colors.white)
                                : (isExhausted
                                      ? Colors.white
                                      : AppTheme.getPrimaryColor(context)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isLowStock
                                ? Colors.red.withAlpha(25)
                                : Colors.green.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Qty: ${item.quantity.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isExhausted
                                  ? Colors.white
                                  : (isLowStock ? Colors.red : Colors.green),
                            ),
                          ),
                        ),
                        // Shortcut container placed next to quantity
                        if (item.shortcut != null && item.shortcut!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isExhausted
                                  ? Colors.red
                                  : const Color.fromARGB(255, 173, 218, 255),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.shortcut_sharp,
                                  color: isExhausted
                                      ? Colors.white
                                      : Colors.blue.shade500,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.shortcut!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isExhausted
                                        ? Colors.white
                                        : Colors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: isDark
                      ? (isExhausted ? Colors.white : Colors.white)
                      : (isExhausted ? Colors.white : Colors.red),
                  size: 24,
                ),
                onPressed: () => _deleteItem(context, item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No items found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some items to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showItemDialog(BuildContext context, {InventoryItem? item}) async {
    final nameController = TextEditingController(text: item?.name);
    final priceController = TextEditingController(
      text: item == null
          ? ''
          : (item.price % 1 == 0
                ? item.price.toInt().toString()
                : item.price.toString()),
    );
    final quantityController = TextEditingController(
      text: item == null ? '' : item.quantity.toInt().toString(),
    );
    final shortcutController = TextEditingController(text: item?.shortcut);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 48),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item == null ? 'Add New Item' : 'Edit Item',
                    style: TextStyle(
                      color: const Color(0xFF1976D2),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: nameController,
                    decoration: AppTheme.getStandardInputDecoration(
                      context,
                      labelText: 'Item Name',
                      hintText: 'Enter item name',
                      prefixIcon: Icons.title,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter item name';
                      }
                      final pattern = RegExp(r'^[a-zA-Z0-9\-\s]{2,50}$');
                      if (!pattern.hasMatch(value.trim())) {
                        return '2-50 letters, numbers, spaces, or dashes only';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: AppTheme.getStandardInputDecoration(
                      context,
                      labelText: 'Price (₨)',
                      hintText: 'Enter price',
                      prefixIcon: Icons.attach_money,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter price';
                      }
                      final price = double.tryParse(value);
                      if (price == null || price <= 0) {
                        return 'Please enter a valid price (>0)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    decoration: AppTheme.getStandardInputDecoration(
                      context,
                      labelText: 'Quantity',
                      hintText: 'Enter quantity',
                      prefixIcon: Icons.numbers,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter quantity';
                      }
                      final quantity = int.tryParse(value);
                      if (quantity == null || quantity <= 0) {
                        return 'Please enter a valid quantity (>0, integer)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: shortcutController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: AppTheme.getStandardInputDecoration(
                      context,
                      labelText: 'Shortcut',
                      hintText: 'Enter shortcut code',
                      prefixIcon: Icons.bolt,
                    ).copyWith(errorText: shortcutErrorText),
                    inputFormatters: [LengthLimitingTextInputFormatter(5)],
                    onChanged: (value) async {
                      final input = value.trim().toUpperCase();
                      // Synchronous format validation
                      String? formatErr;
                      if (input.isEmpty) {
                        formatErr = null; // no required error while typing
                      } else if (!RegExp(r'^[A-D]').hasMatch(input)) {
                        formatErr = 'Shortcut must start with A, B, C, or D.';
                      } else {
                        final digits = input.length > 1
                            ? input.substring(1)
                            : '';
                        if (digits.isEmpty) {
                          formatErr = 'Enter 1–4 digits after the letter.';
                        } else if (!RegExp(r'^[0-9]+$').hasMatch(digits)) {
                          formatErr =
                              'Only digits are allowed after the letter.';
                        } else if (digits.length > 4) {
                          formatErr =
                              'Shortcut cannot have more than 4 digits.';
                        }
                      }

                      setState(() {
                        shortcutErrorText =
                            formatErr; // format errors via decoration
                        // reset duplicate state when typing
                        _shortcutDuplicateMsg = null;
                        _lastShortcutChecked = null;
                      });

                      // Debounced duplicate check only when format is valid
                      _shortcutDebounce?.cancel();
                      if (formatErr != null || input.isEmpty) return;
                      _shortcutDebounce = Timer(
                        const Duration(milliseconds: 350),
                        () async {
                          final userId = await getCurrentUserUid();
                          if (!mounted || userId == null) return;
                          final isDuplicate = await context
                              .read<InventoryRepository>()
                              .isShortcutTaken(
                                userId,
                                input,
                                excludeId: item?.firestoreId,
                              );
                          if (!mounted) return;
                          setState(() {
                            _lastShortcutChecked = input;
                            _shortcutDuplicateMsg = isDuplicate
                                ? 'This shortcut is already used by another item.'
                                : null;
                          });
                          // Re-run validators so the error shows immediately
                          formKey.currentState?.validate();
                        },
                      );
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Shortcut is required';
                      }

                      // Specific checks for clearer errors
                      final input = value.trim().toUpperCase();
                      // 1) Prefix must be A/B/C/D
                      if (!RegExp(r'^[A-D]').hasMatch(input)) {
                        return 'Shortcut must start with A, B, C, or D.';
                      }
                      final digits = input.length > 1 ? input.substring(1) : '';
                      // 2) Must have 1–4 digits after the letter
                      if (digits.isEmpty) {
                        return 'Enter 1–4 digits after the letter.';
                      }
                      if (!RegExp(r'^[0-9]+$').hasMatch(digits)) {
                        return 'Only digits are allowed after the letter.';
                      }
                      if (digits.length > 4) {
                        return 'Shortcut cannot have more than 4 digits.';
                      }

                      // 3) Duplicate check result (if any) should show instantly
                      if (_lastShortcutChecked != null &&
                          input == _lastShortcutChecked &&
                          _shortcutDuplicateMsg != null) {
                        return _shortcutDuplicateMsg;
                      }

                      return null; // No sync error
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF1976D2),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: AppTheme.getGradientDecoration(),
                        child: ElevatedButton(
                          style: AppTheme.getGradientSaveButtonStyle(context),
                          onPressed: () async {
                            // Clear any previous error shown
                            setState(() {
                              shortcutErrorText = null;
                            });

                            // Run sync validation
                            if (!formKey.currentState!.validate()) return;

                            final userId = await getCurrentUserUid();
                            if (userId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('User not authenticated.'),
                                ),
                              );
                              return;
                            }

                            final shortcutInput = shortcutController.text
                                .trim();
                            final normalizedShortcut = shortcutInput
                                .toUpperCase();

                            // Check for duplicate shortcut (async)
                            final isDuplicate = await context
                                .read<InventoryRepository>()
                                .isShortcutTaken(
                                  userId,
                                  normalizedShortcut,
                                  excludeId: item?.firestoreId,
                                );

                            if (isDuplicate) {
                              setState(() {
                                _lastShortcutChecked = normalizedShortcut;
                                _shortcutDuplicateMsg =
                                    'This shortcut is already used by another item.';
                              });
                              // Trigger validator to surface the error immediately
                              formKey.currentState!.validate();
                              return;
                            }

                            // Clear async error if validation passed
                            setState(() {
                              _shortcutDuplicateMsg = null;
                              _lastShortcutChecked = null;
                            });

                            final newItem = InventoryItem(
                              userId: userId,
                              firestoreId: item?.firestoreId,
                              name: nameController.text.trim(),
                              price: double.parse(priceController.text.trim()),
                              quantity: double.parse(
                                quantityController.text.trim(),
                              ),
                              shortcut: normalizedShortcut,
                            );

                            if (item == null) {
                              await context
                                  .read<InventoryRepository>()
                                  .insertItem(newItem);
                            } else {
                              await context
                                  .read<InventoryRepository>()
                                  .updateItem(newItem);
                            }

                            Navigator.pop(context);
                            await _logInventoryActivity(item, newItem, userId);
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteItem(BuildContext context, InventoryItem item) async {
    try {
      debugPrint(
        'Attempting to delete item: \\${item.name} (firestoreId: \\${item.firestoreId})',
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Item'),
          content: Text('Are you sure you want to delete "${item.name}"?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        if (item.firestoreId == null) {
          debugPrint('Error: Cannot delete item without firestoreId');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Item missing Firestore ID.')),
          );
          return;
        }
        await context.read<InventoryRepository>().deleteItem(
          item.firestoreId!,
          item.userId,
        );
        debugPrint('Item deleted in Firestore: \\${item.firestoreId}');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item deleted.')));
      }
    } catch (e, st) {
      debugPrint('Error deleting item: $e\\n$st');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting item: $e')));
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        // Temp variables for dialog state
        bool tempShowLowStockOnly = _showLowStockOnly;
        String tempSortBy = _sortBy;
        bool tempDescending = _sortDescending;

        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Filter & Sort'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: tempShowLowStockOnly,
                  onChanged: (v) =>
                      setModalState(() => tempShowLowStockOnly = v ?? false),
                  title: const Text('Show only low stock'),
                ),
                const Divider(),
                const Text('Sort by:'),
                RadioListTile<String>(
                  value: 'name',
                  groupValue: tempSortBy,
                  onChanged: (v) => setModalState(() => tempSortBy = v!),
                  title: const Text('Name'),
                ),
                RadioListTile<String>(
                  value: 'quantity',
                  groupValue: tempSortBy,
                  onChanged: (v) => setModalState(() => tempSortBy = v!),
                  title: const Text('Quantity'),
                ),
                SwitchListTile(
                  title: const Text('Descending order'),
                  value: tempDescending,
                  onChanged: (v) => setModalState(() => tempDescending = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF1976D2),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  side: BorderSide.none,
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(color: Color(0xFF1976D2)),
                ),
                onPressed: () {
                  // Update notifiers so only the list section rebuilds
                  _lowStockOnlyNotifier.value = tempShowLowStockOnly;
                  _sortByNotifier.value = tempSortBy;
                  _sortDescendingNotifier.value = tempDescending;
                  // Keep legacy state vars in sync (optional)
                  _showLowStockOnly = tempShowLowStockOnly;
                  _sortBy = tempSortBy;
                  _sortDescending = tempDescending;
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A2342)
          : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A2233) : Colors.white,
        centerTitle: true,
        title: Text(
          'Inventory',
          style: TextStyle(
            fontSize: 22,
            color: isDark ? Colors.white : Color(0xFF0A2342),
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Color(0xFF0A2342),
        ),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      body: FutureBuilder<String?>(
        future: getCurrentUserUid(),
        builder: (ctx, usnap) {
          if (!usnap.hasData)
            return const Center(child: CircularProgressIndicator());

          final userId = usnap.data!;

          // Single stream for base inventory (no UI filters applied here)
          return StreamBuilder<List<InventoryItem>>(
            stream: context.read<InventoryRepository>().streamFilteredItems(
              userId,
              sortBy: 'name',
              descending: false,
              lowStockOnly: false,
            ),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snap.hasError) {
                debugPrint('Inventory Stream Error: ${snap.error}');
                if (snap.stackTrace != null) {
                  debugPrint('StackTrace: ${snap.stackTrace}');
                }
                return Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'An error occurred loading inventory:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snap.error.toString(),
                          style: const TextStyle(color: Colors.red),
                        ),
                        if (snap.stackTrace != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              snap.stackTrace.toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }

              if (!snap.hasData) {
                return const Center(
                  child: Text('No inventory data available.'),
                );
              }

              // Base items from stream (no deletion)
              final items = snap.data!.where((it) => !it.isDeleted).toList();

              // Detect transitions for zero quantity and low stock, then notify
              for (final it in items) {
                final String id = it.firestoreId ?? '${it.userId}:${it.name}';
                final now = it.quantity;
                final threshold = (it.initialQuantity) * 0.2;

                // Zero-qty check with persisted dedupe: only after IDs are loaded
                if (_zeroQtyDedupeReady) {
                  if (now == 0 && !_persistedZeroQtyIds.contains(id)) {
                    _notifyZeroQuantity(context, it);
                  }
                  // If replenished above zero, allow future zero-qty notifications again (persistently)
                  if (now > 0 && _persistedZeroQtyIds.contains(id)) {
                    _persistedZeroQtyIds.remove(id);
                    Future.microtask(
                      () => _notificationRepository.removeZeroQtyNotifiedId(id),
                    );
                  }
                }

                // Low stock check with persisted dedupe: only after IDs are loaded
                if (_lowStockDedupeReady) {
                  final isLow = now > 0 && now <= threshold;
                  if (isLow && !_persistedLowStockIds.contains(id)) {
                    _notifyLowStock(context, it);
                  }
                  // If went back above threshold, allow future low-stock notifications again (persistently)
                  if (!isLow && _persistedLowStockIds.contains(id)) {
                    _persistedLowStockIds.remove(id);
                    Future.microtask(
                      () =>
                          _notificationRepository.removeLowStockNotifiedId(id),
                    );
                  }
                }

                // Update last seen
                _prevQuantities[id] = now;
              }

              // Header: stats + search + filter (does not rebuild on filter changes)
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stats summary
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF0A2342),
                            Color(0xFF123060),
                            Color(0xFF1976D2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'Total Items',
                            items.length.toString(),
                            Icons.inventory_2,
                          ),
                          _buildStatItem(
                            'Total Value',
                            'Rs  ${_calculateTotalValue(items)}',
                            Icons.account_balance,
                          ),
                          _buildStatItem(
                            'Low Stock',
                            items
                                .where((item) => _isLowStock(item))
                                .length
                                .toString(),
                            Icons.warning,
                          ),
                        ],
                      ),
                    ).animate().fade(duration: 400.ms).slideY(begin: -0.5),

                    // Search bar + filter button
                    Row(
                          children: [
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(
                                  bottom: 16,
                                  right: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: kCardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withAlpha(25),
                                      spreadRadius: 1,
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  onChanged: _search,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: InputDecoration(
                                    hintText: 'Search items...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: Colors.grey[600],
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? Colors.black
                                        : Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF0A2342),
                                    Color(0xFF123060),
                                    Color(0xFF1976D2),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.filter_alt,
                                  color: Colors.white,
                                ),
                                onPressed: _showFilterDialog,
                                tooltip: 'Filter',
                              ),
                            ),
                          ],
                        )
                        .animate()
                        .fade(delay: 200.ms, duration: 400.ms)
                        .slideY(begin: -0.5),

                    // List (only this part rebuilds on filter/search changes)
                    Expanded(
                      child: ValueListenableBuilder<String>(
                        valueListenable: _sortByNotifier,
                        builder: (context, sortBy, _) =>
                            ValueListenableBuilder<bool>(
                              valueListenable: _sortDescendingNotifier,
                              builder: (context, descending, __) =>
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _lowStockOnlyNotifier,
                                    builder: (context, lowStockOnly, ___) {
                                      return ValueListenableBuilder<String>(
                                        valueListenable: _searchQueryNotifier,
                                        builder: (context, query, ____) {
                                          final base = lowStockOnly
                                              ? items
                                                    .where(
                                                      (it) => _isLowStock(it),
                                                    )
                                                    .toList()
                                              : items;
                                          var working = List.of(base);
                                          if (sortBy == 'quantity') {
                                            working.sort(
                                              (a, b) => a.quantity.compareTo(
                                                b.quantity,
                                              ),
                                            );
                                          } else {
                                            working.sort(
                                              (a, b) => a.name
                                                  .toLowerCase()
                                                  .compareTo(
                                                    b.name.toLowerCase(),
                                                  ),
                                            );
                                          }
                                          if (descending) {
                                            working = working.reversed.toList();
                                          }

                                          final filtered = query.isEmpty
                                              ? working
                                              : working.where((item) {
                                                  final lowerQuery = query
                                                      .toLowerCase();
                                                  return item.name
                                                          .toLowerCase()
                                                          .contains(
                                                            lowerQuery,
                                                          ) ||
                                                      (item.shortcut
                                                              ?.toLowerCase()
                                                              .contains(
                                                                lowerQuery,
                                                              ) ??
                                                          false);
                                                }).toList();

                                          if (filtered.isEmpty) {
                                            return _buildEmptyState();
                                          }

                                          return ListView.builder(
                                            controller: _scrollController,
                                            itemCount: filtered.length,
                                            itemBuilder: (context, index) =>
                                                _buildItemCard(filtered[index])
                                                    .animate()
                                                    .fade(
                                                      delay: (100 * index).ms,
                                                    )
                                                    .slideY(begin: 0.5),
                                          );
                                        },
                                      );
                                    },
                                  ),
                            ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A2342), Color(0xFF123060), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(Icons.add, color: Colors.white, size: 32),
          onPressed: () => _showItemDialog(context),
          tooltip: 'Add New Item',
        ),
      ),
    );
  }
}

Future<void> _logInventoryActivity(
  InventoryItem? oldItem,
  InventoryItem newItem,
  String userId,
) async {
  await ActivityRepository().logActivity(
    Activity(
      userId: userId,
      type: oldItem == null ? 'inventory_add' : 'inventory_edit',
      description:
          '${oldItem == null ? 'Added' : 'Edited'} inventory item: ${newItem.name}',
      timestamp: DateTime.now(),
      metadata: {
        'firestoreId': newItem.firestoreId,
        'name': newItem.name,
        'price': newItem.price,
        'quantity': newItem.quantity,
        'shortcut': newItem.shortcut,
      },
    ),
  );
}
