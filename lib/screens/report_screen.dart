// ignore_for_file: unrelated_type_equality_checks

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../repositories/bill_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/people_repository.dart';
import '../repositories/expense_repository.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/inventory_item.dart';
import '../models/people.dart';
import '../models/expense.dart';
import 'widgets/kpi_card.dart';
import 'widgets/kpi_shimmer.dart';
import 'widgets/chart_line.dart';
import 'widgets/chart_pie.dart';
import 'widgets/chart_comparison.dart';
import 'widgets/detailed_report_container.dart';
import 'widgets/filter_chips.dart';
import 'widgets/data_table.dart';
import 'widgets/export_buttons.dart';
import 'widgets/theme_toggle.dart';
import 'widgets/date_range_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/auth_utils.dart';
import '../utils/refresh_manager.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

const Color accentGreen = Color(0xFF128C7E); // WhatsApp green

class ReportProvider with ChangeNotifier {
  bool _disposed = false;
  final BillRepository billRepo;
  final InventoryRepository inventoryRepo;
  final PeopleRepository peopleRepo;
  final ExpenseRepository expenseRepo;
  RefreshManager? refreshManager;
  // Optional initial data to render instantly before streams emit
  final List<Bill>? initialBills;
  final List<InventoryItem>? initialInventory;
  final List<People>? initialPeople;
  final List<Expense>? initialExpenses;

  ReportProvider({
    required this.billRepo,
    required this.inventoryRepo,
    required this.peopleRepo,
    required this.expenseRepo,
    this.refreshManager,
    this.initialBills,
    this.initialInventory,
    this.initialPeople,
    this.initialExpenses,
  }) {
    // Seed from provided initial data for instant UI
    if (initialBills != null) _allBills = List<Bill>.from(initialBills!);
    if (initialInventory != null) {
      _inventory = List<InventoryItem>.from(initialInventory!);
    }
    if (initialPeople != null) _peoples = List<People>.from(initialPeople!);
    if (initialExpenses != null) _expenses = List<Expense>.from(initialExpenses!);
    if (initialBills != null || initialInventory != null || initialPeople != null || initialExpenses != null) {
      isLoading = false; // We can show something instantly
      _recomputeAll();
    }
    _initializeData();
  }

  // Recompute all derived data from current in-memory lists.
  void _recomputeAll() {
    _calculateKPIs();
    _generateChartData();
    _generateComparisonChartData();
    _generateTableData();
    _generateDetailedSummaries();
  }

  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  String selectedChartType = 'Line';
  String totalSales = '0';
  String revenue = '0';
  String expense = '0';
  String profit = '0';
  double salesChange = 0;
  double revenueChange = 0;
  double expenseChange = 0;
  double profitChange = 0;

  // Stream subscriptions
  StreamSubscription<List<Bill>>? _billsSub;
  StreamSubscription<List<InventoryItem>>? _inventorySub;
  StreamSubscription<List<People>>? _peopleSub;
  StreamSubscription<List<Expense>>? _expensesSub;
  

  Future<void> _initializeData() async {
    try {
      isLoading = true;
      hasError = false;
      errorMessage = '';
      safeNotifyListeners();

      // Get UID and subscribe to streams
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('current_uid');
      debugPrint('ReportProvider: init streams with UID: $uid');

      if (uid == null || uid.isEmpty) {
        // No user yet; show empty state instantly
        _attachEmptyData();
        isLoading = false;
        safeNotifyListeners();
        return;
      }

      _subscribeToStreams(uid);

      // Non-blocking enrichment for bill items used in top-products/avg-items
      // Keep UI instant; this completes in background and triggers recompute
      unawaited(_loadAllBillItemsInBackground(uid));
    } catch (e) {
      debugPrint('Error initializing ReportProvider: $e');
      hasError = true;
      errorMessage = 'Failed to initialize data: $e';
      isLoading = false;
      safeNotifyListeners();
    }
  }

  void _attachEmptyData() {
    _allBills = [];
    _allBillItems = [];
    _inventory = [];
    _peoples = [];
    _expenses = [];
    _recomputeAll();
  }

