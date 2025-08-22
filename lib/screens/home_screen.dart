import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forward_billing_app/repositories/bill_repository.dart';
import 'package:forward_billing_app/repositories/people_repository.dart';
import 'package:forward_billing_app/repositories/inventory_repository.dart';
import 'package:forward_billing_app/repositories/expense_repository.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'widgets/chart_comparison.dart';
import '../models/people.dart';
import '../models/expense.dart';
import 'package:provider/provider.dart';
import '../cubit/notification_cubit.dart';
import '../screens/notification_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/bill.dart';
import '../models/inventory_item.dart';

import '../models/activity.dart';
import '../repositories/activity_repository.dart';
import '../utils/auth_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../providers/dashboard_provider.dart';

String formatIndianAmount(num amount) {
  if (amount.abs() >= 10000000) {
    return '${(amount / 10000000).toStringAsFixed(2)} Cr';
  } else if (amount.abs() >= 100000) {
    return '${(amount / 100000).toStringAsFixed(2)} Lac';
  } else {
    final formatter = NumberFormat('#,##,##0.##');
    return formatter.format(amount);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _graphFilter = 'daily'; // 'daily', 'weekly', 'monthly'

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

  List<FlSpot> _getSalesData(DashboardProvider provider) {
    if (_graphFilter == 'daily') {
      return provider.salesChartData;
    } else if (_graphFilter == 'weekly') {
      final now = DateTime.now();
      List<double> weeklyTotals = List.filled(4, 0);
      for (final bill in provider.bills) {
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
      for (final bill in provider.bills) {
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
      final now = DateTime.now();
      List<double> weeklyTotals = List.filled(4, 0);
      for (final item in provider.inventory) {
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
      for (final item in provider.inventory) {
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
    final userName = "User"; // Replace with real user name if available
    final notificationCount = 3; // Replace with real notification count

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BillRepository()),
        ChangeNotifierProvider(create: (_) => InventoryRepository()),
        ChangeNotifierProvider(create: (_) => PeopleRepository()),
        ChangeNotifierProvider(create: (_) => ExpenseRepository()),
        ChangeNotifierProvider(
          create: (context) => DashboardProvider(
            billRepo: Provider.of<BillRepository>(context, listen: false),
            inventoryRepo: Provider.of<InventoryRepository>(
              context,
              listen: false,
            ),
            peopleRepo: Provider.of<PeopleRepository>(context, listen: false),
            expenseRepo: Provider.of<ExpenseRepository>(context, listen: false),
            userId: FirebaseAuth.instance.currentUser?.uid,
          ),
        ),
      ],
      child: Consumer<DashboardProvider>(
        builder: (context, provider, _) {
          if (provider.errorMessage != null &&
              provider.errorMessage!.isNotEmpty) {
            return WillPopScope(
              onWillPop: () async {
                final shouldExit = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Exit App'),
                    content: const Text(
                      'Are you sure you want to exit the app?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Exit'),
                      ),
                    ],
                  ),
                );
                return shouldExit ?? false;
              },
              child: Scaffold(
                backgroundColor: isDark
                    ? const Color(0xFF0F0F0F)
                    : Theme.of(context).scaffoldBackgroundColor,
                body: Center(
                  child: Text(
                    'Error: ',
                    style: TextStyle(color: Color(0xFF0A2342)),
                  ),
                ),
              ),
            );
          }
          // Wrap main Scaffold in WillPopScope for exit confirmation
          return WillPopScope(
            onWillPop: () async {
              final shouldExit = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Exit App'),
                  content: const Text('Are you sure you want to exit the app?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Exit'),
                    ),
                  ],
                ),
              );
              return shouldExit ?? false;
            },
            child: Scaffold(
              backgroundColor: isDark
                  ? const Color(0xFF0A2342)
                  : Theme.of(context).scaffoldBackgroundColor,
              extendBody: true,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(70),
                child: AppBar(
                  backgroundColor: isDark
                      ? const Color(0xFF0A2342)
                      : Theme.of(context).scaffoldBackgroundColor,
                  elevation: 0,
                  centerTitle: false,
                  title: Row(
                    children: [
                      // Dashboard icon (static)
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
                          color: isDark ? Colors.white : darkBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    BlocBuilder<NotificationCubit, NotificationState>(
                      builder: (context, state) {
                        int unreadCount = 0;
                        if (state is NotificationLoaded) {
                          unreadCount = state.notifications
                              .where((n) => !n.isRead)
                              .length;
                        }
                        return Stack(
                          children: [
                            IconButton(
                              icon: Icon(
                                unreadCount > 0
                                    ? Icons.notifications
                                    : Icons.notifications_none,
                                color: isDark ? Colors.white : darkBlue,
                                size: 28,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationScreen(),
                                  ),
                                );
                              },
                            ),
                            if (unreadCount > 0)
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
                                    '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    // Account menu moved to actions with enhanced dropdown
                    PopupMenuButton<String>(
                      tooltip: 'Account',
                      position: PopupMenuPosition.under,
                      offset: const Offset(0, 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          enabled: false,
                          child: FutureBuilder<User?>(
                            future: Future.value(
                              FirebaseAuth.instance.currentUser,
                            ),
                            builder: (context, snapshot) {
                              String displayName = 'User';
                              String userEmail = '';
                              String? photoUrl;
                              if (snapshot.hasData && snapshot.data != null) {
                                final user = snapshot.data!;
                                displayName =
                                    user.displayName ??
                                    user.email?.split('@').first ??
                                    'User';
                                userEmail = user.email ?? '';
                                photoUrl = user.photoURL;
                              }
                              return Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isDark
                                        ? Colors.white24
                                        : darkBlue,
                                    backgroundImage: photoUrl != null
                                        ? NetworkImage(photoUrl)
                                        : null,
                                    child: photoUrl == null
                                        ? Icon(
                                            Icons.person,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white
                                                : darkBlue,
                                          ),
                                        ),
                                        Text(
                                          userEmail,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(
                                Icons.logout,
                                color: isDark ? Colors.white : darkBlue,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Logout',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : darkBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'logout') {
                          try {
                            await FirebaseAuth.instance.signOut();
                          } catch (_) {}
                          try {
                            final google = GoogleSignIn();
                            await google.signOut();
                            await google.disconnect();
                          } catch (_) {}
                          await clearUserUid();
                          if (mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login',
                              (route) => false,
                            );
                          }
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white12 : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.account_circle,
                          color: isDark ? Colors.white : darkBlue,
                          size: 26,
                        ),
                      ),
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
                  // DashboardProvider auto-refreshes via streams; no manual refresh needed.
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
                                    FutureBuilder<User?>(
                                      future: Future.value(
                                        FirebaseAuth.instance.currentUser,
                                      ),
                                      builder: (context, snapshot) {
                                        final items = provider.inventory;

                                        String displayName = 'User';
                                        String userEmail = '';

                                        if (snapshot.hasData &&
                                            snapshot.data != null) {
                                          final user = snapshot.data!;
                                          displayName =
                                              user.displayName ??
                                              user.email?.split('@').first ??
                                              'User';
                                          userEmail = user.email ?? '';
                                        }

                                        return Text(
                                          displayName,
                                          style: GoogleFonts.urbanist(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF1976D2),
                                            letterSpacing: 0.5,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                // Removed profile icon menu from right side; menu is now on the dashboard icon.
                              ],
                            ),
                          ),
                          // Total Balance Card (robust, real-time: sales - purchases - expenses + sum(positive people) - sum(abs(negative people)))
                          StreamBuilder<List<Bill>>(
                            stream: provider.billRepo.streamBills(
                              FirebaseAuth.instance.currentUser?.uid ?? '',
                            ),
                            builder: (context, billSnapshot) {
                              final bills = billSnapshot.data ?? [];
                              final totalSales = bills.fold(
                                0.0,
                                (sum, b) => sum + b.total,
                              );
                              return StreamBuilder<List<InventoryItem>>(
                                // Use provider-managed inventory
                                stream:
                                    null, // Removed direct repository stream
                                builder: (context, inventorySnapshot) {
                                  final items = inventorySnapshot.data ?? [];
                                  final totalPurchases = items.fold(
                                    0.0,
                                    (sum, item) =>
                                        sum + (item.price * item.quantity),
                                  );
                                  return StreamBuilder<List<Expense>>(
                                    stream: provider.expenseRepo.streamExpenses(
                                      FirebaseAuth.instance.currentUser?.uid ??
                                          '',
                                    ),
                                    builder: (context, expenseSnapshot) {
                                      final expenses =
                                          expenseSnapshot.data ?? [];
                                      final totalExpenses = expenses.fold(
                                        0.0,
                                        (sum, e) => sum + (e.amount ?? 0.0),
                                      );
                                      return StreamBuilder<List<People>>(
                                        stream: provider.peopleRepo
                                            .getPeopleStream(
                                              FirebaseAuth
                                                      .instance
                                                      .currentUser
                                                      ?.uid ??
                                                  '',
                                            ),
                                        builder: (context, peopleSnapshot) {
                                          final people =
                                              peopleSnapshot.data ?? [];
                                          final peoplePositive = people
                                              .where((p) => p.balance > 0)
                                              .fold(
                                                0.0,
                                                (sum, p) => sum + p.balance,
                                              );
                                          final peopleNegative = people
                                              .where((p) => p.balance < 0)
                                              .fold(
                                                0.0,
                                                (sum, p) =>
                                                    sum + p.balance.abs(),
                                              );
                                          final totalBalance =
                                              totalSales -
                                              totalPurchases -
                                              totalExpenses +
                                              peoplePositive -
                                              peopleNegative;
                                          return Container(
                                            decoration: BoxDecoration(
                                              gradient: blueGradient,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.08),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                              backgroundBlendMode:
                                                  BlendMode.srcOver,
                                            ),
                                            padding: const EdgeInsets.all(20),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .account_balance_wallet,
                                                          color: Colors.white,
                                                          size: 22,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          "Total Balance",
                                                          style:
                                                              GoogleFonts.poppins(
                                                                color: Colors
                                                                    .white70,
                                                                fontSize: 15,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Text(
                                                        'Rs ${formatIndianAmount(totalBalance)}',
                                                        style:
                                                            GoogleFonts.poppins(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 28,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              letterSpacing:
                                                                  0.5,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                InkWell(
                                                  onTap: () {
                                                    Navigator.pushNamed(
                                                      context,
                                                      '/reports',
                                                    );
                                                  },
                                                  child: Text(
                                                    "See details",
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      decoration: TextDecoration
                                                          .underline,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 18),

                          // Stat Cards Grid (revert to original white card style)
                          Container(
                            height: 250,
                            child: GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 2.2,
                              children: [
                                StreamBuilder<List<Bill>>(
                                  stream: provider.billRepo.streamBills(
                                    FirebaseAuth.instance.currentUser?.uid ??
                                        '',
                                  ),
                                  builder: (context, snapshot) {
                                    final items = provider.inventory;

                                    final bills = snapshot.data ?? [];
                                    final totalSales = bills.fold(
                                      0.0,
                                      (sum, b) => sum + b.total,
                                    );
                                    return GestureDetector(
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
                                        totalSales,
                                        isDark
                                            ? const Color(0xFF013A63)
                                            : const Color(
                                                0xFFFFF7E6,
                                              ), // light amber
                                        gradient: null,
                                        textColor: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        iconColor: Color(0xFF1976D2),
                                      ),
                                    );
                                  },
                                ),
                                // Purchase Stat Card (real-time)
                                StreamBuilder<List<InventoryItem>>(
                                  // Use provider-managed inventory
                                  stream:
                                      null, // Removed direct repository stream
                                  builder: (context, snapshot) {
                                    final items = provider.inventory;

                                    final totalPurchase = items.fold(
                                      0.0,
                                      (sum, item) =>
                                          sum +
                                          ((item.price) * (item.quantity)),
                                    );
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/reports',
                                          arguments: {
                                            'selectedDetailedReport':
                                                'purchase',
                                          },
                                        );
                                      },
                                      child: _statCard(
                                        Icons.inventory_2,
                                        "Purchase",
                                        totalPurchase,
                                        isDark
                                            ? const Color(0xFF013A63)
                                            : const Color(
                                                0xFFE8F5E9,
                                              ), // light green
                                        gradient: null,
                                        textColor: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        iconColor: Color(0xFF128C7E),
                                      ),
                                    );
                                  },
                                ),
                                // Row 2: People, Expense
                                // People Stat Card (real-time)
                                StreamBuilder<List<People>>(
                                  stream: provider.peopleRepo.getPeopleStream(
                                    FirebaseAuth.instance.currentUser?.uid ??
                                        '',
                                  ),
                                  builder: (context, snapshot) {
                                    final items = provider.inventory;

                                    final people = snapshot.data ?? [];
                                    final customerCount = people
                                        .where((p) => p.category == 'customer')
                                        .length;
                                    return GestureDetector(
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
                                        customerCount,
                                        isDark
                                            ? const Color(0xFF013A63)
                                            : const Color(
                                                0xFFE3F2FD,
                                              ), // light blue
                                        gradient: null,
                                        textColor: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        iconColor: Colors.blue,
                                      ),
                                    );
                                  },
                                ),
                                // Expense Stat Card (real-time)
                                StreamBuilder<List<Expense>>(
                                  stream: provider.expenseRepo.streamExpenses(
                                    FirebaseAuth.instance.currentUser?.uid ??
                                        '',
                                  ),
                                  builder: (context, snapshot) {
                                    final items = provider.inventory;

                                    final expenses = snapshot.data ?? [];
                                    final totalExpense = expenses.fold(
                                      0.0,
                                      (sum, e) => sum + (e.amount ?? 0.0),
                                    );
                                    return GestureDetector(
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
                                        totalExpense,
                                        isDark
                                            ? const Color(0xFF013A63)
                                            : const Color(
                                                0xFFFFEBEE,
                                              ), // light red
                                        gradient: null,
                                        textColor: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        iconColor: Colors.red,
                                      ),
                                    );
                                  },
                                ),
                                // Row 3: Profit
                                // Profit Stat Card (real-time: Sales - Expenses)
                                StreamBuilder<List<Bill>>(
                                  stream: provider.billRepo.streamBills(
                                    FirebaseAuth.instance.currentUser?.uid ??
                                        '',
                                  ),
                                  builder: (context, billSnapshot) {
                                    final bills = billSnapshot.data ?? [];
                                    final totalSales = bills.fold(
                                      0.0,
                                      (sum, b) => sum + b.total,
                                    );
                                    return StreamBuilder<List<Expense>>(
                                      stream: provider.expenseRepo
                                          .streamExpenses(
                                            FirebaseAuth
                                                    .instance
                                                    .currentUser
                                                    ?.uid ??
                                                '',
                                          ),
                                      builder: (context, expenseSnapshot) {
                                        final expenses =
                                            expenseSnapshot.data ?? [];
                                        final totalExpense = expenses.fold(
                                          0.0,
                                          (sum, e) => sum + (e.amount ?? 0.0),
                                        );
                                        final profit =
                                            totalSales - totalExpense;
                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.pushNamed(
                                              context,
                                              '/reports',
                                            );
                                          },
                                          child: _statCard(
                                            Icons.trending_up_rounded,
                                            "Profit",
                                            profit,
                                            isDark
                                                ? const Color(0xFF013A63)
                                                : const Color(
                                                    0xFFE8F5E9,
                                                  ), // light green
                                            gradient: null,
                                            textColor: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            iconColor: Color(0xFF10B981),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                // Row 4: Inventory
                                // Inventory Stat Card (real-time)
                                StreamBuilder<List<InventoryItem>>(
                                  // Use provider-managed inventory
                                  stream:
                                      null, // Removed direct repository stream
                                  builder: (context, snapshot) {
                                    final items = provider.inventory;

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/reports',
                                          arguments: {
                                            'selectedDetailedReport':
                                                'purchase',
                                          },
                                        );
                                      },
                                      child: _statCard(
                                        Icons.store_rounded,
                                        "Inventory",
                                        items.length,
                                        isDark
                                            ? const Color(0xFF013A63)
                                            : const Color(
                                                0xFFF3E5F5,
                                              ), // light purple
                                        gradient: null,
                                        textColor: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        iconColor: Colors.deepPurple,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),
                          // Quick Links Heading
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              "Quick Links",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? Color(0xFF0A2342) : Colors.white,
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
                            child: _menuGrid(context, isDark),
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
                          StreamBuilder<List<Activity>>(
                            stream: ActivityRepository()
                                .getRecentActivitiesStream(
                                  userId:
                                      FirebaseAuth.instance.currentUser?.uid ??
                                      '',
                                  limit: 30,
                                ),
                            builder: (context, snapshot) {
                              final items = provider.inventory;

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
                                      color = isDark
                                          ? Colors.black
                                          : Colors.blue;
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
                                        left: BorderSide(
                                          color: color,
                                          width: 4,
                                        ),
                                      ),
                                      gradient: isDark
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFF0A2342),
                                                Color(0xFF123060),
                                                Color(0xFF1976D2),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      color: isDark ? null : Colors.white,
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
                                                  color: Colors.black
                                                      .withOpacity(0.13),
                                                  blurRadius: 16,
                                                  offset: Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              icon,
                                              color: Colors
                                                  .white, // Set icon color
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
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    Text(
                                                      DateFormat(
                                                        'dd MMM, hh:mm a',
                                                      ).format(act.timestamp),
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 11,
                                                        color: isDark
                                                            ? Colors.white
                                                            : Colors.grey[600],
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
                                                                  FontWeight
                                                                      .w500,
                                                              fontSize: 12.5,
                                                              color:
                                                                  const Color(
                                                                    0xFF1976D2,
                                                                  ),
                                                            ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
              bottomNavigationBar: _modernBottomAppBar(context),
            ),
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
    Color color, {
    Gradient? gradient,
    Color textColor = Colors.black,
    Color iconColor = Colors.blue,
  }) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 120,
        maxWidth: 180,
        minHeight: 56,
        maxHeight: 70,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0),
            blurRadius: 4,
            spreadRadius: 0.5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Monetary labels where we want currency formatting
                    final lower = label.toLowerCase();
                    final isMoney =
                        lower.contains('sale') ||
                        lower.contains('purchase') ||
                        lower.contains('expense') ||
                        lower.contains('profit');

                    final String display = isMoney
                        ? 'Rs ${formatIndianAmount(value)}'
                        : NumberFormat.compact().format(value);

                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        display,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Transaction tile widget

  // Redesigned menu grid: two wide rectangle cards per row
  Widget _menuGrid(BuildContext context, bool isDark) {
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
        'label': 'Khaata',
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

    // New style: 4 columns, circular icons with label under (like Manage Orders)
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      crossAxisCount: 4,
      mainAxisSpacing: 14,
      crossAxisSpacing: 8,
      childAspectRatio: 0.8,
      children: [
        for (final item in menuItems)
          InkWell(
            onTap: () {
              if (item['label'] == 'Digital Khaata') return; // no-op
              if (item.containsKey('route')) {
                Navigator.pushNamed(context, item['route'] as String);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: (item['color'] as Color).withOpacity(0.15),
                  child: Icon(
                    item['icon'] as IconData,
                    color: item['color'] as Color,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['label'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0A2342),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Modern, stylish BottomAppBar
  Widget _modernBottomAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      elevation: 0,
      color: isDark ? Color(0xFF013A63) : Colors.white,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(
                Icons.home,
                color: isDark ? Colors.white : const Color(0xFF1976D2),
                size: 24,
              ),
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
              tooltip: 'Home',
            ),
            IconButton(
              icon: Icon(
                Icons.point_of_sale_rounded,
                color: isDark ? Colors.white : const Color(0xFF1976D2),
                size: 24,
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/sales');
              },
              tooltip: 'Sales',
            ),
            const SizedBox(width: 48), // Space for FAB
            IconButton(
              icon: Icon(
                Icons.shopping_cart_rounded,
                color: isDark ? Colors.white : const Color(0xFF1976D2),
                size: 24,
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/purchase');
              },
              tooltip: 'Purchase',
            ),
            IconButton(
              icon: Icon(
                Icons.settings,
                color: isDark ? Colors.white : const Color(0xFF1976D2),
                size: 24,
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
    for (final bill in provider.bills) {
      for (final item in bill.items) {
        productSales[item.name] = (productSales[item.name] ?? 0) + item.total;
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
    final inventory = List<InventoryItem>.from(provider.inventory);
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
    case 'inventory_add':
      return 'Inventory Added';
    case 'inventory_edit':
      return 'Inventory Edited';
    case 'inventory_delete':
      return 'Inventory Deleted';
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
  }
  return const Color(0xFF1976D2); // default fallback
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
