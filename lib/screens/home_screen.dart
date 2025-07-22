import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forward_billing_app/repositories/bill_repository.dart';
import 'package:forward_billing_app/repositories/people_repository.dart';
import 'package:forward_billing_app/repositories/inventory_repository.dart';
import 'package:forward_billing_app/repositories/expense_repository.dart';
import 'package:intl/intl.dart';
import 'widgets/chart_comparison.dart';
import '../models/people.dart';
import 'inventory_screen.dart';
import 'sales_screen.dart';
import 'purchase_screen.dart';
import 'expense_screen.dart';
import 'report_screen.dart';
import 'calculator.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'peoples_screen.dart';
import '../models/bill.dart';
import '../models/inventory_item.dart';
import 'settings_screen.dart';
import '../models/activity.dart';
import '../repositories/activity_repository.dart';

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

class DashboardProvider with ChangeNotifier {
  final BillRepository _billRepo = BillRepository();
  final InventoryRepository _inventoryRepo = InventoryRepository();
  final PeopleRepository _peopleRepo = PeopleRepository();
  final ExpenseRepository _expenseRepo = ExpenseRepository();

  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  // KPIs
  double totalSales = 0;
  double totalPurchase = 0;
  double totalExpense = 0;
  double totalProfit = 0;

  // Chart data
  List<FlSpot> salesChartData = [];
  List<FlSpot> purchaseChartData = [];
  List<String> comparisonChartLabels = [];

  // For stat cards
  int customerCount = 0;
  int productCount = 0;

  // Recent transactions
  List<Map<String, dynamic>> recentTransactions = [];

  // Expose all loaded bills and inventory for use in UI
  List<Bill> allBills = [];
  List<InventoryItem> allInventory = [];

  DashboardProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      isLoading = true;
      hasError = false;
      errorMessage = '';
      notifyListeners();

      final bills = await _billRepo.getAllBills();
      final inventory = await _inventoryRepo.getAllItems();
      final expenses = await _expenseRepo.getAllExpenses();
      final people = await _peopleRepo.getAllPeople();

      // Store for UI use
      allBills = bills;
      allInventory = inventory;

      // KPIs
      totalSales = bills.fold(0.0, (sum, bill) => sum + (bill.total ?? 0));
      totalPurchase = inventory.fold(
        0.0,
        (sum, item) => sum + (item.price * item.quantity),
      );
      totalExpense = expenses.fold(0.0, (sum, exp) => sum + exp.amount);
      totalProfit = totalSales - totalExpense;
      customerCount = people.where((p) => p.category == 'customer').length;
      productCount = inventory.length;