  void _subscribeToStreams(String uid) {
    // Cancel previous if any
    _billsSub?.cancel();
    _inventorySub?.cancel();
    _peopleSub?.cancel();
    _expensesSub?.cancel();

    _billsSub = billRepo.streamBills(uid).listen((bills) {
      _allBills = bills;
      _recomputeAll();
      if (isLoading) {
        isLoading = false; // First data arrived -> render instantly
      }
      safeNotifyListeners();
    }, onError: (e) {
      _handleStreamError(e);
    });

    _inventorySub = inventoryRepo.streamItems(uid).listen((items) {
      _inventory = items;
      _recomputeAll();
      safeNotifyListeners();
    }, onError: (e) {
      _handleStreamError(e);
    });

    _peopleSub = peopleRepo.getPeopleStream(uid).listen((people) {
      _peoples = people;
      _recomputeAll();
      safeNotifyListeners();
    }, onError: (e) {
      _handleStreamError(e);
    });

    _expensesSub = expenseRepo.streamExpenses(uid).listen((expenses) {
      _expenses = expenses;
      _recomputeAll();
      safeNotifyListeners();
    }, onError: (e) {
      _handleStreamError(e);
    });
  }

  void _handleStreamError(Object e) {
    debugPrint('ReportProvider stream error: $e');
    hasError = true;
    errorMessage = 'Failed to load data: $e';
    isLoading = false;
    safeNotifyListeners();
  }

  Future<void> _loadAllBillItemsInBackground(String uid) async {
    try {
      final items = await billRepo.getAllBillItemsForUser(uid);
      _allBillItems = items;
      _recomputeAll();
      safeNotifyListeners();
    } catch (e) {
      debugPrint('ReportProvider: background bill items load failed: $e');
      // Do not flip hasError to avoid impacting main UI; keep best-effort
    }
  }

  // Chart data
  List<FlSpot> lineChartData = [];
  List<String> lineChartLabels = [];
  List<PieChartSectionData> pieChartSections = [];
  List<String> pieChartLabels = [];
  List<Color> pieChartColors = [];

  // Comparison chart data (Sales vs Purchase)
  List<FlSpot> salesChartData = [];
  List<FlSpot> purchaseChartData = [];
  List<String> comparisonChartLabels = [];

  // Table data
  List<Map<String, dynamic>> tableData = [];

  // Raw data
  List<Bill> _allBills = [];
  List<BillItem> _allBillItems = [];
  List<InventoryItem> _inventory = [];
  List<People> _peoples = [];
  List<Expense> _expenses = [];

  // Detailed report data
  Map<String, dynamic> salesSummary = {};
  Map<String, dynamic> purchaseSummary = {};
  Map<String, dynamic> expenseSummary = {};
  Map<String, dynamic> peopleSummary = {};

  // Removed duplicate unnamed constructor to fix compile error

  void setRefreshManager(RefreshManager rm) {
    refreshManager = rm;
    refreshManager!.addListener(_onRefreshRequested);
  }

  void _onRefreshRequested() {
    debugPrint(
      'ReportProvider: _onRefreshRequested called - shouldRefreshReports: ${refreshManager?.shouldRefreshReports}',
    );
    if (refreshManager != null && refreshManager!.shouldRefreshReports) {
      debugPrint('ReportProvider: Refresh requested, reloading data');
      _loadData();
      refreshManager!.clearReportsRefresh();
    }
  }

  Future<void> _loadData() async {
    debugPrint('ReportProvider: _loadData called');
    try {
      isLoading = true;
      hasError = false;
      errorMessage = '';
      notifyListeners();

      // Fetch UID once for all queries
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('current_uid');
      debugPrint('ReportProvider: _loadData fetched UID: $uid');

      // Fetch all data for this user
      _allBills = uid != null ? await billRepo.getAllBills(uid) : <Bill>[];
      debugPrint(
        'ReportProvider: fetched ${_allBills.length} bills for UID: $uid',
      );
      _allBillItems = uid != null
          ? await billRepo.getAllBillItemsForUser(uid)
          : <BillItem>[];
      debugPrint(
        'ReportProvider: fetched ${_allBillItems.length} bill items for UID: $uid',
      );
      _inventory = uid != null
          ? await inventoryRepo.getAllItems(uid)
          : <InventoryItem>[];
      debugPrint(
        'ReportProvider: fetched ${_inventory.length} inventory items for UID: $uid',
      );
      _peoples = uid != null ? await peopleRepo.getAllPeople(uid) : <People>[];
      debugPrint(
        'ReportProvider: fetched ${_peoples.length} people for UID: $uid',
      );
      _expenses = uid != null
          ? await expenseRepo.getAllExpenses(uid)
          : <Expense>[];
      debugPrint(
        'ReportProvider: fetched ${_expenses.length} expenses for UID: $uid',
      );

      // Calculate KPIs
      _calculateKPIs();

      // Generate chart data
      _generateChartData();

      // Generate comparison chart data
      _generateComparisonChartData();

      // Generate table data
      _generateTableData();

      // Generate detailed summaries
      _generateDetailedSummaries();

      isLoading = false;
      debugPrint('ReportProvider: _loadData completed successfully');
      safeNotifyListeners();
    } catch (e) {
      errorMessage = 'Failed to load data. Please try again.';
      hasError = true;
      isLoading = false;
      safeNotifyListeners();
    }
  }

