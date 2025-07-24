import 'package:flutter/material.dart';
import '../models/inventory_item.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/inventory_cubit.dart';
import '../models/activity.dart';
import '../repositories/activity_repository.dart';
import '../utils/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PurchaseScreen extends StatelessWidget {
  const PurchaseScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _PurchaseScreenAutoOpenWrapper();
  }
}

class _PurchaseScreenAutoOpenWrapper extends StatefulWidget {
  @override
  State<_PurchaseScreenAutoOpenWrapper> createState() =>
      _PurchaseScreenAutoOpenWrapperState();
}

class _PurchaseScreenAutoOpenWrapperState
    extends State<_PurchaseScreenAutoOpenWrapper> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final state = context.findAncestorStateOfType<_PurchaseViewState>();
        if (state != null && mounted) {
          state._showItemDialog(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const PurchaseView();
  }
}

class PurchaseView extends StatefulWidget {
  const PurchaseView({Key? key}) : super(key: key);

  @override
  State<PurchaseView> createState() => _PurchaseViewState();
}

class _PurchaseViewState extends State<PurchaseView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-open Add Item form (no autofocus)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showItemDialog(context);
    });
  }

  @override
  void dispose() {
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
    setState(() {
      _searchQuery = query;
    });
  }

  // --- BUDGET LOGIC ---
  bool _isLowBudget(InventoryItem item) {
    // Let's assume initialQuantity is initial budget, quantity is remaining budget
    final lowBudgetThreshold = item.initialQuantity * 0.2;
    return item.quantity <= lowBudgetThreshold;
  }

  Widget _buildInventoryList(BuildContext context, List<InventoryItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inventory-style stats summary
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
              borderRadius: BorderRadius.circular(12),
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
                  Icons.shopping_cart_rounded,
                ),
                _buildStatItem(
                  'Total Value',
                  'Rs ${_calculateTotal(items).toStringAsFixed(2)}',
                  Icons.account_balance,
                ),
                _buildStatItem(
                  'Total Qty',
                  _calculateTotalQty(items).toString(),
                  Icons.format_list_numbered,
                ),
              ],
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: -0.5),

          // Search bar (moved below stats)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child:
                TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _search,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search items...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: kCardBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
                    )
                    .animate()
                    .fade(delay: 200.ms, duration: 400.ms)
                    .slideY(begin: -0.5),
          ),

          // Items list
          Expanded(
            child: items.isEmpty
                ? _buildEmptyState()
                : InteractiveViewer(
                    panEnabled: true,
                    scaleEnabled: true,
                    minScale: 1.0,
                    maxScale: 3.0,
                    child: ListView.builder(
                    controller: _scrollController,
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                          _buildItemCard(items[index])
                              .animate()
                              .fade(delay: (100 * index).ms)
                              .slideY(begin: 0.5),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    // Convert PKR text to Rupee symbol
    final displayValue = value.startsWith('PKR')
        ? '₨ ${value.substring(4)}'
        : value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: kWhite, size: 24),
        const SizedBox(height: 8),
        Text(
          displayValue,
          style: const TextStyle(
            color: kWhite,
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

  String _calculateTotalBudget(List<InventoryItem> items) {
    // Sum of all remaining budgets (quantity as budget)
    final total = items.fold<double>(0, (sum, item) => sum + item.quantity);
    return total.toStringAsFixed(2);
  }

  Widget _buildItemCard(InventoryItem item) {
    final isLowBudget = _isLowBudget(item);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '₨${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: kBlue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isLowBudget
                                ? Colors.red.withAlpha(51)
                                : Colors.green.withAlpha(51),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Qty: ${item.quantity.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isLowBudget ? Colors.red : Colors.green,
                            ),
                          ),
                        ),
                        // Shortcut container placed next to budget
                        if (item.shortcut != null && item.shortcut!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(
                                255,
                                217,
                                234,
                                250,
                              ), // Blue color
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.shortcut_sharp,
                                  color: Colors.blue.shade500,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.shortcut!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue,
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
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 24,
                ),
                onPressed: () => _deleteItem(context, item.id!),
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

  void _showItemDialog(BuildContext context, {InventoryItem? item}) {
    final nameController = TextEditingController(text: item?.name);
    final priceController = TextEditingController(text: item?.price.toString());
    final quantityController = TextEditingController(
      text: item?.quantity.toString(),
    );
    final shortcutController = TextEditingController(text: item?.shortcut);
    final formKey = GlobalKey<FormState>();
    final nameFocus = FocusNode();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item == null ? 'Add New Item' : 'Edit Item',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1976D2),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameController,
                  focusNode: nameFocus,
                  decoration: InputDecoration(
                    labelText: 'Item Name',
                    hintText: 'Enter item name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFFBBDEFB),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFFBBDEFB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kBlue, width: 2),
                    ),
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
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Price (₨)',
                    hintText: 'Enter price',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFFBBDEFB),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFFBBDEFB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kBlue, width: 2),
                    ),
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
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    hintText: 'Enter quantity',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFFBBDEFB),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFFBBDEFB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kBlue, width: 2),
                    ),
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
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: shortcutController,
                  decoration: InputDecoration(
                    labelText: 'Shortcut (Optional)',
                    hintText: 'Enter shortcut code',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFFBBDEFB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kBlue, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    final pattern = RegExp(r'^[A-D][0-9]{1,4} ?$');
                    if (!pattern.hasMatch(value)) {
                      if (RegExp(r'^[0-9]+$').hasMatch(value)) {
                        return 'Shortcut cannot be only numbers. It must start with A, B, C, or D followed by 1-4 digits (e.g., A1, B12, C123, D1234).';
                      }
                      if (!RegExp(r'^[A-D]').hasMatch(value)) {
                        return 'Shortcut must start with A, B, C, or D (uppercase only).';
                      }
                      if (!RegExp(r'^[A-D][0-9]+$').hasMatch(value)) {
                        return 'Shortcut must be a letter (A-D) followed by 1-4 digits (e.g., A1, B12, C123, D1234).';
                      }
                      if (value.length > 5) {
                        return 'Shortcut can be at most 5 characters (1 letter + up to 4 digits).';
                      }
                      return 'Invalid shortcut format.';
                    }
                    // Check for duplicate shortcut (case-insensitive, except for current item)
                    final inventoryState = context.read<InventoryCubit>().state;
                    if (inventoryState is InventoryLoaded) {
                      final shortcutUpper = value.toUpperCase();
                      final duplicate = inventoryState.items.any((inv) {
                        if (item != null && inv.id == item.id) return false;
                        return (inv.shortcut ?? '').toUpperCase() ==
                            shortcutUpper;
                      });
                      if (duplicate) {
                        return 'This shortcut is already in use by another item.';
                      }
                    }
                    return null;
                  },
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1976D2))),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        side: BorderSide.none,
                      ),
                      child: Text(
                        'Save',
                        style: TextStyle(color: Colors.white),
                      ),
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          final newItem = InventoryItem(
                            id: item?.id,
                            name: nameController.text,
                            price: double.parse(priceController.text),
                            quantity: double.parse(quantityController.text),
                            shortcut: shortcutController.text.isEmpty
                                ? null
                                : shortcutController.text,
                          );

                          context.read<InventoryCubit>().saveInventoryItem(
                            newItem,
                          );
                          await _logInventoryActivity(item, newItem);
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logInventoryActivity(
    InventoryItem? oldItem,
    InventoryItem newItem,
  ) async {
    await ActivityRepository().logActivity(
      Activity(
        type: oldItem == null ? 'purchase_add' : 'purchase_edit',
        description: (oldItem == null ? 'Added' : 'Edited') + ' purchase item: ' + newItem.name,
        timestamp: DateTime.now(),
        metadata: {
          'id': newItem.id,
          'name': newItem.name,
          'price': newItem.price,
          'quantity': newItem.quantity,
          'shortcut': newItem.shortcut,
        },
      ),
    );
    await ActivityRepository().logActivity(
      Activity(
        type: oldItem == null ? 'inventory_add' : 'inventory_edit',
        description: (oldItem == null ? 'Added' : 'Edited') + ' inventory item: ' + newItem.name,
        timestamp: DateTime.now(),
        metadata: {
          'id': newItem.id,
          'name': newItem.name,
          'price': newItem.price,
          'quantity': newItem.quantity,
          'shortcut': newItem.shortcut,
        },
      ),
    );
  }

  Future<void> _deleteItem(BuildContext context, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      context.read<InventoryCubit>().deleteInventoryItem(id);
      await _logDeleteInventoryActivity(id);
    }
  }

  Future<void> _logDeleteInventoryActivity(int id) async {
    await ActivityRepository().logActivity(
      Activity(
        type: 'purchase_delete',
        description: 'Deleted purchase item with id: $id',
        timestamp: DateTime.now(),
        metadata: {'id': id},
      ),
    );
    await ActivityRepository().logActivity(
      Activity(
        type: 'inventory_delete',
        description: 'Deleted inventory item with id: $id',
        timestamp: DateTime.now(),
        metadata: {'id': id},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F0F0F) : kWhite,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A2233) : Colors.white,
        centerTitle: true,
        title: Text(
          'Purchase Management',
          style: TextStyle(
            fontSize: 22,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0A2342),
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: IconThemeData(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0A2342)),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      body: BlocBuilder<InventoryCubit, InventoryState>(
        builder: (context, state) {
          if (state is InventoryLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kBlue),
              ),
            );
          } else if (state is InventoryLoaded) {
            final items = _searchQuery.isEmpty
                ? state.items
                : state.items
                      .where(
                        (item) =>
                            item.name.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ) ||
                            (item.shortcut ?? '').toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ),
                      )
                      .toList();
            return _buildInventoryList(context, items);
          } else if (state is InventoryError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${state.message}',
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
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

  double _calculateTotal(List<InventoryItem> items) {
    return items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  int _calculateTotalQty(List<InventoryItem> items) {
    return items.fold(0, (sum, item) => sum + item.quantity.toInt());
  }
}
