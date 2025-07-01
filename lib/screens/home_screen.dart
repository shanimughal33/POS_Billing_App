import 'dart:async';
import 'package:forward_billing_app/screens/receipt_screen.dart';
import 'package:forward_billing_app/screens/inventory_screen.dart';
import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import '../models/bill_item.dart';
import '../repositories/bill_repository.dart';
import '../database/database_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/sales_cubit.dart';
import '../repositories/inventory_repository.dart';
import '../utils/shortcut_validator.dart';

// --- BEGIN MOVED CODE ---

class CustomerBillScreen extends StatefulWidget {
  const CustomerBillScreen({super.key});

  @override
  State<CustomerBillScreen> createState() => _CustomerBillScreenState();
}

class _CustomerBillScreenState extends State<CustomerBillScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedCustomer;
  String _selectedPaymentMethod = 'Cash';

  final List<String> _customerOptions = [
    'Customer A',
    'Customer B',
    'Customer C',
  ];
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

  bool _isLoading = true;

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

  @override
  void initState() {
    super.initState();
    _initializeSearchAnimation();
    // Load sales items from DB
    Future.microtask(() {
      final salesCubit = context.read<SalesCubit>();
      salesCubit.loadSalesFromDb();
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

  @override
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
    // Use SalesCubit to look up inventory item by shortcut
    final salesCubit = context.read<SalesCubit>();
    salesCubit.addItemFromShortcut(key);
    // The UI will update via BlocListener below
  }

  void _handleOperation(String operation) {
    if (operation == '*' && !isEditingQuantity) {
      // Evaluate current expression before switching
      if (priceValue.isNotEmpty) {
        try {
          final result = _parseExpression(priceValue);
          priceValue = result;
          priceController.text = result;
        } catch (e) {
          debugPrint('Error evaluating expression: $e');
        }
      }
      _showCalculator(true);
      return;
    }

    setState(() {
      if (isEditingQuantity) {
        String currentText = quantityController.text;
        if (!RegExp(r'[+\-*/%]$').hasMatch(currentText)) {
          quantityValue = '$currentText $operation';
          quantityController.text = quantityValue;
        }
      } else {
        String currentText = priceController.text;
        if (!RegExp(r'[+\-*/%]$').hasMatch(currentText)) {
          priceValue = '$currentText $operation';
          priceController.text = priceValue;
        }
      }
    });
  }

  String _parseExpression(String input) {
    try {
      if (input.isEmpty) return '';

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
      // Return original input if parsing fails
      return input;
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
    try {
      final error = validateInputs();
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
        return;
      }
      double finalPrice = double.parse(_parseExpression(priceValue));
      double finalQuantity = double.parse(_parseExpression(quantityValue));
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

      // Sync inventory after sale
      await context.read<InventoryCubit>().updateInventoryAfterSale(billItems);

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
            backgroundColor: Colors.white,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(87),
              child: Container(
                padding: const EdgeInsets.fromLTRB(5, 10, 0, 10),
                color: const Color(0xFF128C7E),
                // Green background
                child: SafeArea(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Back Button
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
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
                              width: 135,
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  dropdownColor: Color(0xFF1E8858),
                                  isExpanded: true,
                                  value: _selectedCustomer,
                                  hint: const Text(
                                    '+ Add Customer',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedCustomer = newValue;
                                    });
                                  },
                                  items: _customerOptions.map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,

                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          18,
                                          2,
                                          2,
                                          2,
                                        ),
                                        child: Text(
                                          value,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),

                            // Payment Method Dropdown
                            Container(
                              height: 30,
                              width: 115,
                              margin: const EdgeInsets.only(left: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedPaymentMethod,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Color(0xFF1E8858),
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
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF1E8858),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          margin: const EdgeInsets.only(right: 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Rs ',
                                    style: const TextStyle(
                                      color: Color(0xFF1E8858),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    totalAmount(context).toStringAsFixed(2),
                                    style: const TextStyle(
                                      color: Color(0xFF1E8858),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Party Discount:0%',
                                style: TextStyle(
                                  color: Color(0xFF1E8858),
                                  fontSize: 12,
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
                        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                          border: Border.all(color: Colors.grey.shade200),
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
                                  color: Colors.grey.shade800,
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
                                  color: Colors.grey.shade800,
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
                                  color: Colors.grey.shade800,
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
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Cart list
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade100,
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
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
                        horizontal: 8.0,
                        vertical: 3.0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 47,
                              decoration: BoxDecoration(
                                color: Colors.white,
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
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
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
                                color: Colors.white,
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
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'eg: 100',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 14,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
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
                                color: Colors.white,
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
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'eg: 2',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // First 5 rows using GridView
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: 20,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
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
                              final String buttonText = buttonTexts[index];

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

                          const SizedBox(height: 10),

                          // Last row with 3 buttons (., 0, Enter)
                          Row(
                            children: [
                              SizedBox(
                                height: 50,
                                width: 75,
                                child: _buildCalculatorButton(
                                  '.',
                                  Colors.grey.shade200,
                                  Colors.black,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 50,
                                width: 75,
                                child: _buildCalculatorButton(
                                  '0',
                                  const Color(0xFFFFEB3B),
                                  Colors.black,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 50,
                                width: 166,
                                child: ElevatedButton(
                                  onPressed: addBillItem,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 4,
                                    shadowColor: Colors.black38,
                                  ),
                                  child: const Text(
                                    'Enter',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            bottomNavigationBar: BottomAppBar(
              elevation: 15,
              color: Color(0xFF128C7E),
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                            color: Colors.white24,
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
                              color: Colors.white,
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
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
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green,
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
    final bool isOperator = ['+', '-', '*', '÷', '%', '.'].contains(label);
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
    if (_shortcutBuffer.isNotEmpty) {
      if (isShortcutKey && isActiveShortcut) {
        bgColor = Colors.green.shade700;
        textColor = Colors.white;
      } else if (isNumber && isActiveNumber) {
        bgColor = Colors.green.shade100;
      } else if (isShortcutKey || isNumber) {
        bgColor = Colors.grey.shade300;
      }
    }

    return ElevatedButton(
      onPressed: () => _onCalculatorButtonPressed(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: isActiveShortcut || isActiveNumber ? 8 : 4,
        shadowColor: isActiveShortcut ? Colors.green : Colors.black38,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: isOperator ? 20 : 14,
          fontWeight: isActiveShortcut || isActiveNumber || isOperator
              ? FontWeight.w600
              : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 10),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Add items to create a bill',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF128C7E),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(BuildContext context, BillItem item, int index) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeletion(context, item.name),
      background: Container(
        color: Colors.red.shade400,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        context.read<SalesCubit>().removeItem(item);
        itemNameController.text = _getDefaultItemName();
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
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.teal.shade100),
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

        await _billRepository.insertBillItem(newItem);
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

    final salesCubit = context.read<SalesCubit>();
    final inv = salesCubit.getInventoryItemByShortcut(
      '${result.category}${result.code}',
    );

    if (inv != null) {
      // Only update the input fields and shortcut UI
      itemNameController.text = inv.name;
      priceValue = inv.price.toStringAsFixed(0);
      priceController.text = priceValue;
      quantityValue = result.quantity?.toStringAsFixed(0) ?? '1';
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
}

/// Determines button background color
Color _getButtonColor(String label) {
  if (['A', 'B', 'C', 'D'].contains(label)) return const Color(0xFF4CAF50);
  if (label == 'Del') return const Color(0xFFEF9A9A);
  if (label == 'AC') return Colors.grey.shade300;
  if (int.tryParse(label) != null) return const Color(0xFFFFEB3B);
  if (['+', '-', 'x', '÷', '%'].contains(label)) {
    return Colors.grey.shade300;
  }
  return Colors.grey.shade200;
}

/// Determines text color
Color _getTextColor(String label) {
  return ['A', 'B', 'C', 'D'].contains(label) ? Colors.white : Colors.black87;
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
          Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 10),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Add items to create a bill',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF128C7E),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