  void _calculateKPIs() {
    // Calculate total sales from bills
    double totalSalesAmount = _allBills.fold(
      0.0,
      (sum, bill) => sum + (bill.total ?? 0),
    );
    totalSales = 'Rs ${totalSalesAmount.toStringAsFixed(2)}';

    // Calculate revenue (same as total sales for now)
    revenue = 'Rs ${totalSalesAmount.toStringAsFixed(2)}';

    // Calculate total expenses
    double totalExpensesAmount = _expenses.fold(
      0.0,
      (sum, exp) => sum + exp.amount,
    );
    expense = 'Rs ${totalExpensesAmount.toStringAsFixed(2)}';

    // Calculate profit
    double profitAmount = totalSalesAmount - totalExpensesAmount;
    profit = 'Rs ${profitAmount.toStringAsFixed(2)}';

    // Calculate percentage changes (placeholder - you can implement real comparison logic)
    salesChange = 5.2; // Example: 5.2% increase
    revenueChange = 5.2;
    expenseChange = -2.1; // Example: 2.1% decrease
    profitChange = 8.3;
  }

  void _generateChartData() {
    // Generate line chart data (last 7 days)
    lineChartData = [];
    lineChartLabels = [];

    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final daySales = _allBills
          .where((bill) => _isSameDay(bill.date, date))
          .fold(0.0, (sum, bill) => sum + (bill.total ?? 0));

      lineChartData.add(FlSpot((6 - i).toDouble(), daySales));
      lineChartLabels.add(DateFormat('MMM dd').format(date));
    }

    // Generate pie chart data (sales by payment method)
    final paymentMethods = <String, double>{};
    for (final bill in _allBills) {
      final method = bill.paymentMethod;
      paymentMethods[method] =
          (paymentMethods[method] ?? 0) + (bill.total ?? 0);
    }

