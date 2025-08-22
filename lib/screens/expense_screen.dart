// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:forward_billing_app/providers/dashboard_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../repositories/expense_repository.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../models/activity.dart';
import '../repositories/activity_repository.dart';
import '../themes/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/auth_utils.dart';
import '../utils/refresh_manager.dart';
import 'home_screen.dart';
import 'package:flutter/foundation.dart';
import 'login_screen.dart' as login;

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
          title: Text('Filter & Sort'),
          content: StatefulBuilder(
            builder: (context, setModalState) => SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.45,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                shrinkWrap: true,
                children: [
                  Text('Sort by:'),
                  RadioListTile<String>(
                    value: 'date_desc',
                    groupValue: tempSortBy,
                    onChanged: (v) => setModalState(() => tempSortBy = v!),
                    title: Text('Date (Newest)'),
                  ),
                  RadioListTile<String>(
                    value: 'date_asc',
                    groupValue: tempSortBy,
                    onChanged: (v) => setModalState(() => tempSortBy = v!),
                    title: Text('Date (Oldest)'),
                  ),
                  RadioListTile<String>(
                    value: 'amount_desc',
                    groupValue: tempSortBy,
                    onChanged: (v) => setModalState(() => tempSortBy = v!),
                    title: Text('Amount (High-Low)'),
                  ),
                  RadioListTile<String>(
                    value: 'amount_asc',
                    groupValue: tempSortBy,
                    onChanged: (v) => setModalState(() => tempSortBy = v!),
                    title: Text('Amount (Low-High)'),
                  ),
                  RadioListTile<String>(
                    value: 'name_asc',
                    groupValue: tempSortBy,
                    onChanged: (v) => setModalState(() => tempSortBy = v!),
                    title: Text('Name (A-Z)'),
                  ),
                  RadioListTile<String>(
                    value: 'name_desc',
                    groupValue: tempSortBy,
                    onChanged: (v) => setModalState(() => tempSortBy = v!),
                    title: Text('Name (Z-A)'),
                  ),
                  Divider(),
                  Text('Payment Method:'),
                  DropdownButton2<String?>(
                    value: tempPaymentMethod,
                    isExpanded: true,
                    hint: Text('All'),
                    items: [
                      DropdownMenuItem(value: null, child: Text('All')),
                      ..._paymentMethods.map(
                        (m) => DropdownMenuItem(value: m, child: Text(m)),
                      ),
                    ],
                    onChanged: (v) =>
                        setModalState(() => tempPaymentMethod = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: AppTheme.getStandardCancelButtonStyle(context),
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
              child: Text('Apply'),
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
    final uid = await getCurrentUserUid();
    debugPrint('ExpenseScreen: _loadExpensesFromDb fetched UID: $uid');
    if (uid == null || uid.isEmpty) {
      setState(() {
        _allExpenses = [];
        _filterExpenses();
      });
      return;
    }
    final expenses = await _expenseRepo.getAllExpenses(uid);
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: EdgeInsets.only(top: 48),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(context),
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
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                      SizedBox(height: 22),
                      _buildAttractiveTextField(
                        context: context,
                        controller: nameController,
                        label: 'Expense Name',
                        icon: Icons.title,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Expense name is required';
                          }
                          if (val.trim().length < 2 ||
                              val.trim().length > 100) {
                            return 'Expense name must be 2-100 characters.';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 18),
                      _buildAttractiveTextField(
                        context: context,
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
                      SizedBox(height: 18),
                      _buildAttractiveDropdown(
                        context: context,
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
                      SizedBox(height: 18),
                      _buildAttractiveTextField(
                        context: context,
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
                      SizedBox(height: 18),
                      _buildAttractiveDropdown(
                        context: context,
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
                      SizedBox(height: 18),
                      _buildAttractiveTextField(
                        context: context,
                        controller: descriptionController,
                        label: 'Notes',
                        icon: Icons.note,
                        maxLines: 2,
                        validator: (val) {
                          if (val != null && val.length > 100) {
                            return 'Notes can be at most 100 characters.';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Color(0xFF1976D2),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(width: 12),
                          Container(
                            decoration: AppTheme.getGradientDecoration(),
                            child: ElevatedButton(
                              style: AppTheme.getGradientSaveButtonStyle(
                                context,
                              ),
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  // Fetch UID (can fail silently if offline, and use a fallback ID if needed)
                                  getCurrentUserUid()
                                      .then((uid) {
                                        debugPrint(
                                          'ExpenseScreen: Save pressed, fetched UID: $uid',
                                        );

                                        final safeUid = uid ?? 'offline_user';

                                        final isValidUid = safeUid.isNotEmpty;
                                        if (!isValidUid) {
                                          debugPrint(
                                            'ExpenseScreen: WARNING: UID is empty. Proceeding offline.',
                                          );
                                        }

                                        if (isEdit) {
                                          final updatedExpense = Expense(
                                            id: expense.id,
                                            userId: safeUid,
                                            date: selectedDate,
                                            category: selectedCategory,
                                            amount: double.parse(
                                              amountController.text,
                                            ),
                                            paymentMethod:
                                                selectedPaymentMethod,
                                            description:
                                                descriptionController
                                                    .text
                                                    .isNotEmpty
                                                ? descriptionController.text
                                                : null,
                                            name: nameController.text.trim(),
                                          );

                                          _expenseRepo.updateExpense(
                                            updatedExpense,
                                          ); // No await

                                          // Log activity (non-blocking)
                                          ActivityRepository().logActivity(
                                            Activity(
                                              userId: safeUid,
                                              type: 'expense_edit',
                                              description:
                                                  'Edited expense: ${nameController.text.trim()} (Rs ${amountController.text})',
                                              timestamp: DateTime.now(),
                                              metadata: {
                                                'id': expense.id,
                                                'name': nameController.text
                                                    .trim(),
                                                'amount': amountController.text,
                                                'category': selectedCategory,
                                              },
                                            ),
                                          );
                                        } else {
                                          final newExpense = Expense(
                                            userId: safeUid,
                                            date: selectedDate,
                                            category: selectedCategory,
                                            amount: double.parse(
                                              amountController.text,
                                            ),
                                            paymentMethod:
                                                selectedPaymentMethod,
                                            description:
                                                descriptionController
                                                    .text
                                                    .isNotEmpty
                                                ? descriptionController.text
                                                : null,
                                            name: nameController.text.trim(),
                                          );

                                          _expenseRepo.insertExpense(
                                            newExpense,
                                          ); // No await

                                          // Refresh UI (local)

                                          // Log activity (non-blocking)
                                          ActivityRepository().logActivity(
                                            Activity(
                                              userId: safeUid,
                                              type: 'expense_add',
                                              description:
                                                  'Added expense: ${nameController.text.trim()} (Rs ${amountController.text})',
                                              timestamp: DateTime.now(),
                                              metadata: {
                                                'name': nameController.text
                                                    .trim(),
                                                'amount': amountController.text,
                                                'category': selectedCategory,
                                              },
                                            ),
                                          );
                                        }

                                        // Load from local DB
                                        _loadExpensesFromDb(); // No await

                                        Navigator.pop(context);
                                      })
                                      .catchError((e) {
                                        debugPrint(
                                          "ExpenseScreen: ERROR fetching UID: $e",
                                        );
                                        // Still save expense offline with fallback UID
                                        final fallbackUid = 'offline_user';

                                        final newExpense = Expense(
                                          userId: fallbackUid,
                                          date: selectedDate,
                                          category: selectedCategory,
                                          amount: double.parse(
                                            amountController.text,
                                          ),
                                          paymentMethod: selectedPaymentMethod,
                                          description:
                                              descriptionController
                                                  .text
                                                  .isNotEmpty
                                              ? descriptionController.text
                                              : null,
                                          name: nameController.text.trim(),
                                        );

                                        _expenseRepo.insertExpense(
                                          newExpense,
                                        ); // fallback save

                                        final refreshManager =
                                            Provider.of<RefreshManager>(
                                              context,
                                              listen: false,
                                            );
                                        refreshManager.refreshExpenses();
                                        refreshManager.refreshDashboard();

                                        final dashboardProvider =
                                            Provider.of<DashboardProvider>(
                                              context,
                                              listen: false,
                                            );

                                        _loadExpensesFromDb(); // fallback reload

                                        Navigator.pop(context);
                                      });
                                }
                              },

                              child: Text('Save'),
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
    final uid = await getCurrentUserUid();
    debugPrint('ExpenseScreen: _deleteExpense fetched UID: $uid');
    if (uid == null || uid.isEmpty) return;

    // Ensure expense.id is properly cast to int
    final expenseId = expense.id;
    if (expenseId == null) {
      debugPrint('ExpenseScreen: ERROR: expense.id is null!');
      return;
    }

    await _expenseRepo.deleteExpense(expenseId, uid);

    // Trigger refresh for all screens
    final refreshManager = Provider.of<RefreshManager>(context, listen: false);
    refreshManager.refreshExpenses();
    refreshManager.refreshDashboard();

    // Also trigger dashboard refresh directly

    await ActivityRepository().logActivity(
      Activity(
        userId: uid,
        type: 'expense_delete',
        description: 'Deleted expense: ${expense.name} (Rs ${expense.amount})',
        timestamp: DateTime.now(),
        metadata: {
          'id': expenseId,
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0A2342)
            : Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A2233)
              : Colors.white,
          centerTitle: true,
          title: Text(
            'Expenses',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          iconTheme: IconThemeData(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Theme.of(context).textTheme.bodyLarge?.color,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
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
                  labelColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Color(0xFF1976D2),
                  unselectedLabelColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.7)
                      : Color(0xFF1976D2).withOpacity(0.5),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 15,
                  ),
                  tabs: [
                    Tab(text: 'ALL'),
                    ..._categories.map(
                      (category) => Tab(
                        child: Row(
                          children: [
                            Icon(
                              _getCategoryIcon(category),
                              size: 16,
                              color: Color(0xFF1976D2),
                            ),
                            SizedBox(width: 4),
                            Text(
                              category,
                              style: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Color(0xFF1976D2),
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
        ),
        body: Column(
          children: [
            // Total Expense Card
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                totalLabel,
                                style: TextStyle(
                                  color: Colors.white,
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
                      SizedBox(width: 10),
                      Flexible(
                        flex: 1,
                        child: Text(
                          'Rs ${_getTotalExpense(category).toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.white,
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
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _filterExpenses();
                        });
                      },
                      decoration: InputDecoration(
                        hintText:
                            'Search by description, vendor, or reference...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppTheme.getPrimaryColor(context),
                        ),
                        filled: true,
                        fillColor: AppTheme.getCardColor(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF0A2342),
                          Color(0xFF123060),
                          Color(0xFF1976D2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.filter_alt, color: Colors.white),
                      tooltip: 'Filter & Sort',
                      onPressed: _showFilterDialog,
                    ),
                  ),
                ],
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Dismissible(
                            key: ValueKey(expense.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFDC3545)
                                    : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.delete,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.red,
                                size: 32,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withAlpha(
                                            (0.1 * 255).toInt(),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.warning_rounded,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('Delete Expense?'),
                                    ],
                                  ),
                                  content: Text(
                                    'Are you sure you want to delete "${expense.name}"? This action cannot be undone.',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                _deleteExpense(expense);
                              }
                              return confirmed;
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
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  constraints: BoxConstraints(minHeight: 80),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF013A63)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
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
                                      SizedBox(width: 12),
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
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color:
                                                          Theme.of(
                                                                context,
                                                              ).brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Container(
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    'Rs ${expense.amount.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.red,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 4),
                                            if (expense.vendor != null &&
                                                expense.vendor!.isNotEmpty)
                                              Text(
                                                expense.vendor!,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? Colors.white
                                                            .withOpacity(0.8)
                                                      : Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            SizedBox(height: 2),
                                            Row(
                                              children: [
                                                // Category container
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
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
                                                              Theme.of(
                                                                    context,
                                                                  ).brightness ==
                                                                  Brightness
                                                                      .dark
                                                              ? Colors.white
                                                              : _getCategoryColor(
                                                                  expense
                                                                      .category,
                                                                ),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              EdgeInsets.symmetric(
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
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      ).brightness ==
                                                                      Brightness
                                                                          .dark
                                                                  ? Colors.white
                                                                  : Color(
                                                                      0xFF1976D2,
                                                                    ),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(width: 8),
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
                                      SizedBox(width: 4),
                                      Container(
                                        alignment: Alignment.center,
                                        child: PopupMenuButton<String>(
                                          icon: Icon(
                                            Icons.more_vert,
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black54,
                                            size: 22,
                                          ),
                                          onSelected: (value) {
                                            if (value == 'details') {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          18,
                                                        ),
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
                                                                color:
                                                                    AppTheme.getPrimaryColor(
                                                                      context,
                                                                    ),
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
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'details',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.info_outline,
                                                    color:
                                                        AppTheme.getPrimaryColor(
                                                          context,
                                                        ),
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Details'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.edit,
                                                    color: Color(0xFF1976D2),
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Edit'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
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
  required BuildContext context,
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
    borderRadius: BorderRadius.circular(12),
    shadowColor: AppTheme.getShadowColor(context),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      maxLines: maxLines,
      onTap: onTap,
      style: TextStyle(color: AppTheme.getTextColor(context)),
      decoration: AppTheme.getStandardInputDecoration(
        context,
        labelText: label,
        hintText: label,
        prefixIcon: icon,
        suffixIcon: suffixIcon,
      ),
    ),
  );
}

Widget _buildAttractiveDropdown({
  required BuildContext context,
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
          colors: [
            AppTheme.getBackgroundColor(context),
            AppTheme.getBackgroundColor(context),
            AppTheme.getBackgroundColor(context),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: DropdownButtonFormField2<String>(
        value: value,
        isExpanded: true,
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.getTextColor(context),
          fontWeight: FontWeight.w500,
        ),
        dropdownStyleData: DropdownStyleData(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.getBackgroundColor(context),
                AppTheme.getBackgroundColor(context),
                AppTheme.getBackgroundColor(context),
              ],
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
          labelStyle: TextStyle(
            color: AppTheme.getPrimaryColor(context),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(
            icon,
            color: AppTheme.getPrimaryColor(context),
            size: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.getTextColor(context),
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
            border: Border.all(color: Colors.transparent),
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
