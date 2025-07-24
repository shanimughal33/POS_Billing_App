import 'dart:async';
import 'package:forward_billing_app/screens/receipt_screen.dart';
import 'package:flutter/material.dart';
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
import '../utils/app_theme.dart';
import 'dart:ui'; // For BackdropFilter
import 'package:google_fonts/google_fonts.dart'; // For modern fonts
import 'package:shared_preferences/shared_preferences.dart';

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
  final priceController = TextEditingController();
  final quantityController = TextEditingController();
  final itemNameController = TextEditingController();

  // Add these properties at the start of class
  final TextEditingController _searchController = TextEditingController();

  // Remove late keywords and make nullable
  AnimationController? _searchAnimationController;
  Animation<double>? _searchAnimation;
  bool _isSearchVisible = false;

  // Add repository
  final BillRepository _billRepository = BillRepository();

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
  static const Duration _shortcutEntryTimeout = Duration(milliseconds: 500);

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

  @override
  void initState() {
    super.initState();
    _initializeSearchAnimation();
    _fetchCustomers();
    _loadDiscount();
    // Always load inventory on open
    Future.microtask(() {
      final inventoryCubit = context.read<InventoryCubit>();
      inventoryCubit.loadInventory();
    });
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
    priceController.dispose();
    quantityController.dispose();
    itemNameController.dispose();
    super.dispose();
  }

  void _showCalculator(bool forQuantity) {
    if (isEditingQuantity != forQuantity) {
      setState(() {
        isEditingQuantity = forQuantity;
      });
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
      _shortcutBuffer = value;
      _startShortcutEntryTimer();
      setState(() {});
      return;
    }

    // Handle shortcut entry continuation
    if (_shortcutBuffer.isNotEmpty) {
      if (value == 'Enter') {
        _processShortcutBuffer();
        return;
      }

      // Handle quantity multiplier
      if (_shortcutBuffer.contains('x')) {
        if (RegExp(r'[0-9]').hasMatch(value)) {
          final newBuffer = _shortcutBuffer + value;
          if (ShortcutValidator.isValidShortcutFormat(newBuffer)) {
            _shortcutBuffer = newBuffer;
            _startShortcutEntryTimer();
            setState(() {});
          }
        }
        return;
      }

      // Handle multiplication symbol for quantity
      if (value == '*' && !_shortcutBuffer.contains('x')) {
        _shortcutBuffer += 'x';
        _startShortcutEntryTimer();
        setState(() {});
        return;
      }

      // Handle numeric input for shortcut
      if (RegExp(r'[0-9]').hasMatch(value)) {
        final newBuffer = _shortcutBuffer + value;
        if (newBuffer.length <= 6) {
          // Max shortcut length
          _shortcutBuffer = newBuffer;
          _startShortcutEntryTimer();
          setState(() {});
        }
      }
      return;
    }

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

  void _startShortcutMode(String key) {
    _pendingShortcut = key;
    _isWaitingForNumber = true;
    _shortcutTimer?.cancel();
    _shortcutTimer = Timer(const Duration(milliseconds: 2000), () {
      _clearShortcutState();
      // Timer expired without a number press - shortcut already handled
    });
    setState(() {}); // Refresh UI to show active state
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
          SnackBar(
            content: Text('Out of stock! ${item.name} has no items available.'),
            backgroundColor: Colors.red,
          ),
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

            // Check if requested quantity exceeds available stock
            if (quantity > inventoryItem.quantity) {
              return 'Insufficient stock! ${inventoryItem.name} has only ${inventoryItem.quantity.toStringAsFixed(0)} items available. You cannot add more than ${inventoryItem.quantity.toStringAsFixed(0)} items.';
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
        await _billRepository.updateBillItem(updatedItem);
      } else {
        String itemName = itemNameController.text.trim();
        if (itemName.isEmpty) {
          itemName = _getDefaultItemName();
        }
        final newItem = BillItem(
          serialNo: 0,
          name: itemName,
          price: finalPrice,
          quantity: finalQuantity,
        );
        await context.read<SalesCubit>().addBillItem(newItem);
      }
      // Clear price and quantity fields, set item name to next default
      priceController.clear();
      quantityController.clear();
      priceValue = '';
      quantityValue = '';
      itemNameController.text = _getDefaultItemName();
      _shortcutBuffer = '';
      setState(() {});
  }

  // Update toggle search method
  void _toggleSearch() {
    if (!mounted || _searchAnimationController == null) return;

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
      final double billTotal = BillItem.calculateBillTotal(billItems);
      final DateTime billDate = DateTime.now();
      final String customer = _selectedCustomer ?? 'Walk-in Customer';
      final String paymentMethod = _selectedPaymentMethod;
      final int billNumber = DateTime.now().millisecondsSinceEpoch % 1000000;

      // *** Save Bill and its items ***
      final BillRepository billRepo = BillRepository();
      final bill = Bill(
        id: billNumber.toString(),
        date: billDate,
        customerName: customer,
        paymentMethod: paymentMethod,
        items: billItems,
      );
      await billRepo.insertBillWithItems(bill);

      await ActivityRepository().logActivity(
        Activity(
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
      await context.read<InventoryCubit>().updateInventoryAfterSale(billItems);

      // Refresh SalesCubit inventory after sale
      final inventoryCubit = context.read<InventoryCubit>();
      final salesCubit = context.read<SalesCubit>();
      final latestInventory = inventoryCubit.unsoldItems;
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
      itemNameController.text = _getDefaultItemName();
      priceController.clear();
      quantityController.clear();
      priceValue = '';
      quantityValue = '';
      setState(() {});
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
    return BlocBuilder<InventoryCubit, InventoryState>(
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
              if (state.items.isEmpty) {
                itemNameController.text = 'Item 1';
              } else {
                itemNameController.text = 'Item ${state.items.length + 1}';
              }
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
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F0F0F) : Theme.of(context).scaffoldBackgroundColor,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(87),
              child: Container(
                padding: const EdgeInsets.fromLTRB(5, 6, 0, 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
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
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Color.fromARGB(255, 6, 61, 107),
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
                                  isExpanded: true,
                                  value: _selectedCustomer,
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
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedCustomer = newValue;
                                    });
                                  },
                                  selectedItemBuilder: (context) {
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
                                  items: _customerList.map((People customer) {
                                    return DropdownMenuItem<String>(
                                      value: customer.name,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: (Colors.blue)
                                                .withOpacity(0.13),
                                            child: Text(
                                              customer.name.isNotEmpty
                                                  ? customer.name[0]
                                                        .toUpperCase()
                                                  : '',
                                              style: TextStyle(
                                                color: Color(0xFF1E8858),
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
                                      ),
                                    );
                                  }).toList(),
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
                              Text(
                                'Discount: ${_discount.toStringAsFixed(0)}%',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 11, // slightly reduced
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                        vertical: 0.0,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.10),
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.08),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    height: 47,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.shade300,
                                          spreadRadius: 2,
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller: itemNameController,
                                      keyboardType: TextInputType.text,
                                      decoration: InputDecoration(
                                        hintText: _getDefaultItemName(),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                        filled: true,
                                        fillColor: Theme.of(context).cardColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    height: 47,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.shade300,
                                          spreadRadius: 2,
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      readOnly: true,
                                      controller: priceController,
                                      focusNode: priceFocus,
                                      onTap: () => _showCalculator(false),
                                      cursorWidth: 2,
                                      cursorHeight: 24,
                                      cursorColor: Colors.blue,
                                      showCursor: true,
                                      style: TextStyle(fontSize: 16),
                                      decoration: InputDecoration(
                                        hintText: 'eg: 100',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 14,
                                            ),
                                        filled: true,
                                        fillColor: Theme.of(context).cardColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    height: 47,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.shade300,
                                          spreadRadius: 2,
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
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
                                      cursorColor: Colors.blue,
                                      showCursor: true,
                                      textAlign: TextAlign.left,
                                      style: TextStyle(fontSize: 16),
                                      decoration: InputDecoration(
                                        hintText: 'eg: 2',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                        filled: true,
                                        fillColor: Theme.of(context).cardColor,
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
                              color: Theme.of(context).cardColor.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.08),
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
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
                                            onPressed: addBillItem,
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
                color: Theme.of(context).scaffoldBackgroundColor, // Use transparent to show gradient
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
        // If id is null, remove by matching all fields
        final cubit = context.read<SalesCubit>();
        if (item.id == null) {
          cubit.removeItemByFields(
            item.name,
            item.price,
            item.quantity,
            item.serialNo,
          );
        } else {
          cubit.removeItem(item);
        }
        // Update itemNameController to next default name
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
            priceValue = item.price.toStringAsFixed(2);
            quantityValue = item.quantity.toStringAsFixed(2);
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
                      '${item.price.toStringAsFixed(0)} × ${item.quantity.toStringAsFixed(0)}',
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

        await _billRepository.updateBillItem(updatedItem);
      } else {
        // Create new item
        String itemName = itemNameController.text.trim();
        if (itemName.isEmpty) {
          itemName = 'Item';
        }

        final newItem = BillItem(
          serialNo: 0,
          name: itemName,
          price: double.parse(priceValue),
          quantity: double.parse(quantityValue),
        );

        await context.read<SalesCubit>().addBillItem(newItem);
      }

      clearInputs();
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
    _shortcutEntryTimer = Timer(_shortcutEntryTimeout, () {
      if (_shortcutBuffer.isNotEmpty) {
        _processShortcutBuffer();
      }
    });
  }

  void _processShortcutBuffer() {
    if (_shortcutBuffer.isEmpty) return;

    final result = ShortcutValidator.parseShortcut(_shortcutBuffer);
    if (!result.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Invalid shortcut format'),
          backgroundColor: Colors.red,
        ),
      );
      _shortcutBuffer = '';
      _shortcutEntryTimer?.cancel();
      setState(() {}); // Only update shortcut UI
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
    final InventoryItem? inv = inventoryList.cast<InventoryItem?>().firstWhere(
      (item) =>
          (item?.shortcut ?? '').toUpperCase() ==
          ('${result.category}${result.code}').toUpperCase(),
      orElse: () => null,
    );

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
        setState(() {}); // Only update shortcut UI
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
        setState(() {}); // Only update shortcut UI
        return;
      }

      itemNameController.text = inv.name;
      priceValue = inv.price.toStringAsFixed(0);
      priceController.text = priceValue;
      quantityValue = requestedQuantity.toStringAsFixed(0);
      quantityController.text = quantityValue;
      setState(() {}); // Only update shortcut UI
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No item found for shortcut $_shortcutBuffer'),
          backgroundColor: Colors.red,
        ),
      );
    }

    _shortcutBuffer = '';
    _shortcutEntryTimer?.cancel();
    setState(() {}); // Only update shortcut UI
  }

  Future<void> _loadDiscount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _discount = prefs.getDouble('defaultDiscount') ?? 0.0;
    });
  }

  Future<void> _fetchCustomers() async {
    final customers = await _peopleRepo.getPeopleByCategory('customer');
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