    pieChartSections = [];
    pieChartLabels = [];
    pieChartColors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
      const Color(0xFF8B5CF6), // Violet
    ];

    int colorIndex = 0;
    paymentMethods.forEach((method, amount) {
      if (amount > 0) {
        pieChartSections.add(
          PieChartSectionData(
            value: amount,
            color: pieChartColors[colorIndex % pieChartColors.length],
            title: method,
            radius: 60,
          ),
        );
        pieChartLabels.add(method);
        colorIndex++;
      }
    });

    // Ensure we have at least one section to prevent crashes
    if (pieChartSections.isEmpty) {
      pieChartSections = [
        PieChartSectionData(
          value: 1,
          color: Colors.grey.shade400,
          title: 'No Data',
          radius: 60,
        ),
      ];
      pieChartLabels = ['No Data'];
      pieChartColors = [Colors.grey.shade400];
    }
  }

  void _generateComparisonChartData() {
    salesChartData = [];
    purchaseChartData = [];
    comparisonChartLabels = [];

    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));

      // Sales data
      final daySales = _allBills
          .where((bill) => _isSameDay(bill.date, date))
          .fold(0.0, (sum, bill) => sum + (bill.total ?? 0));
      salesChartData.add(FlSpot((6 - i).toDouble(), daySales));

      // Purchase data (using inventory items as proxy for purchases)
      final dayPurchase = _inventory
          .where((item) => _isSameDay(item.createdAt ?? DateTime.now(), date))
          .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
      purchaseChartData.add(FlSpot((6 - i).toDouble(), dayPurchase));

      comparisonChartLabels.add(DateFormat('MMM dd').format(date));
    }
  }

  void _generateTableData() {
    // Sort bills by date (most recent first) without string parsing
    final sortedBills = List<Bill>.from(_allBills)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Cap to first 500 to keep UI snappy; full export can use repositories
    final limited = sortedBills.take(500);

    tableData = limited.map((bill) {
      // Get bill items for this bill
      final billItems = _allBillItems
          .where((item) => item.billId == bill.id)
          .toList();
      // Remove itemNames and itemCount
      // Determine transaction type
      String type = 'Sales';
      // You can add logic for purchase/expense if needed
      return {
        'date': DateFormat('MMM dd, yyyy').format(bill.date),
        'time': DateFormat('HH:mm').format(bill.date),
        'invoiceId': bill.id ?? '',
        'customer': bill.customerName,
        'type': type,
        'amount': bill.total ?? 0.0,
        'payment': bill.paymentMethod,
        'status': 'Completed',
      };
    }).toList();

    // Ensure we have at least one row to prevent crashes
    if (tableData.isEmpty) {
      tableData = [
        {
          'date': 'No Data',
          'time': '',
          'invoiceId': '',
          'customer': '',
          'type': '',
          'amount': 0.0,
          'payment': '',
          'status': '',
        },
      ];
    }
  }

  void _generateDetailedSummaries() {
    // Sales Summary
    salesSummary = {
      'totalSales': _allBills.fold(0.0, (sum, bill) => sum + (bill.total ?? 0)),
      'totalBills': _allBills.length,
      'averageBillValue': _allBills.isEmpty
          ? 0.0
          : _allBills.fold(0.0, (sum, bill) => sum + (bill.total ?? 0)) /
                _allBills.length,
      'topProducts': _getTopProducts(),
      'paymentMethods': _getPaymentMethodBreakdown(),
      'dailySales': _getDailySalesData(),
      'recentBills': _allBills.take(10).toList(),
      'bestDay': _getBestDayOfSales(),
      'peakHour': _getPeakHourOfSales(),
      'averageItemsPerBill': _getAverageItemsPerBill(),
    };

    // Purchase Summary (using inventory as proxy)
    purchaseSummary = {
      'totalPurchase': _inventory.fold(
        0.0,
        (sum, item) => sum + (item.price * item.quantity),
      ),
      'totalItems': _inventory.length,
      'averageItemCost': _inventory.isEmpty
          ? 0.0
          : _inventory.fold(
                  0.0,
                  (sum, item) => sum + (item.price * item.quantity),
                ) /
                _inventory.length,
      'lowStockItems': _inventory.where((item) => item.quantity < 10).toList(),
      'topCategories': _getTopCategories(),
      'dailyPurchases': _getDailyPurchaseData(),
      'recentItems': _inventory.take(10).toList(),
    };

    // Expense Summary
    expenseSummary = {
      'totalExpenses': _expenses.fold(0.0, (sum, exp) => sum + exp.amount),
      'totalExpenseCount': _expenses.length,
      'averageExpense': _expenses.isEmpty
          ? 0.0
          : _expenses.fold(0.0, (sum, exp) => sum + exp.amount) /
                _expenses.length,
      'expenseCategories': _getExpenseCategories(),
      // switched to daily to align with sales and purchase charts
      'dailyExpenses': _getDailyExpenseData(),
      'recentExpenses': _expenses.take(10).toList(),
    };

    // People Summary
    peopleSummary = {
      'totalPeople': _peoples.length,
      'customers': _peoples.where((p) => p.category == 'customer').length,
      'suppliers': _peoples.where((p) => p.category == 'supplier').length,
      'employees': _peoples.where((p) => p.category == 'employee').length,
      'topCustomers': _getTopCustomers(),
      'peopleByType': _getPeopleByType(),
      'recentPeople': _peoples.take(10).toList(),
    };
  }

  List<Map<String, dynamic>> _getTopProducts() {
    final productSales = <String, double>{};
    for (final item in _allBillItems) {
      final productName = item.name;
      productSales[productName] = (productSales[productName] ?? 0) + item.total;
    }

    final sortedProducts = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedProducts
        .take(5)
        .map((e) => {'name': e.key, 'sales': e.value})
        .toList();
  }

  Map<String, double> _getPaymentMethodBreakdown() {
    final breakdown = <String, double>{};
    for (final bill in _allBills) {
      final method = bill.paymentMethod;
      breakdown[method] = (breakdown[method] ?? 0) + (bill.total ?? 0);
    }
    return breakdown;
  }

  List<Map<String, dynamic>> _getDailySalesData() {
    final dailyData = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final daySales = _allBills
          .where((bill) => _isSameDay(bill.date, date))
          .fold(0.0, (sum, bill) => sum + (bill.total ?? 0));

      dailyData.add({
        'date': DateFormat('MMM dd').format(date),
        'sales': daySales,
      });
    }

    return dailyData;
  }

  List<Map<String, dynamic>> _getTopCategories() {
    // Since InventoryItem doesn't have category, we'll use a placeholder
    return [
      {'name': 'General', 'count': _inventory.length},
    ];
  }

  List<Map<String, dynamic>> _getDailyPurchaseData() {
    final dailyData = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayPurchase = _inventory
          .where((item) => _isSameDay(item.createdAt ?? DateTime.now(), date))
          .fold(0.0, (sum, item) => sum + (item.price * item.quantity));

      dailyData.add({
        'date': DateFormat('MMM dd').format(date),
        'purchase': dayPurchase,
      });
    }

    return dailyData;
  }

  List<Map<String, dynamic>> _getDailyExpenseData() {
    final dailyData = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayExpense = _expenses
          .where((exp) => _isSameDay(exp.date, date))
          .fold(0.0, (sum, exp) => sum + exp.amount);

      dailyData.add({
        'date': DateFormat('MMM dd').format(date),
        'expenses': dayExpense,
      });
    }

    return dailyData;
  }

  Map<String, double> _getExpenseCategories() {
    final categories = <String, double>{};
    for (final expense in _expenses) {
      final category = expense.category;
      categories[category] = (categories[category] ?? 0) + expense.amount;
    }
    return categories;
  }

  // Removed monthly expense aggregation to avoid unused code and switch to daily trends

  List<Map<String, dynamic>> _getTopCustomers() {
    final customerSales = <String, double>{};
    for (final bill in _allBills) {
      final customer = bill.customerName;
      customerSales[customer] =
          (customerSales[customer] ?? 0) + (bill.total ?? 0);
    }

    final sortedCustomers = customerSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedCustomers
        .take(5)
        .map((e) => {'name': e.key, 'sales': e.value})
        .toList();
  }

  Map<String, int> _getPeopleByType() {
    final peopleByType = <String, int>{};
    for (final person in _peoples) {
      final category = person.category;
      peopleByType[category] = (peopleByType[category] ?? 0) + 1;
    }
    return peopleByType;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void sortTable(String column, bool ascending) {
    tableData.sort((a, b) {
      var aValue = a[column];
      var bValue = b[column];

      if (aValue is num && bValue is num) {
        return ascending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      }

      if (aValue is String && bValue is String) {
        return ascending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      }

      return 0;
    });
    notifyListeners();
  }

  void searchTable(String query) {
    if (query.isEmpty) {
      _generateTableData(); // Reset to original data
    } else {
      tableData = _allBills
          .where(
            (bill) =>
                bill.customerName.toLowerCase().contains(query.toLowerCase()) ||
                (bill.id ?? '').toLowerCase().contains(query.toLowerCase()) ||
                bill.paymentMethod.toLowerCase().contains(query.toLowerCase()),
          )
          .map((bill) {
            return {
              'date': DateFormat('yyyy-MM-dd').format(bill.date),
              'invoiceId': bill.id ?? '',
              'customer': bill.customerName,
              'amount': bill.total,
              'payment': bill.paymentMethod,
            };
          })
          .toList();
    }
    notifyListeners();
  }

  Future<void> refreshData() async {
    // Streams keep data fresh; only refresh heavy bill items in background
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('current_uid');
      if (uid != null && uid.isNotEmpty) {
        unawaited(_loadAllBillItemsInBackground(uid));
      }
    } catch (_) {}
  }

  void setChartType(String type) {
    selectedChartType = type;
    notifyListeners();
  }

  // Calculate the best day of sales based on total revenue
  Map<String, dynamic> _getBestDayOfSales() {
    if (_allBills.isEmpty) {
      return {'day': 'No Data', 'sales': 0.0, 'bills': 0};
    }

    final daySales = <String, Map<String, dynamic>>{};

    for (final bill in _allBills) {
      final dayName = DateFormat(
        'EEEE',
      ).format(bill.date); // Full day name (Monday, Tuesday, etc.)
      final dayKey = dayName.toLowerCase();

      if (!daySales.containsKey(dayKey)) {
        daySales[dayKey] = {'day': dayName, 'sales': 0.0, 'bills': 0};
      }

      daySales[dayKey]!['sales'] =
          (daySales[dayKey]!['sales'] as double) + (bill.total ?? 0);
      daySales[dayKey]!['bills'] = (daySales[dayKey]!['bills'] as int) + 1;
    }

    // Find the day with highest sales
    String bestDayKey = daySales.keys.first;
    double maxSales = daySales[bestDayKey]!['sales'] as double;

    for (final entry in daySales.entries) {
      if (entry.value['sales'] > maxSales) {
        maxSales = entry.value['sales'] as double;
        bestDayKey = entry.key;
      }
    }

    return daySales[bestDayKey]!;
  }

  // Calculate the peak hour of sales based on bill timestamps
  Map<String, dynamic> _getPeakHourOfSales() {
    if (_allBills.isEmpty) {
      return {'hour': 'No Data', 'sales': 0.0, 'bills': 0};
    }

    final hourSales = <int, Map<String, dynamic>>{};

    for (final bill in _allBills) {
      final hour = bill.date.hour;

      if (!hourSales.containsKey(hour)) {
        hourSales[hour] = {'hour': hour, 'sales': 0.0, 'bills': 0};
      }

      hourSales[hour]!['sales'] =
          (hourSales[hour]!['sales'] as double) + (bill.total ?? 0);
      hourSales[hour]!['bills'] = (hourSales[hour]!['bills'] as int) + 1;
    }

    // Find the hour with highest sales
    int peakHour = hourSales.keys.first;
    double maxSales = hourSales[peakHour]!['sales'] as double;

    for (final entry in hourSales.entries) {
      if (entry.value['sales'] > maxSales) {
        maxSales = entry.value['sales'] as double;
        peakHour = entry.key;
      }
    }

    // Format hour for display (e.g., 14 -> "2:00 PM")
    final hourDisplay = _formatHourForDisplay(peakHour);

    return {
      'hour': hourDisplay,
      'sales': hourSales[peakHour]!['sales'] as double,
      'bills': hourSales[peakHour]!['bills'] as int,
    };
  }

  // Format hour for display (24-hour to 12-hour format)
  String _formatHourForDisplay(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour == 12) return '12:00 PM';
    if (hour < 12) return '${hour}:00 AM';
    return '${hour - 12}:00 PM';
  }

  // Calculate average items per bill
  double _getAverageItemsPerBill() {
    if (_allBills.isEmpty) return 0.0;

    final totalItems = _allBillItems.length;
    return totalItems / _allBills.length;
  }

  @override
  @override
  void dispose() {
    _disposed = true;
    // Cancel stream subscriptions
    _billsSub?.cancel();
    _inventorySub?.cancel();
    _peopleSub?.cancel();
    _expensesSub?.cancel();
    if (refreshManager != null) {
      refreshManager!.removeListener(_onRefreshRequested);
      refreshManager = null;
    }
    super.dispose();
  }

  void safeNotifyListeners() {
    if (!_disposed) notifyListeners();
  }
}

