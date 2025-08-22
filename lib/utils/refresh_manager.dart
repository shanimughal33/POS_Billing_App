import 'package:flutter/foundation.dart';

/// Global refresh manager to handle real-time updates across all screens
class RefreshManager extends ChangeNotifier {
  static final RefreshManager _instance = RefreshManager._internal();
  factory RefreshManager() => _instance;
  RefreshManager._internal();

  // Refresh flags for different data types
  bool _shouldRefreshSales = false;
  bool _shouldRefreshInventory = false;
  bool _shouldRefreshExpenses = false;
  bool _shouldRefreshPeople = false;
  bool _shouldRefreshDashboard = false;
  bool _shouldRefreshReports = false;

  // Getters
  bool get shouldRefreshSales => _shouldRefreshSales;
  bool get shouldRefreshInventory => _shouldRefreshInventory;
  bool get shouldRefreshExpenses => _shouldRefreshExpenses;
  bool get shouldRefreshPeople => _shouldRefreshPeople;
  bool get shouldRefreshDashboard => _shouldRefreshDashboard;
  bool get shouldRefreshReports => _shouldRefreshReports;

  // Methods to trigger refreshes
  void refreshSales() {
    _shouldRefreshSales = true;
    _shouldRefreshDashboard = true;
    _shouldRefreshReports = true;
    debugPrint('RefreshManager: Sales refresh triggered - Sales: $_shouldRefreshSales, Dashboard: $_shouldRefreshDashboard, Reports: $_shouldRefreshReports');
    notifyListeners();
  }

  void refreshInventory() {
    _shouldRefreshInventory = true;
    _shouldRefreshDashboard = true;
    _shouldRefreshReports = true;
    debugPrint('RefreshManager: Inventory refresh triggered - Inventory: $_shouldRefreshInventory, Dashboard: $_shouldRefreshDashboard, Reports: $_shouldRefreshReports');
    notifyListeners();
  }

  void refreshExpenses() {
    _shouldRefreshExpenses = true;
    _shouldRefreshDashboard = true;
    _shouldRefreshReports = true;
    debugPrint('RefreshManager: Expenses refresh triggered - Expenses: $_shouldRefreshExpenses, Dashboard: $_shouldRefreshDashboard, Reports: $_shouldRefreshReports');
    notifyListeners();
  }

  void refreshPeople() {
    _shouldRefreshPeople = true;
    _shouldRefreshDashboard = true;
    _shouldRefreshReports = true;
    debugPrint('RefreshManager: People refresh triggered - People: $_shouldRefreshPeople, Dashboard: $_shouldRefreshDashboard, Reports: $_shouldRefreshReports');
    notifyListeners();
  }

  void refreshDashboard() {
    _shouldRefreshDashboard = true;
    notifyListeners();
    debugPrint('RefreshManager: Dashboard refresh triggered');
  }

  void refreshReports() {
    _shouldRefreshReports = true;
    notifyListeners();
    debugPrint('RefreshManager: Reports refresh triggered');
  }

  // Method to refresh all data
  void refreshAll() {
    _shouldRefreshSales = true;
    _shouldRefreshInventory = true;
    _shouldRefreshExpenses = true;
    _shouldRefreshPeople = true;
    _shouldRefreshDashboard = true;
    _shouldRefreshReports = true;
    notifyListeners();
    debugPrint('RefreshManager: All data refresh triggered');
  }

  // Method to clear refresh flags after processing
  void clearSalesRefresh() {
    _shouldRefreshSales = false;
  }

  void clearInventoryRefresh() {
    _shouldRefreshInventory = false;
  }

  void clearExpensesRefresh() {
    _shouldRefreshExpenses = false;
  }

  void clearPeopleRefresh() {
    _shouldRefreshPeople = false;
  }

  void clearDashboardRefresh() {
    _shouldRefreshDashboard = false;
  }

  void clearReportsRefresh() {
    _shouldRefreshReports = false;
  }

  void clearAllRefreshFlags() {
    _shouldRefreshSales = false;
    _shouldRefreshInventory = false;
    _shouldRefreshExpenses = false;
    _shouldRefreshPeople = false;
    _shouldRefreshDashboard = false;
    _shouldRefreshReports = false;
  }
} 