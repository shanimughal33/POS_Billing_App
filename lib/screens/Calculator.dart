// ignore_for_file: unnecessary_null_comparison

import 'dart:async';
import 'package:forward_billing_app/providers/dashboard_provider.dart';
import 'package:forward_billing_app/screens/receipt_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:math_expressions/math_expressions.dart';
import '../models/bill_item.dart';
import '../repositories/bill_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/sales_cubit.dart';
import '../utils/shortcut_validator.dart';
import '../repositories/people_repository.dart';
import '../models/people.dart';
import '../models/bill.dart';
import '../models/inventory_item.dart';
import '../models/activity.dart';
import '../repositories/activity_repository.dart';
import '../themes/app_theme.dart';
import 'dart:ui'; // For BackdropFilter
import 'package:google_fonts/google_fonts.dart'; // For modern fonts
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/settings_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';

import '../utils/auth_utils.dart';
import '../utils/refresh_manager.dart';
import 'home_screen.dart';
import 'login_screen.dart' as login;
import '../screens/settings_screen.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedCustomer;
  String _selectedPaymentMethod = 'Cash';

  List<People> _customerList = [];
  final PeopleRepository _peopleRepo = PeopleRepository();

  final List<String> _paymentOptions = ['Cash', 'Credit', 'Online'];

  String quantityValue = '';
  String priceValue = '';
  bool isEditingQuantity = false;

  // Initialize controllers and focus nodes immediately
  final priceFocus = FocusNode();
  final quantityFocus = FocusNode();
  final itemNameFocus = FocusNode();
  final priceController = TextEditingController();
  final quantityController = TextEditingController();
  final itemNameController = TextEditingController();

  // Add these properties at the start of class
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  // Remove late keywords and make nullable
  AnimationController? _searchAnimationController;
  Animation<double>? _searchAnimation;
  bool _isSearchVisible = false;

  // Add repository
  final BillRepository _billRepository = BillRepository();
  late final Bill bill;

  // Add this variable to track editing state
  BillItem? _editingItem;

  // Add parser instance
  final Parser _parser = Parser();
  final ContextModel _context = ContextModel();

  // Add or update these properties
  String? _pendingShortcut;
  Timer? _shortcutTimer;
  bool _isWaitingForNumber = false;

  // Add these properties to _CustomerBillScreenState:
  String _shortcutBuffer = '';
  Timer? _shortcutEntryTimer;
  static const Duration _shortcutEntryTimeout = Duration(milliseconds: 1500);

  // Add state for pressed button for animation
  String? _pressedButton;

  // Add shimmer effect for total
  Widget _shimmerTotal(String value) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOut,
      builder: (context, t, child) {
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              colors: [
                Colors.white.withOpacity(0.7),
                Colors.blue.withOpacity(0.7),
                Colors.white.withOpacity(0.7),
              ],
              stops: [t - 0.2, t, t + 0.2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              tileMode: TileMode.mirror,
            ).createShader(rect);
          },
          child: child,
          blendMode: BlendMode.srcATop,
        );
      },
      child: Text(
        value,
        style: GoogleFonts.urbanist(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold, // ensure bold
          letterSpacing: 0.5,
          shadows: [
            Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
      ),
    );
  }

  double _discount = 0.0;
  int _dropdownKey = 0;

  // Temporary tracker for real-time inventory validation
  Map<String, double> _tempUsedQty =
      {}; // key: itemName|price, value: used qty in cart

  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _initializeSearchAnimation();
    _fetchCustomers();
    _loadDiscount();
    // Always load inventory on open
    Future.microtask(() async {
      if (!mounted) return;
      final inventoryCubit = context.read<InventoryCubit>();
      final uid = await getCurrentUserUid();
      if (uid != null && mounted) {
        inventoryCubit.loadInventory(userId: uid);
        // Set per-user cart isolation
        if (_lastUserId != uid && mounted) {
          context.read<SalesCubit>().setCurrentUser(uid);
          _lastUserId = uid;
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // On dependencies change, ensure cart is for correct user
    Future.microtask(() async {
      if (!mounted) return;
      final uid = await getCurrentUserUid();
      if (uid != null && _lastUserId != uid && mounted) {
        context.read<SalesCubit>().setCurrentUser(uid);
        _lastUserId = uid;
      }
    });
    // Unfocus the search bar when returning to this screen
    // _searchFocusNode.unfocus(); // This line was not in the new_code, so it's removed.
  }

  void _initializeSearchAnimation() {
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController!,
      curve: Curves.easeInOut,
    );
  }

  void dispose() {
    _searchAnimationController?.dispose();
    _searchController.dispose();
    priceFocus.dispose();
    quantityFocus.dispose();
    itemNameFocus.dispose();
    priceController.dispose();
    quantityController.dispose();
    itemNameController.dispose();
    _shortcutTimer?.cancel();
    _shortcutEntryTimer?.cancel();
    super.dispose();
  }

  void _showCalculator(bool forQuantity) {
    if (isEditingQuantity != forQuantity) {
      if (mounted) {
        setState(() {
          isEditingQuantity = forQuantity;
        });
      }
    }

    // Immediate focus and cursor positioning
    if (forQuantity) {
      quantityFocus.requestFocus();
      quantityController.selection = TextSelection.fromPosition(
        TextPosition(offset: quantityController.text.length),
      );
    } else {
      priceFocus.requestFocus();
      priceController.selection = TextSelection.fromPosition(
        TextPosition(offset: priceController.text.length),
      );
    }
  }

  // Add these properties
  String? _pendingOperation;
  double? _lastNumber;

  void _onCalculatorButtonPressed(String value) {
    // Handle shortcut entry
    if (RegExp(r'^[A-D]$').hasMatch(value)) {
      debugPrint(
        'Shortcut key pressed: $value, current buffer: $_shortcutBuffer',
      );
      _dismissKeyboard();
      _shortcutBuffer = value;
      debugPrint('Shortcut buffer set to: $_shortcutBuffer');
      _updateShortcutPreview();
      _startShortcutEntryTimer();
      if (mounted) {
        setState(() {});
      }
      return;
    }

    // Handle shortcut entry continuation
    if (_shortcutBuffer.isNotEmpty) {
      debugPrint(
        'Shortcut continuation: value=$value, buffer=$_shortcutBuffer',
      );
      if (value == 'Enter') {
        debugPrint('Enter pressed, processing shortcut immediately');
        _dismissKeyboard();
        _shortcutEntryTimer?.cancel();
        _processShortcutBuffer();
        return;
      }
      if (_shortcutBuffer.contains('x')) {
        if (RegExp(r'[0-9]').hasMatch(value)) {
          _dismissKeyboard();
          final newBuffer = _shortcutBuffer + value;
          if (ShortcutValidator.isValidShortcutFormat(newBuffer)) {
            _shortcutBuffer = newBuffer;
            _updateShortcutPreview();
            _startShortcutEntryTimer();
            if (mounted) {
              setState(() {});
            }
          }
        }
        return;
      }
      if (value == '*' && !_shortcutBuffer.contains('x')) {
        _dismissKeyboard();
        _shortcutBuffer += 'x';
        _updateShortcutPreview();
        _startShortcutEntryTimer();
        if (mounted) {
          setState(() {});
        }
        return;
      }
      if (RegExp(r'[0-9]').hasMatch(value)) {
        _dismissKeyboard();
        final newBuffer = _shortcutBuffer + value;
        debugPrint(
          'Numeric input for shortcut: value=$value, newBuffer=$newBuffer',
        );
        if (newBuffer.length <= 6) {
          _shortcutBuffer = newBuffer;
          debugPrint('Shortcut buffer updated to: $_shortcutBuffer');
          _updateShortcutPreview();
          _startShortcutEntryTimer();
          if (mounted) {
            setState(() {});
          }
        }
      }
      return;
    }
    if (mounted) {
      setState(() {
        if (['+', '-', '*', '÷', '%'].contains(value)) {
          if (!isEditingQuantity && value == '*') {
            _showCalculator(true);
            return;
          }
          _handleOperation(value);
        } else if (value == 'Del') {
          _handleDelete();
        } else if (value == 'AC') {
          _clearAll();
        } else {
          _handleNumberInput(value);
        }
      });
    }
  }

  void _dismissKeyboard() {
    // Only unfocus the item name field to dismiss keyboard
    // Don't unfocus other fields as they might interfere with shortcut processing
    itemNameFocus.unfocus();
    // Use a small delay to ensure keyboard dismissal doesn't interfere with button presses
    Future.delayed(Duration(milliseconds: 50), () {
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _startShortcutMode(String key) {
    // Unfocus the item name field to close keyboard when shortcut is pressed
    _dismissKeyboard();
    _pendingShortcut = key;
    _isWaitingForNumber = true;
    _shortcutTimer?.cancel();
    _shortcutTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _clearShortcutState();
      }
      // Timer expired without a number press - shortcut already handled
    });
    if (mounted) {
      setState(() {}); // Refresh UI to show active state
    }
  }

  void _clearShortcutState() {
    if (!mounted) return;
    setState(() {
      _pendingShortcut = null;
      _isWaitingForNumber = false;
      _shortcutTimer?.cancel();
    });
  }

  void _handleShortcut(String key) {
    // Use InventoryCubit to look up inventory item by shortcut
    final inventoryState = context.read<InventoryCubit>().state;
    List inventoryList = [];
    if (inventoryState is InventoryLoaded) {
      inventoryList = inventoryState.items
          .where((i) => i.isSold == false)
          .toList();
    }
    final item = inventoryList.firstWhere(
      (inv) =>
          (inv.shortcut ?? '').trim().toUpperCase() == key.trim().toUpperCase(),
      orElse: () => null,
    );
    if (item != null) {
      // Check if item is out of stock (quantity is 0 or less)
      if (item.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Out of stock!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Guard against exceeding available stock considering what is already in the cart
      final salesCubit = context.read<SalesCubit>();
      final alreadyAddedQty = salesCubit.items
          .where(
            (i) =>
                i.name.trim().toLowerCase() == item.name.trim().toLowerCase(),
          )
          .fold<double>(0.0, (sum, i) => sum + i.quantity);
      if (alreadyAddedQty + 1 > item.quantity) {
        final remaining = (item.quantity - alreadyAddedQty).toInt();
        final msg = remaining <= 0
            ? 'Insufficient stock! You\'ve already added the maximum available for ${item.name}.'
            : 'Insufficient stock! ${item.name}: you can add up to $remaining more.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
        return;
      }

      // Add 1 item by default for shortcuts
      context.read<SalesCubit>().addBillItem(
        BillItem(serialNo: 0, name: item.name, price: item.price, quantity: 1),
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${item.name} to bill'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No item found for shortcut $key'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleOperation(String operation) {
    if (isEditingQuantity) {
      if (quantityValue.isEmpty && operation != '-') {
        return; // Prevent leading operators other than minus
      }
      if (RegExp(r'[+\-*/%]$').hasMatch(quantityValue.trim())) {
        return; // Prevent consecutive operators
      }
      quantityValue = '${quantityValue.trim()} $operation ';
      quantityController.text = quantityValue;
    } else {
      if (priceValue.isEmpty && operation != '-') {
        return;
      }
      if (RegExp(r'[+\-*/%]$').hasMatch(priceValue.trim())) {
        return;
      }
      if (operation == '*') {
        _showCalculator(true);
        return;
      }
      priceValue = '${priceValue.trim()} $operation ';
      priceController.text = priceValue;
    }
  }

  String _parseExpression(String input) {
    try {
      if (input.isEmpty) return '';
      input = input.trim();

      // Prevent division by zero
      if (input.contains('/ 0')) {
        return 'Error';
      }

      // Handle percentage calculations
      if (input.contains('%')) {
        final parts = input.split('%').map((s) => s.trim()).toList();
        if (parts.length == 2) {
          final base = double.parse(parts[0]);
          final percentage = parts[1].isEmpty ? 0 : double.parse(parts[1]);
          final result = (base * percentage) / 100;
          return result.toStringAsFixed(0);
        }
      }

      // Remove spaces and normalize operators
      input = input
          .replaceAll(' ', '')
          .replaceAll('x', '*')
          .replaceAll('÷', '/');

      // If ends with operator, don't evaluate
      if (RegExp(r'[+\-*/%]$').hasMatch(input)) {
        return input;
      }

      // Parse and evaluate
      Expression exp = _parser.parse(input);
      double result = exp.evaluate(EvaluationType.REAL, _context);

      // Format result without decimal places
      return result.toStringAsFixed(0);
    } catch (e) {
      return 'Error';
    }
  }

  // Method removed as it was duplicated

  void _handleNumberInput(String value) {
    if (value == '.' &&
        ((isEditingQuantity && quantityValue.contains('.')) ||
            (!isEditingQuantity && priceValue.contains('.')))) {
      return; // Prevent multiple decimal points
    }

    setState(() {
      if (isEditingQuantity) {
        String newValue = quantityValue + value;
        quantityValue = newValue;
        // Parse and evaluate expression
        String result = _parseExpression(newValue);
        quantityController.text = result;
      } else {
        String newValue = priceValue + value;
        priceValue = newValue;
        // Parse and evaluate expression
        String result = _parseExpression(newValue);
        priceController.text = result;
      }
    });
  }

  void _clearAll() {
    if (isEditingQuantity) {
      quantityValue = '';
      quantityController.clear();
    } else {
      priceValue = '';
      priceController.clear();
    }
    _lastNumber = null;
    _pendingOperation = null;
  }

  void _clearCurrentInput() {
    if (isEditingQuantity) {
      quantityValue = '';
      quantityController.clear();
    } else {
      priceValue = '';
      priceController.clear();
    }
  }

  void _handleDelete() {
    if (isEditingQuantity) {
      if (quantityValue.isNotEmpty) {
        quantityValue = quantityValue.substring(0, quantityValue.length - 1);
        quantityController.text = quantityValue;
      }
    } else {
      if (priceValue.isNotEmpty) {
        priceValue = priceValue.substring(0, priceValue.length - 1);
        priceController.text = priceValue;
      }
    }
  }

  double _calculateResult(double a, double b, String operation) {
    switch (operation) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '*':
        return a * b;
      case '÷':
        if (b == 0) return a; // Prevent division by zero
        return a / b;
      case '%':
        // Calculate b% of a (percentage)
        return (a * b) / 100;
      default:
        return b;
    }
  }

  // Add this validation method
  String? validateInputs() {
    try {
      if (priceValue.isEmpty) return 'Please enter a price';

      // Set default quantity to 1 if empty
      if (quantityValue.isEmpty) {
        quantityValue = "1";
        quantityController.text = "1";
      }

      // Evaluate expressions before validation
      String priceResult = _parseExpression(priceValue);
      String quantityResult = _parseExpression(quantityValue);

      // Parse final values
      double price = double.parse(priceResult);
      double quantity = double.parse(quantityResult);

      // Update the controller values with evaluated results
      priceValue = price.toString();
      quantityValue = quantity.toString();
      priceController.text = priceValue;
      quantityController.text = quantityValue;

      if (price <= 0) return 'Price must be greater than 0';
      if (quantity <= 0) return 'Quantity must be greater than 0';

      // Check inventory availability
      final inventoryState = context.read<InventoryCubit>().state;
      if (inventoryState is InventoryLoaded) {
        final itemName = itemNameController.text.trim();
        if (itemName.isNotEmpty) {
          // Find matching inventory item by name
          final matchingItems = inventoryState.items
              .where(
                (inv) =>
                    inv.name.trim().toLowerCase() == itemName.toLowerCase(),
              )
              .toList();

          if (matchingItems.isNotEmpty) {
            final inventoryItem = matchingItems.first;

            // Check if item is out of stock
            if (inventoryItem.quantity <= 0) {
              return 'Out of stock! ${inventoryItem.name} has no items available.';
            }

            // Temporary UI-only validation: ensure total requested (already in cart + this request)
            // does not exceed available stock in inventory.
            final salesCubit = context.read<SalesCubit>();
            final alreadyAddedQty = salesCubit.items
                .where(
                  (i) =>
                      i.name.trim().toLowerCase() ==
                      inventoryItem.name.trim().toLowerCase(),
                )
                .fold<double>(0.0, (sum, i) => sum + i.quantity);
            final remaining = inventoryItem.quantity - alreadyAddedQty;

            if (remaining <= 0) {
              return 'Insufficient stock! You\'ve already added the maximum available for ${inventoryItem.name}.';
            }

            if (quantity > remaining) {
              final canAdd = remaining.toInt();
              return 'Insufficient stock! ${inventoryItem.name} has only ${inventoryItem.quantityAsInt} available. You\'ve already added ${alreadyAddedQty.toInt()}. You can add up to $canAdd more.';
            }
          }
        }
      }

      return null;
    } catch (e) {
      return 'Invalid input values';
    }
  }

  // Add this method to clear inputs
  void clearInputs() {
    setState(() {
      itemNameController.clear();
      priceValue = '';
      quantityValue = '';
      priceController.clear();
      quantityController.clear();
      _editingItem = null;
      _lastNumber = null;
      _pendingOperation = null;

      // Clear shortcut buffer
      _shortcutBuffer = '';
      _shortcutEntryTimer?.cancel();

      // Set focus back to price field
      _showCalculator(false);
    });
  }

  // Refactor _getDefaultItemName to use Cubit state
  String _getDefaultItemName() {
    final state = context.read<SalesCubit>().state;
    if (state is SalesUpdated) {
      final existingNames = state.items
          .where((item) => item.name.startsWith('Item '))
          .map((item) => int.tryParse(item.name.replaceFirst('Item ', '')))
          .where((x) => x != null)
          .cast<int>()
          .toSet();
      int idx = 1;
      while (existingNames.contains(idx)) {
        idx++;
      }
      return 'Item $idx';
    }
    return 'Item 1';
  }

  // Extracts the numeric suffix from default item names like 'Item 1', case-insensitive
  // Returns null if name is not a default-form name
  int? _extractDefaultItemNumber(String name) {
    final match = RegExp(
      r'^item\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(name.trim());
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  // In addBillItem, after a successful add, clear price/qty and set itemNameController.text to _getDefaultItemName()
  Future<void> addBillItem() async {
    final validationError = validateInputs();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError), backgroundColor: Colors.red),
      );
      return;
    }

    final priceResult = _parseExpression(priceValue);
    final quantityResult = _parseExpression(quantityValue);

    if (priceResult == 'Error' || quantityResult == 'Error') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid calculation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    double finalPrice = double.parse(priceResult);
    double finalQuantity = double.parse(quantityResult);
    final salesCubit = context.read<SalesCubit>();
    // Get current inventory
    final inventoryState = context.read<InventoryCubit>().state;
    List<InventoryItem> inventoryList = [];
    if (inventoryState is InventoryLoaded) {
      inventoryList = inventoryState.items;
    }
    String itemName = itemNameController.text.trim();
    if (itemName.isEmpty) {
      itemName = _getDefaultItemName();
    }
    // Normalize default item names for merging
    String normalizedItemName = itemName;
    final int? defaultNumber = _extractDefaultItemNumber(itemName);
    if (defaultNumber != null) {
      // Standardize casing/spacing
      normalizedItemName = 'Item $defaultNumber';
      debugPrint(
        'Calculator: Normalized default name "$itemName" to "$normalizedItemName"',
      );
    }
    // Find inventory item
    final InventoryItem? invItem = inventoryList.firstWhereOrNull(
      (inv) =>
          inv.name.trim().toLowerCase() == itemName.trim().toLowerCase() &&
          inv.price == finalPrice,
    );
    if (invItem != null) {
      // Calculate used quantity in cart
      final key = '${invItem.name}|${invItem.price}';
      double usedQty = 0.0;
      for (final item in salesCubit.items) {
        if (item.name.trim().toLowerCase() ==
                invItem.name.trim().toLowerCase() &&
            item.price == invItem.price) {
          usedQty += item.quantity;
        }
      }
      // If editing, subtract the old quantity
      if (_editingItem != null &&
          _editingItem!.name.trim().toLowerCase() ==
              invItem.name.trim().toLowerCase() &&
          _editingItem!.price == invItem.price) {
        usedQty -= _editingItem!.quantity;
      }
      if (usedQty + finalQuantity > invItem.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item is out of stock'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    if (_editingItem != null) {
      final updatedItem = BillItem(
        id: _editingItem!.id,
        serialNo: _editingItem!.serialNo,
        name: itemNameController.text.trim().isNotEmpty
            ? itemNameController.text.trim()
            : _editingItem!.name,
        price: finalPrice,
        quantity: finalQuantity,
      );
      if (_editingItem!.id != null) {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        final currentBillId = bill.id;
        if (userId != null) {
          await _billRepository.updateBillItem(
            userId,
            currentBillId!,
            updatedItem,
          );
        }
      } else {
        // Update in-memory cart item
        salesCubit.updateCartItem(_editingItem!, updatedItem);
      }
    } else {
      // Check for existing item (merge by normalized name and price)
      final existingIndex = salesCubit.items.indexWhere((item) {
        // For default names, compare by numeric suffix (case-insensitive) and price
        if (defaultNumber != null) {
          final itemNumber = _extractDefaultItemNumber(item.name);
          if (itemNumber != null) {
            final isSameDefaultName =
                itemNumber == defaultNumber && item.price == finalPrice;
            debugPrint(
              'Calculator: Comparing default names - Item $itemNumber vs Item $defaultNumber, price match: ${item.price == finalPrice}, result: $isSameDefaultName',
            );
            return isSameDefaultName;
          }
        }
        // For non-default names, use the original logic
        final nameMatch =
            item.name.trim().toLowerCase() ==
            normalizedItemName.trim().toLowerCase();
        final priceMatch = item.price == finalPrice;
        debugPrint(
          'Calculator: Comparing non-default names - "${item.name}" vs "$normalizedItemName", price match: $priceMatch, result: ${nameMatch && priceMatch}',
        );
        return nameMatch && priceMatch;
      });
      if (existingIndex != -1) {
        // Update quantity of existing item
        final existingItem = salesCubit.items[existingIndex];
        final updatedItem = existingItem.copyWith(
          quantity: existingItem.quantity + finalQuantity,
        );
        debugPrint(
          'Calculator: Merging items - Existing: ${existingItem.name} (qty: ${existingItem.quantity}), New qty: $finalQuantity, Total: ${updatedItem.quantity}',
        );
        salesCubit.updateCartItem(existingItem, updatedItem);
      } else {
        final newItem = BillItem(
          serialNo: 0,
          name: itemName,
          price: finalPrice,
          quantity: finalQuantity,
        );
        debugPrint(
          'Calculator: Adding new item - Name: $itemName, Price: $finalPrice, Qty: $finalQuantity',
        );
        await salesCubit.addBillItem(newItem);
      }
    }
    // Clear price and quantity fields, set item name to next default
    priceController.clear();
    quantityController.clear();
    priceValue = '';
    quantityValue = '';
    _updateItemNameField();
    _shortcutBuffer = '';
    _editingItem = null;
    setState(() {});
  }

  // Update toggle search method
  void _toggleSearch() {
    if (!mounted || _searchAnimationController == null) return;

    if (mounted) {
      setState(() {
        _isSearchVisible = !_isSearchVisible;
        if (_isSearchVisible) {
          _searchAnimationController?.forward();
        } else {
          _searchAnimationController?.reverse();
          _searchController.clear();
        }
      });
    }
  }

  // Search handler for text field changes
  void _handleSearch(String searchText) {
    context.read<SalesCubit>().searchItems(searchText);
  }

  // Create bill handler
  void _handleCreateBill() async {
    if (context.read<SalesCubit>().items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot create bill - no items added'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final List<BillItem> billItems = List.from(
        context.read<SalesCubit>().items,
      );
      // Compute monetary breakdown
      final double subTotal = BillItem.calculateBillTotal(billItems);
      final double discountPercent = (_discount.clamp(0, 100));
      final double discountAmount = subTotal * (discountPercent / 100);
      final DateTime billDate = DateTime.now();
      final String customer = _selectedCustomer ?? 'Walk-in Customer';
      final String paymentMethod = _selectedPaymentMethod;
      final int billNumber = DateTime.now().millisecondsSinceEpoch % 1000000;

      // Resolve current user id for settings and saving
      final uid = await getCurrentUserUid();

      // Load tax from settings
      final settingsRepo = SettingsRepository();
      final settings = (uid != null && uid.isNotEmpty)
          ? await settingsRepo.getSettings(uid)
          : null;
      final double taxPercent =
          double.tryParse(settings?.taxRate ?? '0') ?? 0.0;
      final double taxAmount = (subTotal - discountAmount) * (taxPercent / 100);
      final double billTotal = subTotal - discountAmount + taxAmount;

      // *** Save Bill and its items ***
      final BillRepository billRepo = BillRepository();
      final bill = Bill(
        id: billNumber.toString(),
        date: billDate,
        customerName: customer,
        paymentMethod: paymentMethod,
        items: billItems,
        subTotal: subTotal,
        discount: discountPercent,
        tax: taxPercent,
        total: billTotal,
      );
      debugPrint('Calculator: Creating bill with UID: $uid');
      debugPrint('Calculator: Bill object: ${bill.toString()}');
      if (uid == null || uid.isEmpty) {
        debugPrint('Calculator: ERROR: UID is null or empty when saving bill!');
        return;
      }
      await billRepo.insertBillWithItems(bill, uid);
      debugPrint('Calculator: Bill inserted for UID: $uid');

      // Trigger refresh for all screens
      final refreshManager = Provider.of<RefreshManager>(
        context,
        listen: false,
      );
      refreshManager.refreshSales();
      refreshManager.refreshInventory();
      refreshManager.refreshDashboard();

      // Also trigger dashboard refresh directly
      final provider = Provider.of<DashboardProvider>(context, listen: false);

      await ActivityRepository().logActivity(
        Activity(
          userId: uid,
          type: 'sale_add',
          description: 'Created bill for $customer, total: Rs $billTotal',
          timestamp: DateTime.now(),
          metadata: {'id': bill.id, 'customer': customer, 'total': billTotal},
        ),
      );

      // *** Ensure cart is cleared before bill creation ***
      await context.read<SalesCubit>().clearItems();

      // Navigate to receipt screen
      if (!mounted) return;
      await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              ReceiptScreen(
                items: billItems,
                total: billTotal,
                customerName: customer,
                paymentMethod: paymentMethod,
                dateTime: billDate,
                billNumber: billNumber,
                discount: _discount,
              ),
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0); // Slide from right
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            final tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            final offsetAnimation = animation.drive(tween);
            return SlideTransition(position: offsetAnimation, child: child);
          },
        ),
      );

      // Update inventory after sale (handles quantity reduction and marking as sold when quantity reaches 0)
      if (uid != null) {
        await context.read<InventoryCubit>().updateInventoryAfterSale(
          billItems,
          uid,
        );
      }

      // Refresh SalesCubit inventory after sale
      final inventoryCubit = context.read<InventoryCubit>();
      final salesCubit = context.read<SalesCubit>();
      final latestInventory = inventoryCubit.items;
      salesCubit.updateInventory(latestInventory);

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill created successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Reset input fields
      _updateItemNameField();
      priceController.clear();
      quantityController.clear();
      priceValue = '';
      quantityValue = '';
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error creating bill: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create bill'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double totalAmount(BuildContext context) {
    final state = context.watch<SalesCubit>().state;
    if (state is SalesUpdated) {
      return state.items.fold(0.0, (sum, item) => sum + item.total);
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocConsumer<InventoryCubit, InventoryState>(
      listenWhen: (previous, current) => current is InventoryLoaded,
      listener: (context, inventoryState) {
        if (inventoryState is InventoryLoaded) {
          // Whenever inventory changes, update SalesCubit inventory cache
          context.read<SalesCubit>().updateInventory(inventoryState.items);
        }
      },
      builder: (context, inventoryState) {
        if (inventoryState is InventoryLoading ||
            inventoryState is InventoryInitial) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF128C7E)),
              ),
            ),
          );
        }
        // Main sales UI
        return BlocListener<SalesCubit, SalesState>(
          listener: (context, state) {
            if (state is SalesUpdated) {
              // Always update input fields based on Cubit state
              _updateItemNameField();
              priceController.clear();
              quantityController.clear();
              priceValue = '';
              quantityValue = '';
              setState(() {});
            } else if (state is SalesError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF0F0F0F)
                : Theme.of(context).scaffoldBackgroundColor,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(87),

              child: Container(
                padding: const EdgeInsets.fromLTRB(5, 6, 0, 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1A2233)
                      : null,
                  gradient: Theme.of(context).brightness == Brightness.dark
                      ? null
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Colors.blue.shade50],
                        ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF1976D2).withOpacity(0.13),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),

                child: SafeArea(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Back Button
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios,
                          color: isDark
                              ? Colors.blue
                              : const Color.fromARGB(255, 1, 64, 116),
                          size: 16,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),

                      // Dropdowns Column
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Add Customer Dropdown
                            Container(
                              height: 30,
                              width: 140,
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF0A2342).withOpacity(0.13),
                                    blurRadius: 16,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  key: ValueKey(_dropdownKey),
                                  isExpanded: true,
                                  value: _customerList.isEmpty
                                      ? null
                                      : _selectedCustomer,
                                  hint: Text(
                                    '+ Add Customer',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 20,
                                    color: Colors.blue,
                                  ),
                                  dropdownColor: Theme.of(context).cardColor,
                                  onChanged: (String? newValue) async {
                                    if (_customerList.isEmpty) return;
                                    // Normalize the special option value (supports both 'Add more' and 'Add_more')
                                    final isAddMore =
                                        newValue == 'Add more' ||
                                        newValue == 'Add_more';
                                    if (isAddMore) {
                                      setState(() {
                                        _dropdownKey++;
                                      });
                                      await Future.delayed(
                                        const Duration(milliseconds: 50),
                                      );
                                      // Navigate to Peoples screen, Customers tab (index 1)
                                      await Navigator.pushNamed(
                                        context,
                                        '/peoples',
                                        arguments: {'tab': 1},
                                      );
                                      // Refresh local customers after returning
                                      await _fetchCustomers();
                                      return;
                                    }
                                    setState(() {
                                      _selectedCustomer = newValue;
                                    });
                                  },
                                  selectedItemBuilder: (context) {
                                    if (_customerList.isEmpty) {
                                      return [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.person_outline,
                                              color: Colors.grey,
                                              size: 16,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'No customers',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ];
                                    }
                                    return _customerList.map((People customer) {
                                      return Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Color(
                                              0xFF1E8858,
                                            ).withOpacity(0.13),
                                            child: Text(
                                              customer.name.isNotEmpty
                                                  ? customer.name[0]
                                                        .toUpperCase()
                                                  : '',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            customer.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.blue,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList();
                                  },
                                  items: _customerList.isEmpty
                                      ? [
                                          DropdownMenuItem<String>(
                                            enabled: false,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.person_outline,
                                                      color: Colors.grey,
                                                      size: 16,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'No customers',
                                                      style: TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 8),
                                                GestureDetector(
                                                  onTap: () async {
                                                    setState(() {
                                                      _dropdownKey++;
                                                    });
                                                    await Future.delayed(
                                                      const Duration(
                                                        milliseconds: 50,
                                                      ),
                                                    );
                                                    await Navigator.pushNamed(
                                                      context,
                                                      '/peoples',
                                                      arguments: {'tab': 1},
                                                    );
                                                    await _fetchCustomers();
                                                  },
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .add_circle_outline,
                                                        color: Color(
                                                          0xFF1976D2,
                                                        ),
                                                        size: 18,
                                                      ),
                                                      SizedBox(width: 6),
                                                      Text(
                                                        'Add One',
                                                        style: TextStyle(
                                                          color: Color(
                                                            0xFF1976D2,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ]
                                      : [
                                          ..._customerList.map((
                                            People customer,
                                          ) {
                                            return DropdownMenuItem<String>(
                                              value: customer.name,
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 12,
                                                    backgroundColor:
                                                        (Colors.blue)
                                                            .withOpacity(0.13),
                                                    child: Text(
                                                      customer.name.isNotEmpty
                                                          ? customer.name[0]
                                                                .toUpperCase()
                                                          : '',
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFF1E8858,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    customer.name,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.blue,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          // Add the '+ Add more' option always at the bottom
                                          DropdownMenuItem<String>(
                                            value: 'Add_more',
                                            enabled: true,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.add_circle_outline,
                                                  color: Color(0xFF1976D2),
                                                  size: 18,
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  ' Add more',
                                                  style: TextStyle(
                                                    color: Color(0xFF1976D2),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                ),
                              ),
                            ),

                            // Payment Method Dropdown
                            Container(
                              height: 30,
                              width: 140,
                              margin: const EdgeInsets.only(left: 0),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF0A2342).withOpacity(0.13),
                                    blurRadius: 16,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedPaymentMethod,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.blue,
                                  ),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedPaymentMethod = newValue!;
                                    });
                                  },
                                  items: _paymentOptions.map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Center(
                                        child: Text(
                                          value,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.blue,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // PKR Total Column
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF0A2342).withOpacity(0.13),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          margin: const EdgeInsets.only(right: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Rs ',
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight:
                                          FontWeight.bold, // ensure bold
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Flexible(
                                    child: _shimmerTotal(
                                      totalAmount(context).toStringAsFixed(2),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              GestureDetector(
                                onTap: () {
                                  _discountController.text = _discount
                                      .toStringAsFixed(0);
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                        'Edit Discount',
                                        style: GoogleFonts.poppins(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : const Color(0xFF1976D2),
                                        ),
                                      ),
                                      content: TextField(
                                        controller: _discountController,
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: InputDecoration(
                                          hintText: 'Enter discount percentage',
                                          suffixText: '%',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text(
                                            'Cancel',
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF1976D2),
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            final newDiscount = double.tryParse(
                                              _discountController.text,
                                            );
                                            if (newDiscount != null &&
                                                newDiscount >= 0 &&
                                                newDiscount <= 100) {
                                              setState(
                                                () => _discount = newDiscount,
                                              );
                                              Navigator.pop(context);
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Please enter a valid discount (0-100)',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF1976D2,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: Text(
                                            'Save',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Discount: ${_discount.toStringAsFixed(0)}%',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 11,
                                        decoration: TextDecoration.underline,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            body: Column(
              children: [
                // Header row
                Expanded(
                  child: Column(
                    children: [
                      // Header row
                      Container(
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF64B5F6), // lighter blue at top
                              Color(0xFF1976D2), // deeper blue at bottom
                            ],
                          ),
                          borderRadius: BorderRadius.zero,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF1976D2).withOpacity(0.08),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(
                                'NO',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  letterSpacing: 0.3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: Text(
                                'PRODUCT',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  letterSpacing: 0.3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'QTY',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  letterSpacing: 0.3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'AMOUNT',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  letterSpacing: 0.3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Cart list
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(18),
                              bottomRight: Radius.circular(18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF1976D2).withOpacity(0.04),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CartListView(itemBuilder: _buildListItem),
                        ),
                      ),
                    ],
                  ),
                ),

                // Input fields and calculator section (fixed at bottom)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Input fields row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 6.0,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0B1E3A).withOpacity(0.72)
                                  : Theme.of(context).cardColor.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isDark
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF3D5AFE).withOpacity(0.18),
                                        blurRadius: 16,
                                        spreadRadius: 0.5,
                                        offset: const Offset(0, 6),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.35),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF3D5AFE).withOpacity(0.22)
                                    : const Color(0xFFE3F2FD),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isDark
                                              ? Colors.black.withOpacity(0.35)
                                              : Colors.black.withOpacity(0.08),
                                          blurRadius: isDark ? 10 : 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller: itemNameController,
                                      focusNode: itemNameFocus,
                                      keyboardType: TextInputType.text,
                                      onEditingComplete: () {
                                        FocusScope.of(context).requestFocus(priceFocus);
                                      },
                                      decoration: InputDecoration(
                                        hintText: _getNextItemSerialName(),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        filled: true,
                                        fillColor: isDark
                                            ? const Color(0xFF102A43)
                                            : Colors.white,
                                        hintStyle: GoogleFonts.poppins(
                                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF3D5AFE).withOpacity(0.35)
                                                : Colors.black12,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF64B5F6)
                                                : Theme.of(context).primaryColor,
                                            width: 1.3,
                                          ),
                                        ),
                                      ),
                                      cursorColor: AppTheme.getCursorColor(context),
                                      style: GoogleFonts.poppins(
                                        color: isDark ? Colors.white : null,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isDark
                                              ? Colors.black.withOpacity(0.35)
                                              : Colors.black.withOpacity(0.08),
                                          blurRadius: isDark ? 10 : 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      readOnly: true,
                                      controller: priceController,
                                      focusNode: priceFocus,
                                      onTap: () => _showCalculator(false),
                                      onEditingComplete: () {
                                        FocusScope.of(context).requestFocus(quantityFocus);
                                      },
                                      cursorWidth: 2,
                                      cursorHeight: 24,
                                      cursorColor: AppTheme.getCursorColor(context),
                                      showCursor: true,
                                      style: GoogleFonts.poppins(
                                        color: isDark ? Colors.white : null,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'eg: 100',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                        filled: true,
                                        fillColor: isDark
                                            ? const Color(0xFF102A43)
                                            : Colors.white,
                                        hintStyle: GoogleFonts.poppins(
                                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF3D5AFE).withOpacity(0.35)
                                                : Colors.black12,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF64B5F6)
                                                : Theme.of(context).primaryColor,
                                            width: 1.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isDark
                                              ? Colors.black.withOpacity(0.35)
                                              : Colors.black.withOpacity(0.08),
                                          blurRadius: isDark ? 10 : 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      readOnly: true,
                                      controller: quantityController,
                                      focusNode: quantityFocus,
                                      onTap: () => _showCalculator(true),
                                      cursorWidth: 2,
                                      cursorHeight: 24,
                                      cursorColor: AppTheme.getCursorColor(context),
                                      showCursor: true,
                                      textAlign: TextAlign.left,
                                      style: GoogleFonts.poppins(
                                        color: isDark ? Colors.white : null,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'eg: 2',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                        filled: true,
                                        fillColor: isDark
                                            ? const Color(0xFF102A43)
                                            : Colors.white,
                                        hintStyle: GoogleFonts.poppins(
                                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF3D5AFE).withOpacity(0.35)
                                                : Colors.black12,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF64B5F6)
                                                : Theme.of(context).primaryColor,
                                            width: 1.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).cardColor.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: 20,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 4,
                                        crossAxisSpacing: 6,
                                        mainAxisSpacing: 6,
                                        childAspectRatio:
                                            1.7, // Wider but still tall enough
                                      ),
                                  itemBuilder: (context, index) {
                                    final List<String> buttonTexts = [
                                      'A',
                                      'B',
                                      'C',
                                      'D',
                                      'Del',
                                      'AC',
                                      '%',
                                      '÷',
                                      '7',
                                      '8',
                                      '9',
                                      '*',
                                      '4',
                                      '5',
                                      '6',
                                      '-',
                                      '1',
                                      '2',
                                      '3',
                                      '+',
                                    ];
                                    final String buttonText =
                                        buttonTexts[index];

                                    // Add visual feedback for pending shortcuts
                                    Color bgColor = _getButtonColor(buttonText);
                                    if (_pendingShortcut != null &&
                                        buttonText == _pendingShortcut) {
                                      bgColor = Colors
                                          .green
                                          .shade700; // Highlight active shortcut button
                                    }

                                    return _buildCalculatorButton(
                                      buttonText,
                                      bgColor,
                                      _getTextColor(buttonText),
                                    );
                                  },
                                ),

                                const SizedBox(height: 12),

                                // Last row with 3 buttons (., 0, Enter)
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 50,
                                      width: 75,
                                      child: _buildCalculatorButton(
                                        '.',
                                        Colors.grey.shade200,
                                        Colors.white, // Changed to white
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      height: 50,
                                      width: 75,
                                      child: _buildCalculatorButton(
                                        '0',
                                        const Color(0xFFEEEEEE), // Grey for 0
                                        Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: MouseRegion(
                                        onEnter: (_) => setState(
                                          () => _pressedButton = 'Enter',
                                        ),
                                        onExit: (_) => setState(
                                          () => _pressedButton = null,
                                        ),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 120,
                                          ),
                                          curve: Curves.easeInOut,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFF1976D2),
                                                Color(0xFF2196F3),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: [
                                              if (_pressedButton == 'Enter')
                                                BoxShadow(
                                                  color: Colors.blueAccent
                                                      .withOpacity(0.4),
                                                  blurRadius: 18,
                                                  spreadRadius: 2,
                                                  offset: Offset(0, 0),
                                                ),
                                            ],
                                          ),
                                          child: ElevatedButton(
                                            onPressed: addBillItemAndRefresh,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              elevation: 0,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: Text(
                                              'Enter',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.1,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
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
                  ],
                ),
              ],
            ),

            bottomNavigationBar: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF1976D2).withOpacity(0.13),
                    blurRadius: 16,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: BottomAppBar(
                elevation: 0,
                color: Theme.of(
                  context,
                ).scaffoldBackgroundColor, // Use transparent to show gradient
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Search toggle button
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              icon: Icon(
                                _isSearchVisible ? Icons.close : Icons.search,
                                color: Colors.blue,
                                size: 22,
                              ),
                              onPressed: _toggleSearch,
                            ),
                          ),
                          // Search field with animation
                          SizeTransition(
                            sizeFactor:
                                _searchAnimation ??
                                const AlwaysStoppedAnimation(0.0),
                            axis: Axis.horizontal,
                            child: Container(
                              width: 140, // Increased width
                              height: 40,
                              margin: const EdgeInsets.only(right: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF0A2342).withOpacity(0.13),
                                    blurRadius: 16,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: _handleSearch,
                                      decoration: InputDecoration(
                                        hintText: "Search items...",
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  if (_searchController.text.isNotEmpty)
                                    SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.close,
                                          size: 18,
                                          color: Colors.grey.shade600,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          _handleSearch('');
                                        },
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _handleCreateBill,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).cardColor,
                          foregroundColor: Colors.blue,
                          elevation: 5,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ), // Reduced padding
                          minimumSize: Size(0, 32), // Reduced minimum height
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        icon: Icon(
                          Icons.receipt_long,
                          size: 18,
                        ), // Reduced icon size
                        label: Text(
                          "Create Bill",
                          style: TextStyle(fontSize: 13), // Reduced font size
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            resizeToAvoidBottomInset: false, // Add this line to prevent resize
          ),
        );
      },
    );
  }

  // Calculator button builder
  Widget _buildCalculatorButton(String label, Color bgColor, Color textColor) {
    final bool isOperator = ['+', '-', '*', '÷', '%'].contains(label);
    final bool isShortcutKey = ['A', 'B', 'C', 'D'].contains(label);
    final bool isNumber = RegExp(r'^[0-9]$').hasMatch(label);
    final bool isActiveShortcut =
        _shortcutBuffer.isNotEmpty && _shortcutBuffer[0] == label;
    final bool isActiveNumber =
        _shortcutBuffer.isNotEmpty &&
        isNumber &&
        _shortcutBuffer.length > 1 &&
        label == _shortcutBuffer[_shortcutBuffer.length - 1];

    // Highlight shortcut and number buttons during shortcut entry
    Color effectiveBg = bgColor;
    Color effectiveText = textColor;
    if (_shortcutBuffer.isNotEmpty) {
      if (isShortcutKey && isActiveShortcut) {
        effectiveBg = Colors.blue.shade700; // vibrant blue for pressed shortcut
        effectiveText = Colors.white;
      } else if (isNumber && isActiveNumber) {
        effectiveBg = Colors.blue.shade100;
      } else if (isShortcutKey || isNumber) {
        effectiveBg = Colors.grey.shade300;
      }
    }

    // Use operator gradient for operator and AC buttons
    BoxDecoration? customGradient;
    final bool isDot = label == '.';
    if (isOperator || label == 'AC' || isDot) {
      customGradient = const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      );
      effectiveBg = Colors.transparent;
    }

    return GestureDetector(
      onTap: () => _onCalculatorButtonPressed(label), // <-- Add this line
      onTapDown: (_) => setState(() => _pressedButton = label),
      onTapUp: (_) => setState(() => _pressedButton = null),
      onTapCancel: () => setState(() => _pressedButton = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: (_pressedButton == label)
            ? (Matrix4.identity()..scale(0.96))
            : Matrix4.identity(),
        decoration:
            customGradient ??
            BoxDecoration(
              color: effectiveBg.withOpacity(
                _pressedButton == label ? 0.85 : 1.0,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (_pressedButton != label)
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.08),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
              ],
            ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isOperator ? 22 : 16,
              fontWeight: FontWeight.bold,
              color: effectiveText,
              shadows: [
                Shadow(
                  color: Colors.white.withOpacity(0.2),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 36, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add items to create a bill',
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(BuildContext context, BillItem item, int index) {
    // Use a composite key for Dismissible to avoid issues with null id
    final dismissKey = item.id != null
        ? ValueKey('billitem_${item.id}')
        : ValueKey(
            'billitem_${item.name}_${item.price}_${item.quantity}_${item.serialNo}',
          );
    return Dismissible(
      key: dismissKey,
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeletion(context, item.name),
      background: Container(
        color: Colors.red.shade400,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        _handleDeleteCartItem(item);
        // Update itemNameController to next default name
        final cubit = context.read<SalesCubit>();
        final state = cubit.state;
        if (state is SalesUpdated && state.items.isNotEmpty) {
          final nextIdx = state.items.length + 1;
          itemNameController.text = 'Item $nextIdx';
        } else {
          itemNameController.text = 'Item 1';
        }
      },
      child: InkWell(
        onTap: () {
          setState(() {
            _editingItem = item;
            itemNameController.text = item.name;
            priceValue = item.priceAsInt.toString();
            quantityValue = item.quantityAsInt.toString();
            priceController.text = priceValue;
            quantityController.text = quantityValue;
          });
          _showCalculator(false);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: const Border(
              bottom: BorderSide(color: Color(0xFF128C7E), width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // NO column
              SizedBox(
                width: 40,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: Colors.teal.shade100),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF128C7E),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // PRODUCT column
              Expanded(
                flex: 4,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              // QTY column
              Expanded(
                flex: 3,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withOpacity(0.13),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF1976D2).withOpacity(0.25),
                      ),
                    ),
                    child: Text(
                      '${item.priceAsInt} × ${item.quantityAsInt}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF128C7E),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
              // AMOUNT column
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Rs ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        item.total.toStringAsFixed(2),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDeletion(BuildContext context, String itemName) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Item'),
              content: Text('Are you sure you want to delete "$itemName"?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('DELETE'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // Update your other methods to ensure proper data refresh
  Future<void> addBillItemAndRefresh() async {
    try {
      // Evaluate expressions first
      if (priceValue.isNotEmpty) {
        priceValue = _parseExpression(priceValue);
        priceController.text = priceValue;
      }
      if (quantityValue.isNotEmpty) {
        quantityValue = _parseExpression(quantityValue);
        quantityController.text = quantityValue;
      }

      final error = validateInputs();
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
        return;
      }

      final salesCubit = context.read<SalesCubit>();
      if (_editingItem != null) {
        // Update existing item
        final updatedItem = BillItem(
          id: _editingItem!.id,
          serialNo: _editingItem!.serialNo,
          name: itemNameController.text.trim().isNotEmpty
              ? itemNameController.text.trim()
              : _editingItem!.name,
          price: double.parse(priceValue),
          quantity: double.parse(quantityValue),
        );
        if (_editingItem!.id != null) {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          final currentBillId = bill.id;
          if (currentBillId == null) {
            debugPrint('Error: Current bill ID is null');
            if (userId != null) {
              await _billRepository.updateBillItem(
                userId,
                currentBillId!,
                updatedItem,
              );
            }
          }
        } else {
          // Update in-memory cart item
          salesCubit.updateCartItem(_editingItem!, updatedItem);
        }
      } else {
        // Create new item
        String itemName = itemNameController.text.trim();
        if (itemName.isEmpty) {
          itemName = _getDefaultItemName();
        }
        final finalPrice = double.parse(priceValue);
        final finalQuantity = double.parse(quantityValue);

        // Normalize default item names for merging
        String normalizedItemName = itemName;
        final defaultNameMatch = RegExp(r'^Item (\d+)').firstMatch(itemName);
        if (defaultNameMatch != null) {
          // Always treat 'Item X' as the same if the number matches
          normalizedItemName = 'Item ${defaultNameMatch.group(1)}';
          debugPrint(
            'Calculator: Normalized default name "$itemName" to "$normalizedItemName"',
          );
        }

        // Check for existing item with enhanced logic for default names
        final existingIndex = salesCubit.items.indexWhere((item) {
          // For default names, use the normalized comparison
          if (defaultNameMatch != null) {
            final itemDefaultMatch = RegExp(
              r'^Item (\d+)',
            ).firstMatch(item.name);
            if (itemDefaultMatch != null) {
              final itemNumber = itemDefaultMatch.group(1);
              final newNumber = defaultNameMatch.group(1);
              final isSameDefaultName =
                  itemNumber == newNumber && item.price == finalPrice;
              debugPrint(
                'Calculator: Comparing default names - Item $itemNumber vs Item $newNumber, price match: ${item.price == finalPrice}, result: $isSameDefaultName (addBillItemAndRefresh)',
              );
              return isSameDefaultName;
            }
          }
          // For non-default names, use the original logic
          final nameMatch =
              item.name.trim().toLowerCase() ==
              normalizedItemName.trim().toLowerCase();
          final priceMatch = item.price == finalPrice;
          debugPrint(
            'Calculator: Comparing non-default names - "${item.name}" vs "$normalizedItemName", price match: $priceMatch, result: ${nameMatch && priceMatch} (addBillItemAndRefresh)',
          );
          return nameMatch && priceMatch;
        });
        if (existingIndex != -1) {
          // Update quantity of existing item
          final existingItem = salesCubit.items[existingIndex];
          final updatedItem = existingItem.copyWith(
            quantity: existingItem.quantity + finalQuantity,
          );
          debugPrint(
            'Calculator: Merging items - Existing: ${existingItem.name} (qty: ${existingItem.quantity}), New qty: $finalQuantity, Total: ${updatedItem.quantity} (addBillItemAndRefresh)',
          );
          salesCubit.updateCartItem(existingItem, updatedItem);
        } else {
          final newItem = BillItem(
            serialNo: 0,
            name: itemName,
            price: finalPrice,
            quantity: finalQuantity,
          );
          debugPrint(
            'Calculator: Adding new item - Name: $itemName, Price: $finalPrice, Qty: $finalQuantity (addBillItemAndRefresh)',
          );
          await salesCubit.addBillItem(newItem);
        }
      }

      clearInputs();
      // Explicitly focus the price field after adding item
      FocusScope.of(context).requestFocus(priceFocus);
      _editingItem = null;
    } catch (e) {
      debugPrint('Error managing item: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save item'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startShortcutEntryTimer() {
    _shortcutEntryTimer?.cancel();
    debugPrint('Starting shortcut timer for buffer: $_shortcutBuffer');
    _shortcutEntryTimer = Timer(_shortcutEntryTimeout, () {
      if (!mounted) return;
      if (_shortcutBuffer.isNotEmpty) {
        debugPrint(
          'Shortcut timer expired, processing buffer: $_shortcutBuffer',
        );
        _processShortcutBuffer();
      }
    });
  }

  void _processShortcutBuffer() {
    if (_shortcutBuffer.isEmpty) {
      debugPrint('Shortcut buffer is empty, skipping processing');
      return;
    }

    debugPrint('Processing shortcut buffer: $_shortcutBuffer');
    final result = ShortcutValidator.parseShortcut(_shortcutBuffer);
    debugPrint(
      'Shortcut parse result: isValid=${result.isValid}, category=${result.category}, code=${result.code}, quantity=${result.quantity}',
    );

    if (!result.isValid) {
      debugPrint('Invalid shortcut format: ${result.error}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Invalid shortcut format'),
          backgroundColor: Colors.red,
        ),
      );
      _shortcutBuffer = '';
      _shortcutEntryTimer?.cancel();
      if (mounted) {
        setState(() {}); // Only update shortcut UI
      }
      return;
    }

    // Use inventory from InventoryCubit
    final inventoryState = context.read<InventoryCubit>().state;
    List inventoryList = [];
    if (inventoryState is InventoryLoaded) {
      inventoryList = inventoryState.items
          .where((i) => i.isSold == false)
          .toList();
    }

    final searchShortcut = '${result.category}${result.code}'.toUpperCase();
    debugPrint(
      'Searching for shortcut: $searchShortcut in ${inventoryList.length} items',
    );

    // Debug: Print all available shortcuts
    for (var item in inventoryList) {
      if (item.shortcut != null && item.shortcut!.isNotEmpty) {
        debugPrint(
          'Available shortcut: ${item.shortcut!.toUpperCase()} for item: ${item.name}',
        );
      }
    }

    final InventoryItem? inv = inventoryList
        .cast<InventoryItem?>()
        .firstWhereOrNull(
          (item) => (item?.shortcut ?? '').toUpperCase() == searchShortcut,
        );

    debugPrint('Found inventory item: ${inv?.name ?? 'NOT FOUND'}');

    if (inv != null) {
      // Check if item is out of stock
      if (inv.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Out of stock! ${inv.name} has no items available.'),
            backgroundColor: Colors.red,
          ),
        );
        _shortcutBuffer = '';
        _shortcutEntryTimer?.cancel();
        debugPrint('Shortcut processing failed - out of stock, buffer cleared');
        if (mounted) {
          setState(() {}); // Only update shortcut UI
        }
        return;
      }

      // Check if requested quantity exceeds available stock
      final requestedQuantity = result.quantity ?? 1.0;
      if (requestedQuantity > inv.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient stock! ${inv.name} has only ${inv.quantity.toStringAsFixed(0)} items available. You cannot add more than ${inv.quantity.toStringAsFixed(0)} items.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        _shortcutBuffer = '';
        _shortcutEntryTimer?.cancel();
        debugPrint(
          'Shortcut processing failed - insufficient stock, buffer cleared',
        );
        if (mounted) {
          setState(() {}); // Only update shortcut UI
        }
        return;
      }

      itemNameController.text = inv.name;
      priceValue = inv.price.toStringAsFixed(0);
      priceController.text = priceValue;

      // Clear shortcut buffer after successful processing
      _shortcutBuffer = '';
      _shortcutEntryTimer?.cancel();
      debugPrint('Shortcut processed successfully, buffer cleared');
      quantityValue = requestedQuantity.toStringAsFixed(0);
      quantityController.text = quantityValue;
      if (mounted) {
        setState(() {}); // Only update shortcut UI
      }
    } else {
      debugPrint('No inventory item found for shortcut: $_shortcutBuffer');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No item found for shortcut $_shortcutBuffer'),
          backgroundColor: Colors.red,
        ),
      );
      _shortcutBuffer = '';
      _shortcutEntryTimer?.cancel();
      debugPrint('Shortcut processing failed - item not found, buffer cleared');
      if (mounted) {
        setState(() {}); // Only update shortcut UI
      }
    }
  }

  Future<void> _loadDiscount() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('current_uid');
    if (uid == null || uid.isEmpty) {
      if (mounted) {
        setState(() => _discount = 0.0);
      }
      return;
    }
    final settings = await SettingsRepository().getSettings(uid);
    if (mounted) {
      setState(() {
        _discount = settings?.defaultDiscount ?? 0.0;
      });
    }
  }

  Future<void> _fetchCustomers() async {
    final uid = await getCurrentUserUid();
    debugPrint('Calculator: getPeopleByCategory fetched UID: $uid');
    if (uid == null || uid.isEmpty) {
      // handle error or return empty list
      return;
    }
    final customers = await _peopleRepo.getPeopleByCategory('customer', uid);
    if (mounted) {
      setState(() {
        _customerList = customers;
        // If the previously selected customer is not in the new list, clear selection
        if (_selectedCustomer != null &&
            !_customerList.any((c) => c.name == _selectedCustomer)) {
          _selectedCustomer = null;
        }
      });
    }
  }

  void _handleDeleteCartItem(BillItem item) {
    final salesCubit = context.read<SalesCubit>();
    salesCubit.removeItem(item);
    if (mounted) {
      setState(
        () {},
      ); // This will trigger a rebuild and recalculate available qty
    }
  }

  void _updateItemNameField() {
    final salesCubit = context.read<SalesCubit>();
    final nextSerial = salesCubit.items.length + 1;
    itemNameController.text = 'Item $nextSerial';
  }

  String _getNextItemSerialName() {
    final salesCubit = context.read<SalesCubit>();
    final nextSerial = salesCubit.items.length + 1;
    return 'Item $nextSerial';
  }

  void _updateShortcutPreview() {
    if (_shortcutBuffer.isEmpty) {
      // Optionally clear fields if buffer is empty
      // itemNameController.clear();
      // priceValue = '';
      // priceController.clear();
      // quantityValue = '';
      // quantityController.clear();
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final result = ShortcutValidator.parseShortcut(_shortcutBuffer);
    if (!result.isValid) {
      // Optionally clear fields if invalid
      // itemNameController.clear();
      // priceValue = '';
      // priceController.clear();
      // quantityValue = '';
      // quantityController.clear();
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final inventoryState = context.read<InventoryCubit>().state;
    List inventoryList = [];
    if (inventoryState is InventoryLoaded) {
      inventoryList = inventoryState.items
          .where((i) => i.isSold == false)
          .toList();
    }
    final searchShortcut = '${result.category}${result.code}'.toUpperCase();
    final InventoryItem? inv = inventoryList
        .cast<InventoryItem?>()
        .firstWhereOrNull(
          (item) => (item?.shortcut ?? '').toUpperCase() == searchShortcut,
        );
    if (inv != null) {
      itemNameController.text = inv.name;
      priceValue = inv.price.toStringAsFixed(0);
      priceController.text = priceValue;
      quantityValue = (result.quantity ?? 1.0).toStringAsFixed(0);
      quantityController.text = quantityValue;
    } else {
      // Optionally clear fields if not found
      // itemNameController.clear();
      // priceValue = '';
      // priceController.clear();
      // quantityValue = '';
      // quantityController.clear();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _startShortcutTimer() {
    _shortcutTimer?.cancel();
    _shortcutTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      // Timer expired without a number press - shortcut already handled
      debugPrint('Shortcut timer expired without number press');
      if (mounted) {
        setState(() {}); // Refresh UI to show active state
      }
    });
  }
}

/// Determines button background color
Color _getButtonColor(String label) {
  // Updated palette per user request
  if (["A", "B", "C", "D"].contains(label))
    return const Color(0xFFBBDEFB); // Light blue for shortcuts
  if (label == "Del")
    return const Color(0xFFD32F2F); // Medium strong red for delete
  if (label == "AC")
    return Colors.transparent; // Use gradient for AC, handled in builder
  if (int.tryParse(label) != null)
    return const Color(0xFFEEEEEE); // Grey for digits
  if (["+", "-", "*", "÷", "%"].contains(label)) {
    return const Color(0xFFBBDEFB); // Light blue for operators
  }
  if (label == ".") return const Color(0xFF1976D2); // Blue for dot
  return const Color(0xFFE3F2FD); // Default very light blue
}

/// Determines text color
Color _getTextColor(String label) {
  if (["A", "B", "C", "D"].contains(label))
    return const Color(0xFF1976D2); // Blue text for shortcuts
  if (["Del"].contains(label)) return Colors.white;
  if (["AC"].contains(label)) return Colors.white; // White for AC
  if (["+", "-", "*", "÷", "%"].contains(label))
    return Colors.white; // White text for operators
  if (int.tryParse(label) != null) return Colors.black87; // Black for digits
  if (label == ".") return Colors.white; // White for dot
  return const Color(0xFF1976D2);
}

// --- Refactored Cart List Widget ---
class CartListView extends StatelessWidget {
  final Widget Function(BuildContext, BillItem, int) itemBuilder;
  const CartListView({Key? key, required this.itemBuilder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SalesCubit, SalesState>(
      buildWhen: (previous, current) => previous != current,
      builder: (context, state) {
        if (state is SalesUpdated) {
          final items = state.items;
          if (items.isEmpty) {
            return _buildEmptyState(context);
          }
          return ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  itemBuilder(context, items[index], index),
            ),
          );
        } else if (state is SalesError) {
          return Center(
            child: Text(state.message, style: TextStyle(color: Colors.red)),
          );
        } else if (state is SalesInitial) {
          return _buildEmptyState(context);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 36, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add items to create a bill',
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