class ReportScreen extends StatefulWidget {
  final String? selectedDetailedReport;
  const ReportScreen({super.key, this.selectedDetailedReport});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? selectedDetailedReport;
  RefreshManager? refreshManager;

  @override
  void initState() {
    super.initState();
    selectedDetailedReport = widget.selectedDetailedReport;

    // Set up refresh manager after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      refreshManager = Provider.of<RefreshManager>(context, listen: false);
      refreshManager!.addListener(_onRefreshRequested);
      Provider.of<ReportProvider>(
        context,
        listen: false,
      )!.setRefreshManager(refreshManager!);
    });
  }

  void _onRefreshRequested() {
    if (refreshManager != null && refreshManager!.shouldRefreshReports) {
      debugPrint('ReportScreen: Refresh requested, reloading data');
      setState(() {
        // Trigger rebuild of the screen
      });
      refreshManager!.clearReportsRefresh();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If navigated with arguments, use them
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['selectedDetailedReport'] is String) {
      setState(() {
        selectedDetailedReport = args['selectedDetailedReport'];
      });
    }
  }

  void _showDetailedReport(String type) {
    setState(() {
      selectedDetailedReport = type;
    });
  }

  void _hideDetailedReport() {
    setState(() {
      selectedDetailedReport = null;
    });
    // Check if user navigated from home screen with arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['selectedDetailedReport'] != null) {
      // User came from home screen, just pop back to home
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    if (refreshManager != null) {
      refreshManager!.removeListener(_onRefreshRequested);
    }
    // Do not manually dispose Provider.of<ReportProvider>(context, listen: false); ChangeNotifierProvider will handle it
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        if (selectedDetailedReport != null) {
          setState(() {
            selectedDetailedReport = null;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0A2342) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true,
          title: Text(
            'Reports',
            style: const TextStyle(
              fontSize: 22,
              color: Color(0xFF0A2342),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          actions: [
            // Export functionality can be added here
          ],
          iconTheme: const IconThemeData(color: Color(0xFF0A2342)),
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
        ),
        body: Stack(
          children: [
            _buildBody(context, isDark, colorScheme),
            if (selectedDetailedReport != null)
              Consumer<ReportProvider>(
                builder: (context, provider, _) {
                  final data = _getReportData(
                    selectedDetailedReport!,
                    provider,
                  );
                  final title = _getReportTitle(selectedDetailedReport!);

                  return DetailedReportContainer(
                    title: title,
                    type: selectedDetailedReport!,
                    data: data,
                    onClose: _hideDetailedReport,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        await Provider.of<ReportProvider>(context, listen: false).refreshData();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildKpiSection(context, isDark, colorScheme),
            const SizedBox(height: 32),
            _buildDetailedReportsSection(context, isDark, colorScheme),
            const SizedBox(height: 32),
            _buildChartSection(context, isDark, colorScheme),
            const SizedBox(height: 32),
            _buildTableSection(context, isDark, colorScheme),
            const SizedBox(height: 16),
            _buildFooter(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiSection(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Performance Indicators',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Consumer<ReportProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return Column(
                children: [
                  Row(
                    children: [
                      const Expanded(child: KpiShimmer()),
                      const SizedBox(width: 16),
                      const Expanded(child: KpiShimmer()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: KpiShimmer()),
                      const SizedBox(width: 16),
                      const Expanded(child: KpiShimmer()),
                    ],
                  ),
                ],
              );
            }

            if (provider.hasError) {
              return _buildErrorCard(context, provider.errorMessage, isDark);
            }

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: KpiCard(
                        title: 'Total Sales',
                        value:
                            'Rs ${formatIndianAmount(double.tryParse(provider.totalSales.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0)}',
                        icon: Icons.shopping_cart_rounded,
                        percentChange: provider.salesChange,
                        isUp: provider.salesChange >= 0,
                        color: const Color(0xFF1976D2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: KpiCard(
                        title: 'Purchase',
                        value:
                            'Rs ${formatIndianAmount((provider.purchaseSummary['totalPurchase'] as double?) ?? 0)}',
                        icon: Icons.inventory_rounded,
                        percentChange:
                            0, // You can add logic for purchase change
                        isUp: true,
                        color: const Color(0xFF128C7E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: KpiCard(
                        title: 'Expense',
                        value:
                            'Rs ${formatIndianAmount(double.tryParse(provider.expense.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0)}',
                        icon: Icons.credit_card_rounded,
                        percentChange: provider.expenseChange,
                        isUp: provider.expenseChange >= 0,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: KpiCard(
                        title: 'Profit',
                        value:
                            'Rs ${formatIndianAmount(double.tryParse(provider.profit.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0)}',
                        icon: Icons.trending_up_rounded,
                        percentChange: provider.profitChange,
                        isUp: provider.profitChange >= 0,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDetailedReportsSection(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detailed Reports',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        _buildReportCard(
          context,
          isDark,
          icon: Icons.bar_chart_rounded,
          title: 'Sales Report',
          type: 'sales',
          color: const Color(0xFF1976D2),
        ),
        const SizedBox(height: 16),
        _buildReportCard(
          context,
          isDark,
          icon: Icons.inventory_rounded,
          title: 'Purchase Report',
          type: 'purchase',
          color: const Color(0xFF128C7E),
        ),
        const SizedBox(height: 16),
        _buildReportCard(
          context,
          isDark,
          icon: Icons.credit_card_rounded,
          title: 'Expense Report',
          type: 'expense',
          color: const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 16),
        _buildReportCard(
          context,
          isDark,
          icon: Icons.people_rounded,
          title: 'People Report',
          type: 'people',
          color: const Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String title,
    required String type,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => _showDetailedReport(type),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF013A63) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(20),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withAlpha(45), width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: isDark ? Colors.white : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sales vs Purchase Comparison',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 20),
        Consumer<ReportProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load chart data',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }
            return ComparisonChartWidget(
              salesData: provider.salesChartData,
              purchaseData: provider.purchaseChartData,
              labels: _getLast7DaysLabels(), // Use new helper for Mon, Tue, ...
              salesColor: Color(0xFF1976D2),
              purchaseColor: Color(0xFF128C7E),
              showZoomControlsBelow: true,
            );
          },
        ),
      ],
    );
  }

  Widget _buildTableSection(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Transactions',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            // Remove all PopupMenuButton, export icons, and export logic from the report screen UI.
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF013A63) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Consumer<ReportProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (provider.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load table data',
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return DataTableWidget(
                data: provider.tableData,
                onSort: provider.sortTable,
                onSearch: provider.searchTable,
                exportButton:
                    Container(), // Placeholder since export is now handled in DataTableWidget
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Last updated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
        ),
        Consumer<ReportProvider>(
          builder: (context, provider, _) {
            return Container();
          },
        ),
      ],
    );
  }

  Widget _buildErrorCard(BuildContext context, String message, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 32,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.poppins(
              color: Colors.red.shade600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              final provider = Provider.of<ReportProvider>(
                context,
                listen: false,
              );
              provider.refreshData();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getReportData(String type, ReportProvider provider) {
    switch (type) {
      case 'sales':
        return provider.salesSummary;
      case 'purchase':
        return provider.purchaseSummary;
      case 'expense':
        return provider.expenseSummary;
      case 'people':
        return provider.peopleSummary;
      default:
        return {};
    }
  }

  String _getReportTitle(String type) {
    switch (type) {
      case 'sales':
        return 'Sales Report';
      case 'purchase':
        return 'Purchase Report';
      case 'expense':
        return 'Expense Report';
      case 'people':
        return 'People Report';
      default:
        return 'Report';
    }
  }
}

// Add helper for last 7 days as Mon, Tue, ...
List<String> _getLast7DaysLabels() {
  final now = DateTime.now();
  final days = <String>[];
  for (int i = 6; i >= 0; i--) {
    final date = now.subtract(Duration(days: i));
    days.add(DateFormat('E').format(date)); // Mon, Tue, etc.
  }
  return days;
}

String formatIndianAmount(num amount) {
  if (amount.abs() >= 10000000) {
    return '${(amount / 10000000).toStringAsFixed(2)} Cr';
  } else if (amount.abs() >= 100000) {
    return '${(amount / 100000).toStringAsFixed(2)} Lakh';
  } else {
    final formatter = NumberFormat('#,##,##0.##');
    return formatter.format(amount);
  }
}

Future<void> _exportToExcel(BuildContext context) async {
  try {
    final provider = Provider.of<ReportProvider>(context, listen: false);
    final tableData = provider.tableData;
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    if (tableData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No data to export.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // Add headers
    final headers = tableData.first.keys.toList();
    for (int i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
    }
    // Add data
    for (int row = 0; row < tableData.length; row++) {
      final dataRow = tableData[row];
      for (int col = 0; col < headers.length; col++) {
        sheet
            .getRangeByIndex(row + 2, col + 1)
            .setText('${dataRow[headers[col]] ?? ''}');
      }
    }
    final bytes = workbook.saveAsStream();
    workbook.dispose();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/report.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    if (!await file.exists() || await file.length() == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create Excel file.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Exported Report (Excel)');
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
    );
  }
}

Future<void> _exportToWord(BuildContext context) async {
  try {
    final provider = Provider.of<ReportProvider>(context, listen: false);
    final tableData = provider.tableData;
    if (tableData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No data to export.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final headers = tableData.first.keys.toList();
    final buffer = StringBuffer();
    buffer.writeln(headers.join('\t'));
    for (final row in tableData) {
      buffer.writeln(headers.map((h) => row[h]).join('\t'));
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/report.doc');
    await file.writeAsString(buffer.toString());
    if (!await file.exists() || await file.length() == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create Word file.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    await Share.shareXFiles([XFile(file.path)], text: 'Exported Report (Word)');
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
    );
  }
}

// Helper functions for report data
Map<String, dynamic> _getReportData(String type, ReportProvider provider) {
  switch (type) {
    case 'sales':
      return provider.salesSummary;
    case 'purchase':
      return provider.purchaseSummary;
    case 'expense':
      return provider.expenseSummary;
    case 'people':
      return provider.peopleSummary;
    default:
      return {};
  }
}

String _getReportTitle(String type) {
  switch (type) {
    case 'sales':
      return 'Sales Report';
    case 'purchase':
      return 'Purchase Report';
    case 'expense':
      return 'Expense Report';
    case 'people':
      return 'People Report';
    default:
      return 'Report';
  }
}
