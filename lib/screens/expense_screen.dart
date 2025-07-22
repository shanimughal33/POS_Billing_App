// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../repositories/expense_repository.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../models/activity.dart';
import '../repositories/activity_repository.dart';
import '../utils/app_theme.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Expense> _allExpenses = [];
  List<Expense> _filteredExpenses = [];
  final ExpenseRepository _expenseRepo = ExpenseRepository();

  final List<String> _categories = [
    'Rent',
    'Utilities',
    'Salaries/Wages',
    'Supplies & Inventory',
    'Maintenance & Repairs',
    'Marketing & Advertising',
    'Transportation / Delivery',
  ];

  final List<String> _paymentMethods = [
    'Cash',
    'Card',
    'Bank Transfer',
    'UPI',
    'Cheque',
    'Digital Wallet',
  ];

  // Add filter state
  String _sortBy =
      'date_desc'; // date_desc, date_asc, amount_desc, amount_asc, name_asc, name_desc
  String? _paymentMethodFilter; // null means all

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _categories.length + 1, // +1 for "ALL" tab
      vsync: this,
    );
    _filteredExpenses = [];
    _tabController.addListener(_onTabChanged);
    _loadExpensesFromDb();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _filterExpenses();
    });
  }

  void _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        String tempSortBy = _sortBy;
        String? tempPaymentMethod = _paymentMethodFilter;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Filter & Sort'),
          content: StatefulBuilder(
            builder: (context, setModalState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sort by:'),
                RadioListTile<String>(
                  value: 'date_desc',
                  groupValue: tempSortBy,
                  onChanged: (v) => setModalState(() => tempSortBy = v!),
                  title: const Text('Date (Newest)'),
                ),
                RadioListTile<String>(
                  value: 'date_asc',
                  groupValue: tempSortBy,
                  onChanged: (v) => setModalState(() => tempSortBy = v!),
                  title: const Text('Date (Oldest)'),
                ),
                RadioListTile<String>(
                  value: 'amount_desc',
                  groupValue: tempSortBy,
                  onChanged: (v) => setModalState(() => tempSortBy = v!),
                  title: const Text('Amount (High-Low)'),
                ),
                RadioListTile<String>(
                  value: 'amount_asc',
                  groupValue: tempSortBy,
                  onChanged: (v) => setModalState(() => tempSortBy = v!),
                  title: const Text('Amount (Low-High)'),
                ),
                RadioListTile<String>(
                  value: 'name_asc',
                  groupValue: tempSortBy,
                  onChanged: (v) => setModalState(() => tempSortBy = v!),
                  title: const Text('Name (A-Z)'),
                ),
                RadioListTile<String>(
                  value: 'name_desc',
                  groupValue: tempSortBy,
                  onChanged: (v) => setModalState(() => tempSortBy = v!),
                  title: const Text('Name (Z-A)'),
                ),
                const Divider(),
                const Text('Payment Method:'),
                DropdownButton2<String?>(
                  value: tempPaymentMethod,
                  isExpanded: true,
                  hint: const Text('All'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ..._paymentMethods.map(
                      (m) => DropdownMenuItem(value: m, child: Text(m)),
                    ),
                  ],
                  onChanged: (v) => setModalState(() => tempPaymentMethod = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _sortBy = tempSortBy;
                  _paymentMethodFilter = tempPaymentMethod;
                  _filterExpenses();
                });
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _filterExpenses() {
    int idx = _tabController.index;
    List<Expense> filtered = [];
    if (idx == 0) {
      if (_searchQuery.isEmpty) {
        filtered = List.from(_allExpenses);
      } else {
        filtered = _allExpenses
            .where(
              (e) =>
                  (e.description?.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ??
                      false) ||
                  (e.vendor?.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ??
                      false) ||
                  (e.referenceNumber?.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ??
                      false) ||
                  (e.name.toLowerCase().contains(_searchQuery.toLowerCase())),
            )
            .toList();
      }
    } else {
      String category = _categories[idx - 1];
      if (_searchQuery.isEmpty) {
        filtered = _allExpenses.where((e) => e.category == category).toList();
      } else {
        filtered = _allExpenses
            .where(
              (e) =>
                  e.category == category &&
                  ((e.description?.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ??
                          false) ||
                      (e.vendor?.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ??
                          false) ||
                      (e.referenceNumber?.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ??
                          false) ||
                      (e.name.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ))),
            )
            .toList();
      }
    }
    // Apply payment method filter
    if (_paymentMethodFilter != null) {
      filtered = filtered
          .where((e) => e.paymentMethod == _paymentMethodFilter)
          .toList();
    }
    // Apply sorting
    switch (_sortBy) {
      case 'date_desc':
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 'date_asc':
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'amount_desc':
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'amount_asc':
        filtered.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case 'name_asc':
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case 'name_desc':
        filtered.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
    }
    setState(() {
      _filteredExpenses = filtered;
    });
  }

  Future<void> _loadExpensesFromDb() async {
    final expenses = await _expenseRepo.getAllExpenses();
    setState(() {
      _allExpenses = expenses;
      _filterExpenses();
    });
  }

  double _getTotalExpense(String category) {
    if (category == 'all') {
      return _allExpenses.fold(0.0, (sum, e) => sum + e.amount);
    }
    return _allExpenses
        .where((e) => e.category == category)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'rent':
        return Icons.home;
      case 'utilities':
        return Icons.electric_bolt;
      case 'salaries/wages':
        return Icons.people;
      case 'supplies & inventory':
        return Icons.inventory;
      case 'maintenance & repairs':
        return Icons.build;
      case 'marketing & advertising':
        return Icons.campaign;
      case 'transportation / delivery':
        return Icons.local_shipping;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    // All categories use blue theme now
    return Color(0xFF1976D2);
  }

  void _showAddEditExpense({Expense? expense}) async {
    final isEdit = expense != null;
    final dateController = TextEditingController(
      text: isEdit
          ? DateFormat('yyyy-MM-dd').format(expense.date)
          : DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final amountController = TextEditingController(
      text: isEdit ? expense.amount.toString() : '',
    );
    final descriptionController = TextEditingController(
      text: isEdit ? expense.description : '',
    );
    final nameController = TextEditingController(
      text: isEdit ? expense.name : '',
    );

    String selectedCategory = isEdit
        ? expense.category
        : _tabController.index == 0
        ? _categories[0]
        : _categories[_tabController.index - 1];

    String selectedPaymentMethod = isEdit
        ? expense.paymentMethod
        : _paymentMethods[0];

    DateTime selectedDate = isEdit ? expense.date : DateTime.now();

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 48),
            decoration: const BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Padding(
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
                        isEdit ? 'Edit Expense' : 'Add Expense',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: kBlue,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _buildAttractiveTextField(
                        controller: nameController,
                        label: 'Expense Name',
                        icon: Icons.title,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Expense name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildAttractiveTextField(
                        controller: dateController,
                        label: 'Date',
                        icon: Icons.calendar_today,
                        readOnly: true,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setModalState(() {
                              selectedDate = date;
                              dateController.text = DateFormat(
                                'yyyy-MM-dd',
                              ).format(date);
                            });
                          }
                        },
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Date is required';
                          }
                          return null;
                        },
                        suffixIcon: Icons.edit_calendar,
                      ),
                      const SizedBox(height: 18),
                      _buildAttractiveDropdown(
                        value: selectedCategory,
                        label: 'Category',
                        icon: Icons.category,
                        items: _categories,
                        onChanged: (value) {
                          setModalState(() {
                            selectedCategory = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildAttractiveTextField(
                        controller: amountController,
                        label: 'Amount (Rs)',
                        icon: Icons.attach_money,
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Amount is required';
                          }
                          if (double.tryParse(val.trim()) == null) {
                            return 'Enter a valid number';
                          }
                          if (double.parse(val.trim()) <= 0) {
                            return 'Amount must be greater than 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildAttractiveDropdown(
                        value: selectedPaymentMethod,
                        label: 'Payment Method',
                        icon: Icons.payment,
                        items: _paymentMethods,
                        onChanged: (value) {
                          setModalState(() {
                            selectedPaymentMethod = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildAttractiveTextField(
                        controller: descriptionController,
                        label: 'Notes',
                        icon: Icons.note,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: kBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Color(0xFF1976D2),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              side: BorderSide.none,
                            ),
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                if (isEdit) {
                                  final updatedExpense = Expense(
                                    id: expense.id,
                                    date: selectedDate,
                                    category: selectedCategory,
                                    amount: double.parse(amountController.text),
                                    paymentMethod: selectedPaymentMethod,
                                    description:
                                        descriptionController.text.isNotEmpty
                                        ? descriptionController.text
                                        : null,
                                    name: nameController.text.trim(),
                                  );
                                  await _expenseRepo.updateExpense(
                                    updatedExpense,
                                  );
                                  await ActivityRepository().logActivity(
                                    Activity(
                                      type: 'expense_edit',
                                      description:
                                          'Edited expense: ${nameController.text.trim()} (Rs ${amountController.text})',
                                      timestamp: DateTime.now(),
                                      metadata: {
                                        'id': expense.id,
                                        'name': nameController.text.trim(),
                                        'amount': amountController.text,
                                        'category': selectedCategory,
                                      },
                                    ),
                                  );
                                } else {
                                  final newExpense = Expense(
                                    date: selectedDate,
                                    category: selectedCategory,
                                    amount: double.parse(amountController.text),
                                    paymentMethod: selectedPaymentMethod,
                                    description:
                                        descriptionController.text.isNotEmpty
                                        ? descriptionController.text
                                        : null,
                                    name: nameController.text.trim(),
                                  );
                                  await _expenseRepo.insertExpense(newExpense);
                                  await ActivityRepository().logActivity(
                                    Activity(
                                      type: 'expense_add',
                                      description:
                                          'Added expense: ${nameController.text.trim()} (Rs ${amountController.text})',
                                      timestamp: DateTime.now(),
                                      metadata: {
                                        'name': nameController.text.trim(),
                                        'amount': amountController.text,
                                        'category': selectedCategory,
                                      },
                                    ),
                                  );
                                }
                                await _loadExpensesFromDb();
                                Navigator.pop(context);
                              }
                            },
                            child: Text(
                              'Save',
                              style: TextStyle(color: Color(0xFF1976D2)),
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
        ),
      ),
    );
  }

  void _deleteExpense(Expense expense) async {
    await _expenseRepo.deleteExpense(expense.id!);
    await ActivityRepository().logActivity(
      Activity(
        type: 'expense_delete',
        description: 'Deleted expense: ${expense.name} (Rs ${expense.amount})',
        timestamp: DateTime.now(),
        metadata: {
          'id': expense.id,
          'name': expense.name,
          'amount': expense.amount,
          'category': expense.category,
        },
      ),
    );
    await _loadExpensesFromDb();
  }

  @override
  Widget build(BuildContext context) {
    int idx = _tabController.index;
    String category = idx == 0 ? 'all' : _categories[idx - 1];
    String totalLabel = idx == 0 ? 'Total Expenses' : '$category Total';

    return DefaultTabController(
      length: _categories.length + 1,
      child: Scaffold(
        backgroundColor: kWhite,
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true,
          title: Text(
            'Expenses',
            style: const TextStyle(
              fontSize: 22,
              color: Color(0xFF0A2342),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF0A2342)),
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: BouncingScrollPhysics(),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicator: UnderlineTabIndicator(
                    borderSide: BorderSide(width: 3, color: Color(0xFF1976D2)),
                  ),
                  labelColor: Color(0xFF1976D2),
                  unselectedLabelColor: Color(0xFF1976D2).withOpacity(0.5),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 15,
                  ),
                  tabs: [
                    const Tab(text: 'ALL'),
                    ..._categories.map(
                      (category) => Tab(
                        child: Row(
                          children: [
                            Icon(
                              _getCategoryIcon(category),
                              size: 16,
                              color: Color(0xFF1976D2),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              category,
                              style: TextStyle(color: Color(0xFF1976D2)),
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
        ),
        body: Column(
          children: [
            // Total Expense Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Container(
                  width: double.infinity,
                  height: 90,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        flex: 2,
                        child: Row(
                          children: [
                            Icon(
                              Icons.money_off_csred_rounded,
                              color: kWhite,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                totalLabel,
                                style: const TextStyle(
                                  color: kWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: 0.5,
                                  overflow: TextOverflow.ellipsis,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        flex: 1,
                        child: Text(
                          'Rs ${_getTotalExpense(category).toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 0.5,
                            overflow: TextOverflow.ellipsis,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                    _filterExpenses();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by description, vendor, or reference...',
                  prefixIcon: Icon(Icons.search, color: kBlue),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.filter_alt, color: kBlue),
                    tooltip: 'Filter & Sort',
                    onPressed: _showFilterDialog,
                  ),
                  filled: true,
                  fillColor: kCardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                ),
              ),
            ),

            // Expenses List
            Expanded(
              child: _filteredExpenses.isEmpty
                  ? Center(
                      child: Text(
                        'No Expenses Found',
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredExpenses.length,
                      itemBuilder: (context, idx) {
                        final expense = _filteredExpenses[idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Dismissible(
                            key: ValueKey(expense.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 32,
                              ),
                            ),
                            onDismissed: (direction) {
                              _deleteExpense(expense);
                            },
                            child: Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    _showAddEditExpense(expense: expense),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  constraints: const BoxConstraints(
                                    minHeight: 80,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: _getCategoryColor(
                                          expense.category,
                                        ).withAlpha((0.1 * 255).toInt()),
                                        child: Icon(
                                          _getCategoryIcon(expense.category),
                                          color: _getCategoryColor(
                                            expense.category,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    expense.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  'Rs ${expense.amount.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            if (expense.vendor != null &&
                                                expense.vendor!.isNotEmpty)
                                              Text(
                                                expense.vendor!,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                // Category container
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            _getCategoryColor(
                                                              expense.category,
                                                            ).withAlpha(
                                                              (0.1 * 255)
                                                                  .toInt(),
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        expense.category,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              _getCategoryColor(
                                                                expense
                                                                    .category,
                                                              ),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                Color(
                                                                  0xFF1976D2,
                                                                ).withAlpha(
                                                                  (0.1 * 255)
                                                                      .toInt(),
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            expense
                                                                .paymentMethod,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 11,
                                                                  color: Color(
                                                                    0xFF1976D2,
                                                                  ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          DateFormat(
                                                            'dd MMM, yyyy',
                                                          ).format(
                                                            expense.date,
                                                          ),
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey[500],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      PopupMenuButton<String>(
                                        icon: const Icon(
                                          Icons.more_vert,
                                          color: Colors.black54,
                                          size: 22,
                                        ),
                                        onSelected: (value) {
                                          if (value == 'details') {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                ),
                                                content: SizedBox(
                                                  height:
                                                      MediaQuery.of(
                                                                context,
                                                              ).size.height *
                                                              0.5 >
                                                          300
                                                      ? 300
                                                      : MediaQuery.of(
                                                              context,
                                                            ).size.height *
                                                            0.5,
                                                  child: Scrollbar(
                                                    thumbVisibility: true,
                                                    child: SingleChildScrollView(
                                                      padding: EdgeInsets.all(
                                                        18,
                                                      ),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Description:',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: kBlue,
                                                            ),
                                                          ),
                                                          SizedBox(height: 6),
                                                          Text(
                                                            expense.description ??
                                                                'No description',
                                                            style: TextStyle(
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx),
                                                    child: Text(
                                                      'Close',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          } else if (value == 'edit') {
                                            _showAddEditExpense(
                                              expense: expense,
                                            );
                                          } else if (value == 'delete') {
                                            _deleteExpense(expense);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'details',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.info_outline,
                                                  color: kBlue,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text('Details'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.edit,
                                                  color: Colors.blue,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text('Delete'),
                                              ],
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
                      },
                    ),
            ),
          ],
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
            onPressed: () => _showAddEditExpense(),
            tooltip: 'Add Expense',
          ),
        ),
      ),
    );
  }
}

Widget _buildAttractiveTextField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
  bool readOnly = false,
  int maxLines = 1,
  void Function()? onTap,
  IconData? suffixIcon,
}) {
  return Material(
    elevation: 1.0,
    borderRadius: BorderRadius.circular(10),
    shadowColor: Colors.black12,
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      maxLines: maxLines,
      onTap: onTap,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kBlue, fontSize: 14),
        prefixIcon: Icon(icon, color: kBlue, size: 20),
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, color: kBlue, size: 20)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kLightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kLightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBlue),
        ),
        filled: true,
        fillColor: kWhite,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 10,
        ),
      ),
    ),
  );
}

Widget _buildAttractiveDropdown({
  required String value,
  required String label,
  required IconData icon,
  required List<String> items,
  required void Function(String?) onChanged,
}) {
  return Material(
    elevation: 1.0,
    borderRadius: BorderRadius.circular(10),
    shadowColor: Colors.black12,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kWhite, kF8F9FA, kF1F3F4],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: DropdownButtonFormField2<String>(
        value: value,
        isExpanded: true,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        dropdownStyleData: DropdownStyleData(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kWhite, kF8F9FA, kF1F3F4],
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          offset: const Offset(0, -4),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: kBlue,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(icon, color: kBlue, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kLightBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kLightBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBlue, width: 1.5),
          ),
          filled: true,
          fillColor: kTransparent,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 12,
          ),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
        buttonStyleData: ButtonStyleData(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kLightBorder),
          ),
        ),
        menuItemStyleData: MenuItemStyleData(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    ),
  );
}
