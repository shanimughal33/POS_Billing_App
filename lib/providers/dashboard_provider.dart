import 'dart:async';
import 'package:flutter/foundation.dart';
import '../repositories/bill_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/people_repository.dart';
import '../repositories/expense_repository.dart';
import '../models/bill.dart';
import '../models/inventory_item.dart';
import '../models/people.dart';
import '../models/expense.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

export 'dashboard_provider.dart';

class DashboardProvider with ChangeNotifier {
  final BillRepository billRepo;
  final InventoryRepository inventoryRepo;
  final PeopleRepository peopleRepo;
  final ExpenseRepository expenseRepo;

  String? userId;

  // Dashboard data
  List<Bill> bills = [];
  List<InventoryItem> inventory = [];
  List<People> people = [];
  List<Expense> expenses = [];

  // Dashboard stats
  double totalSales = 0.0;
  double totalExpense = 0.0;
  double totalPurchase = 0.0;
  int customerCount = 0;
  int supplierCount = 0;
  int productCount = 0;

  // Chart data
  List<FlSpot> salesChartData = [];
  List<FlSpot> purchaseChartData = [];
  List<String> chartLabels = [];

  // Loading/error state
  bool isLoading = true;
  String? errorMessage;

  // Stream subscriptions
  StreamSubscription? _billsSub;
  StreamSubscription? _inventorySub;
  StreamSubscription? _peopleSub;
  StreamSubscription? _expensesSub;

  DashboardProvider({
    required this.billRepo,
    required this.inventoryRepo,
    required this.peopleRepo,
    required this.expenseRepo,
    required this.userId,
  }) {
    _listenToRepositories();
  }

  void _listenToRepositories() {
    _billsSub?.cancel();
    _inventorySub?.cancel();
    _peopleSub?.cancel();
    _expensesSub?.cancel();
    if (userId == null) {
      // Clear all cached data when there is no user
      bills = [];
      inventory = [];
      people = [];
      expenses = [];
      _computeStats();
      isLoading = false;
      notifyListeners();
      return;
    }
    isLoading = true;
    notifyListeners();
    _billsSub = billRepo.streamBills(userId!).listen((data) {
      bills = data;
      _computeStats();
      notifyListeners();
    });
    _inventorySub = inventoryRepo.streamItems(userId!).listen((data) {
      inventory = data;
      _computeStats();
      notifyListeners();
    });
    _peopleSub = peopleRepo.getPeopleStream(userId!).listen((data) {
      people = data;
      _computeStats();
      notifyListeners();
    });
    _expensesSub = expenseRepo.streamExpenses(userId!).listen((data) {
      expenses = data;
      _computeStats();
      notifyListeners();
    });
  }

  /// Switch the active user and refresh all live streams
  void setUser(String? uid) {
    if (userId == uid) return;
    userId = uid;
    // Cancel existing listeners and clear cached data immediately to avoid showing stale info
    _billsSub?.cancel();
    _inventorySub?.cancel();
    _peopleSub?.cancel();
    _expensesSub?.cancel();
    bills = [];
    inventory = [];
    people = [];
    expenses = [];
    _computeStats();
    isLoading = true;
    notifyListeners();
    _listenToRepositories();
  }

  void _computeStats() {
    // Totals
    totalSales = bills.fold(0.0, (sum, bill) => sum + (bill.total ?? 0.0));
    totalExpense = expenses.fold(0.0, (sum, exp) => sum + (exp.amount));
    totalPurchase = inventory.fold(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );
    customerCount = people.where((p) => p.category == 'customer').length;
    supplierCount = people.where((p) => p.category == 'supplier').length;
    productCount = inventory.length;
    // Chart data (last 7 days)
    _generateChartData();
  }

  void _generateChartData() {
    salesChartData.clear();
    purchaseChartData.clear();
    chartLabels.clear();
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      chartLabels.add(DateFormat('E').format(date));
      final daySales = bills
          .where((b) => _isSameDay(b.date, date))
          .fold(0.0, (sum, b) => sum + (b.total ?? 0.0));
      salesChartData.add(FlSpot((6 - i).toDouble(), daySales));
      final dayPurchase = inventory
          .where((item) => _isSameDay(item.createdAt, date))
          .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
      purchaseChartData.add(FlSpot((6 - i).toDouble(), dayPurchase));
    }
  }

  bool _isSameDay(DateTime? d1, DateTime d2) {
    if (d1 == null) return false;
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  List<Bill> get allBills => bills;
  List<InventoryItem> get allInventory => inventory;
  List<People> get allPeople => people;
  List<Expense> get allExpenses => expenses;

  Future<void> deleteBill(Bill bill) async {
    if (userId == null || bill.id == null) return;
    try {
      await billRepo.softDeleteBill(userId!, bill.id!);
      // The stream listener will automatically update the UI.
    } catch (e) {
      errorMessage = 'Failed to delete bill: $e';
      notifyListeners();
    }
  }

  // For HomeScreen: expose chart data by filter
  List<FlSpot> getSalesData(String filter) {
    if (filter == 'daily') return salesChartData;
    if (filter == 'weekly') {
      // Aggregate by week (last 4 weeks)
      List<FlSpot> weekly = [];
      final now = DateTime.now();
      for (int i = 3; i >= 0; i--) {
        final weekStart = now.subtract(Duration(days: (i + 1) * 7));
        final weekEnd = now.subtract(Duration(days: i * 7));
        double weekTotal = bills
            .where(
              (b) =>
                  b.date != null &&
                  b.date!.isAfter(weekStart) &&
                  b.date!.isBefore(weekEnd),
            )
            .fold(0.0, (sum, b) => sum + (b.total ?? 0.0));
        weekly.add(FlSpot((3 - i).toDouble(), weekTotal));
      }
      return weekly;
    }
    // monthly (last 6 months)
    List<FlSpot> monthly = [];
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      double monthTotal = bills
          .where(
            (b) =>
                b.date != null &&
                b.date!.year == month.year &&
                b.date!.month == month.month,
          )
          .fold(0.0, (sum, b) => sum + (b.total ?? 0.0));
      monthly.add(FlSpot((5 - i).toDouble(), monthTotal));
    }
    return monthly;
  }

  List<FlSpot> getPurchaseData(String filter) {
    if (filter == 'daily') return purchaseChartData;
    if (filter == 'weekly') {
      List<FlSpot> weekly = [];
      final now = DateTime.now();
      for (int i = 3; i >= 0; i--) {
        final weekStart = now.subtract(Duration(days: (i + 1) * 7));
        final weekEnd = now.subtract(Duration(days: i * 7));
        double weekTotal = inventory
            .where(
              (item) =>
                  item.createdAt != null &&
                  item.createdAt!.isAfter(weekStart) &&
                  item.createdAt!.isBefore(weekEnd),
            )
            .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
        weekly.add(FlSpot((3 - i).toDouble(), weekTotal));
      }
      return weekly;
    }
    // monthly (last 6 months)
    List<FlSpot> monthly = [];
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      double monthTotal = inventory
          .where(
            (item) =>
                item.createdAt != null &&
                item.createdAt!.year == month.year &&
                item.createdAt!.month == month.month,
          )
          .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
      monthly.add(FlSpot((5 - i).toDouble(), monthTotal));
    }
    return monthly;
  }

  @override
  void dispose() {
    _billsSub?.cancel();
    _inventorySub?.cancel();
    _peopleSub?.cancel();
    _expensesSub?.cancel();
    super.dispose();
  }
}