      // Chart data (last 7 days)
      salesChartData = [];
      purchaseChartData = [];
      comparisonChartLabels = [];
      final now = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final daySales = bills
            .where((bill) => _isSameDay(bill.date, date))
            .fold(0.0, (sum, bill) => sum + (bill.total ?? 0));
        salesChartData.add(FlSpot((6 - i).toDouble(), daySales));
        final dayPurchase = inventory
            .where((item) => _isSameDay(item.createdAt ?? DateTime.now(), date))
            .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
        purchaseChartData.add(FlSpot((6 - i).toDouble(), dayPurchase));
        comparisonChartLabels.add('${date.month}/${date.day}');
      }

      // Recent transactions (last 5 bills)
      final recentTxns = bills.where((b) => b.isDeleted != true).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      recentTransactions = recentTxns
          .take(5)
          .map(
            (b) => {
              "name": b.items.isNotEmpty ? b.items.first.name : "Unknown",
              "date": DateFormat('dd MMM yyyy').format(b.date),
              "status": "Fulfilled",
              "txn": "# 24{b.id ?? ''}",
              "image":
                  "assets/product_placeholder.png", // Replace with real image if available
            },
          )
          .toList();

      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to load dashboard data.';
      hasError = true;
      isLoading = false;
      notifyListeners();
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> refreshData() async {
    await _loadData();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Repositories for real-time data
  final BillRepository _billRepo = BillRepository();
  final PeopleRepository _peopleRepo = PeopleRepository();
  final InventoryRepository _inventoryRepo = InventoryRepository();
  final ExpenseRepository _expenseRepo = ExpenseRepository();

  // Dashboard data
  double _totalBalance = 0;
  int _customerCount = 0;
  int _productCount = 0;
  double _revenue = 0;
  double _expense = 0;
  // REMOVE: List<Map<String, dynamic>> _recentTransactions = [];
  bool _loading = true;
  List<People> _allPeople = [];

  // Add filter state
  String _graphFilter = 'daily'; // 'daily', 'weekly', 'monthly'

  // Helper for x-axis labels based on filter
  List<String> _getGraphLabels() {
    final now = DateTime.now();
    if (_graphFilter == 'daily') {
      return List.generate(
        7,
        (i) => DateFormat('E').format(now.subtract(Duration(days: 6 - i))),
      );
    } else if (_graphFilter == 'weekly') {
      return List.generate(4, (i) {
        final weekStart = now.subtract(Duration(days: (3 - i) * 7));
        return 'Wk ${DateFormat('d MMM').format(weekStart)}';
      });
    } else {
      // monthly
      return List.generate(6, (i) {
        final month = DateTime(now.year, now.month - 5 + i, 1);
        return DateFormat('MMM').format(month);
      });
    }
  }

  // Helper for graph data based on filter
  List<FlSpot> _getSalesData(DashboardProvider provider) {
    if (_graphFilter == 'daily') {
      return provider.salesChartData;
    } else if (_graphFilter == 'weekly') {
      // Aggregate by week (last 4 weeks)
      final now = DateTime.now();
      List<double> weeklyTotals = List.filled(4, 0);
      for (final bill in provider.allBills) {
        for (int w = 0; w < 4; w++) {
          final weekStart = now.subtract(Duration(days: (3 - w) * 7));
          final weekEnd = weekStart.add(const Duration(days: 6));
          if (bill.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
              bill.date.isBefore(weekEnd.add(const Duration(days: 1)))) {
            weeklyTotals[w] += bill.total ?? 0;
          }
        }
      }
      return List.generate(4, (i) => FlSpot(i.toDouble(), weeklyTotals[i]));
    } else {
      // monthly (last 6 months)
      final now = DateTime.now();
      List<double> monthlyTotals = List.filled(6, 0);
      for (final bill in provider.allBills) {
        for (int m = 0; m < 6; m++) {
          final month = DateTime(now.year, now.month - 5 + m, 1);
          if (bill.date.year == month.year && bill.date.month == month.month) {
            monthlyTotals[m] += bill.total ?? 0;
          }
        }
      }
      return List.generate(6, (i) => FlSpot(i.toDouble(), monthlyTotals[i]));
    }
  }

  List<FlSpot> _getPurchaseData(DashboardProvider provider) {
    if (_graphFilter == 'daily') {
      return provider.purchaseChartData;
    } else if (_graphFilter == 'weekly') {
      // Aggregate by week (last 4 weeks)
      final now = DateTime.now();
      List<double> weeklyTotals = List.filled(4, 0);
      for (final item in provider.allInventory) {
        for (int w = 0; w < 4; w++) {
          final weekStart = now.subtract(Duration(days: (3 - w) * 7));
          final weekEnd = weekStart.add(const Duration(days: 6));
          if ((item.createdAt ?? now).isAfter(
                weekStart.subtract(const Duration(days: 1)),
              ) &&
              (item.createdAt ?? now).isBefore(
                weekEnd.add(const Duration(days: 1)),
              )) {
            weeklyTotals[w] += item.price * item.quantity;
          }
        }
      }
      return List.generate(4, (i) => FlSpot(i.toDouble(), weeklyTotals[i]));
    } else {
      // monthly (last 6 months)
      final now = DateTime.now();
      List<double> monthlyTotals = List.filled(6, 0);
      for (final item in provider.allInventory) {
        for (int m = 0; m < 6; m++) {
          final month = DateTime(now.year, now.month - 5 + m, 1);
          final createdAt = item.createdAt ?? now;
          if (createdAt.year == month.year && createdAt.month == month.month) {
            monthlyTotals[m] += item.price * item.quantity;
          }
        }
      }
      return List.generate(6, (i) => FlSpot(i.toDouble(), monthlyTotals[i]));
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchAllPeople();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Optionally refresh people when dependencies change (e.g., after navigation)
    _fetchAllPeople();
  }

  Future<void> _fetchAllPeople() async {
    final people = await _peopleRepo.getAllPeople();
    setState(() {
      _allPeople = people;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentGreen = const Color(0xFF128C7E);
    final darkBlue = const Color(0xFF0A2342);
    final blueGradient = const LinearGradient(
      colors: [
        Color(0xFF0A2342), // deep navy blue
        Color(0xFF123060), // dark blue
        Color(0xFF1976D2), // vibrant blue
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final userName = "Ehtisham"; // Replace with real user name if available
    final notificationCount = 3; // Replace with real notification count

    return ChangeNotifierProvider(
      create: (_) => DashboardProvider(),
      child: Consumer<DashboardProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (provider.hasError) {
            return Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Text(
                  'Error: ',
                  style: TextStyle(color: Color(0xFF0A2342)),
                ),
              ),
            );
          }
          return Scaffold(
            backgroundColor: Colors.white,
            extendBody: true,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(70),
              child: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                centerTitle: false,
                title: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: blueGradient,
                      ),
                      child: const Icon(
                        Icons.dashboard,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      "Dashboard",
                      style: GoogleFonts.poppins(
                        color: darkBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                actions: [
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.notifications_none,
                          color: darkBlue,
                          size: 28,
                        ),
                        onPressed: () {},
                      ),
                      if (notificationCount > 0)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$notificationCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
              ),
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                final provider = Provider.of<DashboardProvider>(
                  context,
                  listen: false,
                );
                await provider.refreshData();
                // Optionally refresh people as well
                await _fetchAllPeople();
              },
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment:
                                CrossAxisAlignment.center, // align with icon
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "WELCOME",
                                        style: GoogleFonts.montserrat(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey[600],
                                          letterSpacing: 2.2,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '👋',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    userName,
                                    style: GoogleFonts.urbanist(
                                      fontSize: 24, // reduced from 30
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF1976D2),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              // Account icon (blue, vertically centered)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.search_rounded,
                                      color: Color(0xFF1976D2),
                                      size: 24,
                                    ),
                                    onPressed: () {
                                      // Search action (implement if needed)
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.account_circle_rounded,
                                      color: Color(0xFF1976D2),
                                      size: 28,
                                    ),
                                    onPressed: () {
                                      // Account action
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Total Balance Card (use dark blue gradient)
                        Container(
                          decoration: BoxDecoration(
                            gradient:
                                blueGradient, // Use the dark blue gradient
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                            backgroundBlendMode: BlendMode.srcOver,
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.account_balance_wallet,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Total Balance",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white70,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Rs ' +
                                          formatIndianAmount(
                                            provider.totalProfit,
                                          ),
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "See details",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Stat Cards Grid (revert to original white card style)
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.2,
                          children: [
                            // Row 1: Sales, Purchase
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/reports',
                                  arguments: {
                                    'selectedDetailedReport': 'sales',
                                  },
                                );
                              },
                              child: _statCard(
                                Icons.shopping_cart_rounded,
                                "Sales",
                                provider.totalSales,
                                0.0,
                                Colors.white,
                                gradient: null,
                                textColor: Colors.black,
                                iconColor: Color(0xFF1976D2),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/reports',
                                  arguments: {
                                    'selectedDetailedReport': 'purchase',
                                  },
                                );
                              },
                              child: _statCard(
                                Icons.inventory_2,
                                "Purchase",
                                provider.totalPurchase,
                                0.0,
                                Colors.white,
                                gradient: null,
                                textColor: Colors.black,
                                iconColor: Color(0xFF128C7E),
                              ),
                            ),
                            // Row 2: People, Expense
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/reports',
                                  arguments: {
                                    'selectedDetailedReport': 'people',
                                  },
                                );
                              },
                              child: _statCard(
                                Icons.people_rounded,
                                "People",
                                provider.customerCount,
                                0.0,
                                Colors.white,
                                gradient: null,
                                textColor: Colors.black,
                                iconColor: Colors.blue,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/reports',
                                  arguments: {
                                    'selectedDetailedReport': 'expense',
                                  },
                                );
                              },
                              child: _statCard(
                                Icons.money_off,
                                "Expense",
                                provider.totalExpense,
                                0.0,
                                Colors.white,
                                gradient: null,
                                textColor: Colors.black,
                                iconColor: Colors.red,
                              ),
                            ),
                            // Row 3: Profit
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/reports');
                              },
                              child: _statCard(
                                Icons.trending_up_rounded,
                                "Profit",
                                provider.totalSales - provider.totalExpense,
                                0.0,
                                Colors.white,
                                gradient: null,
                                textColor: Colors.black,
                                iconColor: Color(0xFF10B981),
                              ),
                            ),
                            // Row 4: Inventory
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/reports',
                                  arguments: {
                                    'selectedDetailedReport': 'purchase',
                                  },
                                );
                              },
                              child: _statCard(
                                Icons.store_rounded,
                                "Inventory",
                                provider.allInventory.length,
                                0.0,
                                Colors.white,
                                gradient: null,
                                textColor: Colors.black,
                                iconColor: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                        // No extra spacing here

                        // Reduce spacing between recent people avatars and menu grid
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                            horizontal: 8,
                          ),
                          child: _menuGrid(context),
                        ),
                        const SizedBox(height: 24),

                        // Sales vs Purchase Comparison Chart
                        Text(
                          "Sales vs Purchase Comparison",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Add filter bar above and outside the graph container
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildGraphFilterButton('daily', 'Daily'),
                              const SizedBox(width: 6),
                              _buildGraphFilterButton('weekly', 'Weekly'),
                              const SizedBox(width: 6),
                              _buildGraphFilterButton('monthly', 'Monthly'),
                            ],
                          ),
                        ),
                        // Graph container: increase width, reduce horizontal margin/padding, reduce height
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 2,
                          ), // Reduced margin
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFF8FBFF), Color(0xFFEAF1FB)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ), // Reduced padding
                          width:
                              MediaQuery.of(context).size.width -
                              8, // Wider graph
                          height: 260, // Slightly reduced height
                          child: ComparisonChartWidget(
                            salesData: _getSalesData(provider),
                            purchaseData: _getPurchaseData(provider),
                            labels: _getGraphLabels(),
                            salesColor: Color(0xFF1976D2),
                            purchaseColor: Color(0xFF128C7E),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Add Top 5 Sales section
                        Text(
                          "Recent Activity",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FutureBuilder<List<Activity>>(
                          future: ActivityRepository().getRecentActivities(
                            limit: 30,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Center(
                                child: Text(
                                  'No recent activity',
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                              );
                            }
                            final activities = snapshot.data!;
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: activities.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, idx) {
                                final act = activities[idx];
                                final icon = getActivityIcon(
                                  act.type,
                                  act.metadata,
                                );
                                Color color = const Color(
                                  0xFF1976D2,
                                ); // Always blue for all activity types
                                switch (act.type) {
                                  case 'sale':
                                    color = Colors.blue;
                                    break;
                                  case 'purchase':
                                    color = Colors.green;
                                    break;
                                  case 'people_add':
                                    color = Colors.teal;
                                    break;
                                  case 'people_edit':
                                    color = Colors.orange;
                                    break;
                                  case 'people_delete':
                                    color = Colors.red;
                                    break;
                                  case 'expense_add':
                                    color = Colors.redAccent;
                                    break;
                                  case 'expense_edit':
                                    color = Colors.orange;
                                    break;
                                  case 'expense_delete':
                                    color = Colors.red;
                                    break;
                                  default:
                                    color = Colors.grey;
                                }
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(0.07),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    border: Border(
                                      left: BorderSide(color: color, width: 4),
                                    ),
                                    color: Colors.white,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Icon
                                        Container(
                                          width: 36,
                                          height: 36,
                                          margin: const EdgeInsets.only(
                                            right: 10,
                                            top: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFF1976D2),
                                                Color(0xFF42A5F5),
                                              ], // blue for sales
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.10,
                                                ),
                                                blurRadius: 6,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            icon,
                                            color:
                                                Colors.white, // Set icon color
                                            size: 18,
                                          ),
                                        ),
                                        // Main content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // First row: Activity type (bold) and date/time (right)
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      _getActivityTypeLabel(
                                                        act.type,
                                                      ),
                                                      style: GoogleFonts.poppins(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13.5,
                                                        color:
                                                            _getActivityTextColor(
                                                              act.type,
                                                            ),
                                                        letterSpacing: 0.2,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Text(
                                                    DateFormat(
                                                      'dd MMM, hh:mm a',
                                                    ).format(act.timestamp),
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              // Second row: Description (left) and Amount (right, if present)
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      act.description,
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontSize: 12.5,
                                                            color: const Color(
                                                              0xFF1976D2,
                                                            ),
                                                          ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (act.metadata != null &&
                                                      act.metadata!['amount'] !=
                                                          null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            left: 8,
                                                          ),
                                                      child: Text(
                                                        'Rs ${act.metadata!['amount']}',
                                                        style: GoogleFonts.poppins(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12.5,
                                                          color:
                                                              _getActivityTextColor(
                                                                act.type,
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
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        // Add extra space so nothing is hidden behind the BottomAppBar
                        const SizedBox(height: 80),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: SizedBox(
              height: 48,
              width: 48,
              child: FloatingActionButton(
                backgroundColor: const Color(0xFF1976D2),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.calculate,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () async {
                  await Navigator.pushNamed(context, '/calculator');
                },
              ),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            bottomNavigationBar: _modernBottomAppBar(),
          );
        },
      ),
    );
  }

  // Stat card widget
  Widget _statCard(
    IconData icon,
    String label,
    num value,
    double change,
    Color color, {
    Gradient? gradient,
    Color textColor = Colors.black,
    Color iconColor = Colors.blue,
  }) {
    final isUp = change >= 0;
    return Container(
      constraints: const BoxConstraints(
        minWidth: 120,
        maxWidth: 180,
        minHeight: 56,
        maxHeight: 70,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.13),
            child: Icon(icon, color: iconColor, size: 20),
            radius: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: textColor.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value.toString(),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isUp ? Icons.arrow_upward : Icons.arrow_downward,
                color: isUp ? Colors.greenAccent : Colors.redAccent,
                size: 14,
              ),
              Text(
                "${(change.abs() * 100).toStringAsFixed(0)}%",
                style: GoogleFonts.poppins(
                  color: isUp ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Transaction tile widget
  Widget _transactionTile(Map txn) {
    // Determine icon and color based on transaction type or status
    IconData icon = Icons.receipt_long;
    Color iconColor = const Color(0xFF1976D2); // blue
    if ((txn["status"] ?? '').toLowerCase().contains('purchase')) {
      icon = Icons.shopping_cart;
      iconColor = Colors.green;
    } else if ((txn["status"] ?? '').toLowerCase().contains('expense')) {
      icon = Icons.money_off;
      iconColor = Colors.redAccent;
    } else if ((txn["status"] ?? '').toLowerCase().contains('sales') ||
        (txn["status"] ?? '').toLowerCase().contains('fulfilled')) {
      icon = Icons.point_of_sale;
      iconColor = const Color(0xFF1976D2);
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE3F2FD), width: 1.2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.13),
          radius: 22,
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          txn["name"],
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(txn["date"], style: GoogleFonts.poppins(fontSize: 13)),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              txn["status"],
              style: GoogleFonts.poppins(
                color: iconColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Text(
              txn["txn"],
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // Add this widget for recent people avatars
  Widget _recentPeopleAvatars(List<People> people) {
    // Group by category
    final customers = people.where((p) => p.category == 'customer').toList();
    final suppliers = people.where((p) => p.category == 'supplier').toList();
    final others = people
        .where((p) => p.category != 'customer' && p.category != 'supplier')
        .toList();

    Widget buildAvatar(People person) {
      // Get initials (first and last name)
      String initials = '?';
      final nameParts = person.name.trim().split(' ');
      if (nameParts.length == 1) {
        initials = nameParts[0].isNotEmpty
            ? nameParts[0][0].toUpperCase()
            : '?';
      } else if (nameParts.length > 1) {
        initials =
            nameParts[0][0].toUpperCase() + nameParts.last[0].toUpperCase();
      }
      Color bgColor;
      switch (person.category) {
        case 'customer':
          bgColor = const Color(0xFF1976D2).withOpacity(0.15); // blue
          break;
        case 'supplier':
          bgColor = const Color(0xFF43A047).withOpacity(0.15); // green
          break;
        case 'employee':
          bgColor = const Color(0xFFF9A825).withOpacity(0.15); // yellow
          break;
        default:
          bgColor = const Color(0xFF8E24AA).withOpacity(0.15); // purple
      }
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: bgColor,
              child: Text(
                initials,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 56,
              child: Text(
                person.name.split(' ').first,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                StringCasingExtension(person.category).capitalize(),
                style: GoogleFonts.poppins(
                  fontSize: 8,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      );
    }

    List<Widget> buildSection(String label, List<People> group) {
      if (group.isEmpty) return [];
      return [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8, bottom: 2),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        SizedBox(
          height: 84, // Increased height to allow for padding
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: group.take(10).map(buildAvatar).toList(),
          ),
        ),
      ];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2), // Minimized bottom padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent People',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/peoples');
                },
                child: Text(
                  'See All',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF128C7E),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          ...buildSection('Customers', customers),
          ...buildSection('Suppliers', suppliers),
          ...buildSection('Others', others),
        ],
      ),
    );
  }

  // Redesigned menu grid: two wide rectangle cards per row
  Widget _menuGrid(BuildContext context) {
    final menuItems = [
      {
        'icon': Icons.inventory_2,
        'label': 'Inventory',
        'route': '/inventory',
        'color': Colors.teal,
      },
      {
        'icon': Icons.point_of_sale,
        'label': 'Sales',
        'route': '/sales',
        'color': Colors.green,
      },
      {
        'icon': Icons.shopping_cart,
        'label': 'Purchase',
        'route': '/purchase',
        'color': Colors.blue,
      },
      {
        'icon': Icons.money_off,
        'label': 'Expense',
        'route': '/expense', // Assuming you'll add this route
        'color': Colors.red,
      },
      {
        'icon': Icons.bar_chart,
        'label': 'Reports',
        'route': '/reports', // Assuming you'll add this route
        'color': Colors.deepPurple,
      },
      {
        'icon': Icons.calculate,
        'label': 'Calculator',
        'route': '/calculator',
        'color': Colors.indigo,
      },
      {
        'icon': Icons.book,
        'label': 'Digital Khaata',
        // No navigation for Digital Khaata
        'color': Colors.orange,
      },
      {
        'icon': Icons.people,
        'label': 'People',
        'route': '/peoples',
        'color': Colors.brown,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: 2.4, // Wider rectangle
      ),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        final item = menuItems[index];
        return InkWell(
          onTap: () {
            if (item['label'] == 'Digital Khaata') {
              // Do nothing
              return;
            }
            if (item.containsKey('route')) {
              Navigator.pushNamed(context, item['route'] as String);
            }
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 124, // Increased height
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: Colors.grey[200]!),
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 10,
            ), // Reduced padding
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: (item['color'] as Color).withOpacity(0.13),
                  radius: 20, // Reduced icon size
                  child: Icon(
                    item['icon'] as IconData,
                    size: 20, // Reduced icon size
                    color: item['color'] as Color,
                  ),
                ),
                const SizedBox(width: 8), // Reduced space between icon and text
                Expanded(
                  child: Center(
                    child: Text(
                      item['label'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: item['label'] == 'Digital Khaata' ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Modern, stylish BottomAppBar
  Widget _modernBottomAppBar() {
    // Flat, white, minimal, blue icons, no shadow, no overflow
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      elevation: 0,
      color: Colors.white,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.home, color: Color(0xFF1976D2), size: 28),
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
              tooltip: 'Home',
            ),
            IconButton(
              icon: const Icon(
                Icons.point_of_sale_rounded,
                color: Color(0xFF1976D2),
                size: 28,
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/sales');
              },
              tooltip: 'Sales',
            ),
            const SizedBox(width: 48), // Space for FAB
            IconButton(
              icon: const Icon(
                Icons.shopping_cart_rounded,
                color: Color(0xFF1976D2),
                size: 28,
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/purchase');
              },
              tooltip: 'Purchase',
            ),
            IconButton(
              icon: const Icon(
                Icons.settings,
                color: Color(0xFF1976D2),
                size: 28,
              ),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/settings',
                ); // Assuming you'll add this route
              },
              tooltip: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for Top 5 Sales
  Widget _topSalesList(DashboardProvider provider) {
    final productSales = <String, double>{};
    for (final bill in provider.allBills) {
      for (final item in bill.items) {
        productSales[item.name] =
            (productSales[item.name] ?? 0) + (item.total ?? 0);
      }
    }
    final sorted = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();
    if (top5.isEmpty) {
      return Center(
        child: Text('No sales data', style: GoogleFonts.poppins(fontSize: 13)),
      );
    }
    return Column(
      children: top5
          .map(
            (e) => ListTile(
              leading: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF1976D2).withOpacity(0.18),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const CircleAvatar(
                  backgroundColor: Colors.transparent,
                  radius: 20,
                  child: Icon(
                    Icons.trending_up_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              title: Text(
                e.key,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              trailing: Text(
                'Rs ${e.value.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          )
          .toList(),
    );
  }

  // Helper widget for Recent Purchases
  Widget _recentPurchasesList(DashboardProvider provider) {
    final inventory = List<InventoryItem>.from(provider.allInventory);
    inventory.sort(
      (a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    final recent = inventory.take(5).toList();
    if (recent.isEmpty) {
      return Center(
        child: Text(
          'No purchase data',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
      );
    }
    return Column(
      children: recent
          .map(
            (item) => ListTile(
              leading: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF43A047), Color(0xFFB2FF59)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF43A047).withOpacity(0.18),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const CircleAvatar(
                  backgroundColor: Colors.transparent,
                  radius: 20,
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              title: Text(
                item.name,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('Qty: ${item.quantity}'),
              trailing: Text(
                'Rs ${item.price.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          )
          .toList(),
    );
  }

  // Helper for filter button
  Widget _buildGraphFilterButton(String value, String label) {
    final isSelected = _graphFilter == value;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF1976D2) : Colors.white,
        foregroundColor: isSelected ? Colors.white : const Color(0xFF1976D2),
        elevation: isSelected ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: const Color(0xFF1976D2), width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      onPressed: () {
        setState(() {
          _graphFilter = value;
        });
      },
      child: Text(label),
    );
  }
}

extension StringCasingExtension on String {
  String capitalize() =>
      isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
}

// 1. Custom icons for activity types
IconData getActivityIcon(String type, Map<String, dynamic>? metadata) {
  switch (type) {
    case 'sale_add':
      return Icons.point_of_sale_rounded;
    case 'sale_delete':
      return Icons.delete_forever_rounded;
    case 'purchase_add':
      return Icons.add_shopping_cart_rounded;
    case 'purchase_edit':
      return Icons.edit_note_rounded;
    case 'purchase_delete':
      return Icons.delete_sweep_rounded;
    case 'people_add':
      return Icons.person_add_alt_1_rounded;
    case 'people_edit':
      return Icons.edit_rounded;
    case 'people_delete':
      return Icons.person_remove_rounded;
    case 'expense_add':
      return Icons.attach_money_rounded;
    case 'expense_edit':
      return Icons.edit_document;
    case 'expense_delete':
      return Icons.delete_outline_rounded;
    default:
      return Icons.info_outline_rounded;
  }
}

// 1. Add a function to get icon background color by activity type
Color getActivityIconBgColor(String type) {
  if (type.endsWith('_delete')) {
    return const Color(0xFFD32F2F); // red for all deletions
  }
  switch (type) {
    case 'sale_add':
      return const Color(0xFF1976D2); // blue
    case 'sale_delete':
      return const Color(0xFFD32F2F); // red (handled above, but for clarity)
    case 'purchase_add':
      return const Color(0xFF42A5F5); // light blue
    case 'purchase_edit':
      return const Color(0xFF64B5F6); // lighter blue
    case 'purchase_delete':
      return const Color(0xFF0D47A1); // navy blue
    case 'people_add':
      return const Color(0xFF2196F3); // blue
    case 'people_edit':
      return const Color(0xFF1976D2); // blue
    case 'people_delete':
      return const Color(0xFF1565C0); // dark blue
    case 'expense_add':
      return const Color(0xFF90CAF9); // pale blue
    case 'expense_edit':
      return const Color(0xFF42A5F5); // light blue
    default:
      return const Color(0xFF1976D2); // default blue
  }
}

// Add a helper to get a standardized activity type label
String _getActivityTypeLabel(String type) {
  switch (type) {
    case 'sale_add':
      return 'Sale Created';
    case 'sale_delete':
      return 'Sale Deleted';
    case 'purchase_add':
      return 'Purchase Added';
    case 'purchase_edit':
      return 'Purchase Edited';
    case 'purchase_delete':
      return 'Purchase Deleted';
    case 'people_add':
      return 'Person Added';
    case 'people_edit':
      return 'Person Edited';
    case 'people_delete':
      return 'Person Deleted';
    case 'expense_add':
      return 'Expense Added';
    case 'expense_edit':
      return 'Expense Edited';
    case 'expense_delete':
      return 'Expense Deleted';
    default:
      return 'Activity';
  }
}

// Place this at the file level, after other helpers, not inside any function/class
Color _getActivityTextColor(String type) {
  if (type.startsWith('sale')) {
    return const Color(0xFF1976D2); // blue for sales
  } else if (type.startsWith('purchase')) {
    return const Color(0xFF388E3C); // green for purchase
  } else if (type.endsWith('_delete')) {
    return const Color(0xFFD32F2F); // red for deletes
  } else {
    return getActivityIconBgColor(type); // fallback to icon color
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

Widget _buildLegendHint(Color color, String label) {
  return Container(
    height: 18,
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.25), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9, // Changed from 10.5 to 9
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}
