// ignore_for_file: sized_box_for_whitespace

import 'package:flutter/material.dart';
import 'package:forward_billing_app/providers/dashboard_provider.dart';
import 'package:provider/provider.dart';

import '../models/bill.dart';
import 'package:intl/intl.dart';
import '../models/activity.dart';
import '../utils/app_theme.dart';
import '../repositories/activity_repository.dart';

import './Calculator.dart' hide getCurrentUserUid;

import 'package:flutter/foundation.dart';
import '../utils/auth_utils.dart';
import '../utils/refresh_manager.dart';
import '../repositories/bill_repository.dart';
import '../models/bill_item.dart';

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

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';

  String? _selectedCustomer;
  String? _selectedPaymentMethod;
  final Map<int, bool> _expanded = {}; // bill.id -> expanded
  RefreshManager? _refreshManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshManager = Provider.of<RefreshManager>(context, listen: false);
      _refreshManager!.addListener(_onRefreshRequested);
    });
  }

  void _onRefreshRequested() {
    if (_refreshManager != null && _refreshManager!.shouldRefreshSales) {
      debugPrint('SalesScreen: Refresh requested, triggering stream update');
      _refreshManager!.clearSalesRefresh();
    }
  }

  @override
  void dispose() {
    // Clear any cached data or cancel any ongoing operations
    _expanded.clear();
    if (_refreshManager != null) {
      _refreshManager!.removeListener(_onRefreshRequested);
    }
    super.dispose();
  }

  // _loadBills is now obsolete and replaced by stream-based logic for instant updates.

  // _applyFilters is now replaced by _applyFiltersStream for stream-based UI.
  List<Bill> _applyFiltersStream(List<Bill> bills) {
    List<Bill> filtered = List.from(bills);

    if (_selectedCustomer != null && _selectedCustomer!.isNotEmpty) {
      filtered = filtered
          .where(
            (b) => b.customerName.toLowerCase().contains(
              _selectedCustomer!.toLowerCase(),
            ),
          )
          .toList();
    }
    if (_selectedPaymentMethod != null && _selectedPaymentMethod!.isNotEmpty) {
      filtered = filtered
          .where((b) => b.paymentMethod == _selectedPaymentMethod)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.trim();
      final int? billNumber = int.tryParse(query);
      if (billNumber != null) {
        // User searched for a bill number (e.g., '3' for bill #3)
        if (billNumber > 0 && billNumber <= filtered.length) {
          // Only show the bill at that 1-based index
          filtered = [filtered[billNumber - 1]];
        } else {
          filtered = [];
        }
      } else {
        filtered = filtered.where((b) {
          final q = query.toLowerCase();
          return b.customerName.toLowerCase().contains(q) ||
              b.items.any((item) => item.name.toLowerCase().contains(q));
        }).toList();
      }
    }
    return filtered;
  }

  void _showFilterDialog({required List<Bill> allBills}) async {
    final customers = allBills.map((b) => b.customerName).toSet().toList();
    final paymentMethods = allBills
        .map((b) => b.paymentMethod)
        .toSet()
        .toList();

    String? tempCustomer = _selectedCustomer;
    String? tempPayment = _selectedPaymentMethod;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kBlue.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.filter_alt_rounded,
                color: kBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Filter Sales',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setModalState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  value: tempCustomer,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Customer',
                    prefixIcon: Icon(Icons.person_rounded, color: kBlue),
                    border: InputBorder.none,
                  ),
                  items:
                      [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Any Customer'),
                        ),
                      ] +
                      customers
                          .map(
                            (c) => DropdownMenuItem<String?>(
                              value: c,
                              child: Text(c),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setModalState(() => tempCustomer = v),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kLightBorder),
                  ),
                  child: DropdownButtonFormField<String?>(
                    value: tempPayment,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Payment Method',
                      prefixIcon: Icon(Icons.payment_rounded, color: kBlue),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items:
                        [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Any Payment'),
                          ),
                        ] +
                        paymentMethods
                            .map(
                              (m) => DropdownMenuItem<String?>(
                                value: m,
                                child: Text(m),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setModalState(() => tempPayment = v),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kGrey500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF1976D2),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
              side: BorderSide.none,
            ),
            child: Text('Apply', style: TextStyle(color: Color(0xFF1976D2))),
            onPressed: () {
              if (mounted) {
                setState(() {
                  _selectedCustomer = tempCustomer;
                  _selectedPaymentMethod = tempPayment;
                });
              } else {
                _selectedCustomer = tempCustomer;
                _selectedPaymentMethod = tempPayment;
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBill(Bill bill) async {
    // Compute 1-based display index BEFORE deletion
    final dashboardProvider = context.read<DashboardProvider>();
    final preDeleteBills = dashboardProvider.bills
        .where((b) => !b.isDeleted)
        .toList();
    final idxInList = preDeleteBills.indexWhere((b) => b.id == bill.id);
    final displayIdx = idxInList >= 0 ? (idxInList + 1) : preDeleteBills.length;

    // Use the provider to delete the bill
    await context.read<DashboardProvider>().deleteBill(bill);

    // Log the activity
    final userId = await getCurrentUserUid() ?? '';
    await ActivityRepository().logActivity(
      Activity(
        userId: userId,
        type: 'sale_delete',
        description: 'Deleted bill #$displayIdx for ${bill.customerName}',
        timestamp: DateTime.now(),
        metadata: {
          'billId': bill.id,
          'customer': bill.customerName,
          'total': bill.total,
        },
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bill  Deleted Successfully'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _logBillCreation(Bill bill) async {
    final userId = await getCurrentUserUid() ?? '';
    // Compute 1-based display index; if the stream hasn't updated yet,
    // fall back to next sequential number.
    final dashboardProvider = context.read<DashboardProvider>();
    final currentBills = dashboardProvider.bills
        .where((b) => !b.isDeleted)
        .toList();
    final idxInList = currentBills.indexWhere((b) => b.id == bill.id);
    final displayIdx = idxInList >= 0
        ? (idxInList + 1)
        : (currentBills.length + 1);
    await ActivityRepository().logActivity(
      Activity(
        userId: userId,
        type: 'sale_create',
        description: 'Created new bill #$displayIdx for ${bill.customerName}',
        timestamp: DateTime.now(),
        metadata: {
          'billId': bill.id,
          'customer': bill.customerName,
          'total': bill.total,
          'itemCount': bill.items.length,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = context.watch<DashboardProvider>();
    final allBills = dashboardProvider.bills
        .where((b) => !b.isDeleted)
        .toList();
    final filteredBills = _applyFiltersStream(allBills);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Sales History'),
        centerTitle: true,

        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      body: Column(
        children: [
          _TotalsSection(bills: filteredBills),
          _SearchBar(
            onSearchChanged: (val) {
              if (mounted) {
                setState(() {
                  _searchQuery = val;
                });
              }
            },
            onFilterTap: () => _showFilterDialog(allBills: allBills),
          ),
          Expanded(
            child: _BillList(
              bills: filteredBills,
              onDeleteBill: _deleteBill, // Pass the delete function
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
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CalculatorScreen()),
            ).then((newBill) {
              if (newBill != null && newBill is Bill) {
                _logBillCreation(newBill);
              }
            });
          },
          tooltip: 'Create New Bill',
        ),
      ),
    );
  }
}

// Extracted widget for the totals section to prevent unnecessary rebuilds.
class _TotalsSection extends StatelessWidget {
  final List<Bill> bills;

  const _TotalsSection({required this.bills});

  @override
  Widget build(BuildContext context) {
    // Use allBills from DashboardProvider for instant, always-up-to-date totals
    final dashboardProvider = Provider.of<DashboardProvider>(
      context,
      listen: false,
    );
    final allBills = dashboardProvider.bills
        .where((b) => !b.isDeleted)
        .toList();

    // Calculate total sales from all bills
    final totalSales = allBills.fold<double>(
      0.0,
      (sum, bill) => sum + (bill.total ?? 0),
    );

    // Calculate unique customers
    final uniqueCustomers = allBills
        .where((bill) => bill.customerName.isNotEmpty)
        .map((bill) => bill.customerName)
        .toSet()
        .length;

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2342), Color(0xFF123060), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _TotalPill(
            icon: Icons.attach_money_rounded,
            label: 'Total',
            value: 'Rs ${formatIndianAmount(totalSales)}',
          ),
          _TotalPill(
            icon: Icons.receipt_long_rounded,
            label: 'Bills',
            value: allBills.length.toString(),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TotalPill(
                icon: Icons.people_rounded,
                label: 'Customers',
                value: uniqueCustomers.toString(),
              ),
              const SizedBox(height: 2),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TotalPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// Extracted widget for the search bar and filter button.
class _SearchBar extends StatelessWidget {
  final Function(String) onSearchChanged;
  final VoidCallback onFilterTap;

  const _SearchBar({required this.onSearchChanged, required this.onFilterTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.transparent
            : kWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: kGrey500.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by customer, bill #, or item...',
                hintStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.7)
                      : kGrey500,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.7)
                      : kBlue,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: kBlue,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onFilterTap,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0A2342),
                      Color(0xFF123060),
                      Color(0xFF1976D2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.filter_alt_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extracted StatefulWidget for the bill list to manage its own state.
class _BillList extends StatefulWidget {
  final List<Bill> bills;
  final Function(Bill) onDeleteBill;

  const _BillList({required this.bills, required this.onDeleteBill});

  @override
  State<_BillList> createState() => _BillListState();
}

class _BillListState extends State<_BillList> {
  String _getBillTitle(int idx) {
    // Try to get the searched bill number from SalesScreenState if available
    final salesScreenState = context
        .findAncestorStateOfType<_SalesScreenState>();
    if (salesScreenState != null && salesScreenState._searchQuery.isNotEmpty) {
      final query = salesScreenState._searchQuery.trim();
      final int? searchedNumber = int.tryParse(query);
      if (searchedNumber != null && widget.bills.length == 1) {
        // Find this bill's index in the full, unfiltered list
        final dashboardProvider = context.read<DashboardProvider>();
        final allBills = dashboardProvider.bills
            .where((b) => !b.isDeleted)
            .toList();
        final bill = widget.bills[0];
        final actualIdx = allBills.indexWhere((b) => b.id == bill.id);
        if (actualIdx != -1) {
          return 'Bill #$searchedNumber ';
        }
      }
    }
    // Default: show as Bill #N in the current list
    return 'Bill #${idx + 1}';
  }

  final Set<String> _expandedBillIds = {};
  final BillRepository _billRepo = BillRepository();
  String? _userId;

  @override
  void initState() {
    super.initState();
    getCurrentUserUid().then((uid) {
      if (mounted) {
        setState(() {
          _userId = uid;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bills.isEmpty) {
      return SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 80),
              Icon(Icons.receipt_long_rounded, size: 64, color: kBlue),
              const SizedBox(height: 16),
              Text(
                'No sales found',
                style: TextStyle(
                  color: kGrey600,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InteractiveViewer(
      panEnabled: true,
      scaleEnabled: true,
      minScale: 1.0,
      maxScale: 3.0,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.bills.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, idx) {
          final bill = widget.bills[idx];
          final isOpen = _expandedBillIds.contains(bill.id);

          return Dismissible(
            key: ValueKey('bill_${bill.id ?? idx}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFDC3545)
                    : kRed100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.delete_rounded,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : kRed,
                size: 28,
              ),
            ),
            confirmDismiss: (direction) async {
              final res = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kRed.withAlpha((0.1 * 255).toInt()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.warning_rounded,
                          color: kRed,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Delete Bill?'),
                    ],
                  ),
                  content: const Text(
                    'Are you sure you want to delete this bill? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              return res == true;
            },
            onDismissed: (direction) async {
              await widget.onDeleteBill(bill);
            },
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF013A63)
                        : kWhite,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: kGrey500.withAlpha(18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: kBlue.withAlpha(30), width: 1),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kBlue.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.receipt_rounded,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : kBlue,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      _getBillTitle(idx),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : kBlue,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 14,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withOpacity(0.8)
                                  : kGrey600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                bill.customerName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : kBlack87,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withOpacity(0.8)
                                  : kGrey500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                DateFormat(
                                  'dd MMM, yyyy – hh:mm a',
                                ).format(bill.date),
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white.withOpacity(0.8)
                                      : kGrey600,
                                  fontWeight: FontWeight.w500,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Rs ${formatIndianAmount(bill.total)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : kBlue,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF1976D2).withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border:
                                Theme.of(context).brightness == Brightness.dark
                                ? Border.all(
                                    color: const Color(
                                      0xFF1976D2,
                                    ).withOpacity(0.3),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Text(
                            bill.paymentMethod,
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF1976D2)
                                  : kBlue,
                              fontWeight: FontWeight.w600,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        if (_expandedBillIds.contains(bill.id)) {
                          _expandedBillIds.remove(bill.id);
                        } else {
                          _expandedBillIds.add(bill.id ?? '');
                        }
                      });
                    },
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 60),
                  curve: Curves.easeInOut,
                  child: isOpen
                      ? _buildStreamedBillItems(bill)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper method to build a consistent total row
  Widget _buildTotalRow(
    BuildContext context, {
    required String label,
    required double amount,
    bool isBold = false,
    Color? textColor,
    double textSize = 13,
    bool isDiscount = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white70 : Colors.black54;
    final amountColor = textColor ?? (isDark ? Colors.white : Colors.black);

    // Format the amount with proper sign for discounts
    final displayAmount = isDiscount ? -amount : amount;
    final displayText = 'Rs ${formatIndianAmount(displayAmount)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: textSize - (isBold ? 0 : 1),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? amountColor : defaultColor,
            ),
          ),
          Text(
            displayText,
            style: TextStyle(
              fontSize: textSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamedBillItems(Bill bill) {
    if (_userId == null || bill.id == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<BillItem>>(
      stream: _billRepo.streamBillItems(_userId!, bill.id!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show bill summary immediately while items load
          final double subtotal = bill.subTotal ?? 0.0;
          // Compute discount amount following app rules (<=100 => percent, >100 => fixed)
          double discountAmount = 0.0;
          if ((bill.discount) > 0) {
            discountAmount = (bill.discount <= 100)
                ? subtotal * (bill.discount / 100)
                : bill.discount;
          }
          final double taxableAmount = subtotal - discountAmount;
          final double taxAmount = (bill.tax > 0)
              ? taxableAmount * (bill.tax / 100)
              : 0.0;
          final double total = bill.total ?? (taxableAmount + taxAmount);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildTotalRow(context, label: 'Subtotal', amount: subtotal),
                _buildTotalRow(
                  context,
                  label: bill.discount > 0 && bill.discount <= 100
                      ? 'Discount (${bill.discount}%)'
                      : 'Discount',
                  amount: discountAmount,
                  textColor: Colors.red,
                  isDiscount: true,
                ),
                _buildTotalRow(
                  context,
                  label: bill.tax > 0 ? 'Tax (${bill.tax}%)' : 'Tax',
                  amount: taxAmount,
                ),
                const Divider(height: 16, thickness: 1),
                _buildTotalRow(
                  context,
                  label: 'TOTAL',
                  amount: total,
                  isBold: true,
                  textSize: 15,
                ),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading items: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Even if items are absent, show the bill summary
          final double subtotal = bill.subTotal ?? 0.0;
          double discountAmount = 0.0;
          if ((bill.discount) > 0) {
            discountAmount = (bill.discount <= 100)
                ? subtotal * (bill.discount / 100)
                : bill.discount;
          }
          final double taxableAmount = subtotal - discountAmount;
          final double taxAmount = (bill.tax > 0)
              ? taxableAmount * (bill.tax / 100)
              : 0.0;
          final double total = bill.total ?? (taxableAmount + taxAmount);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildTotalRow(context, label: 'Subtotal', amount: subtotal),
                _buildTotalRow(
                  context,
                  label: bill.discount > 0 && bill.discount <= 100
                      ? 'Discount (${bill.discount}%)'
                      : 'Discount',
                  amount: discountAmount,
                  textColor: Colors.red,
                  isDiscount: true,
                ),
                _buildTotalRow(
                  context,
                  label: bill.tax > 0 ? 'Tax (${bill.tax}%)' : 'Tax',
                  amount: taxAmount,
                ),
                const Divider(height: 16, thickness: 1),
                _buildTotalRow(
                  context,
                  label: 'TOTAL',
                  amount: total,
                  isBold: true,
                  textSize: 15,
                ),
              ],
            ),
          );
        }

        final items = snapshot.data!;
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF0A2342)
                    : kBlue.withAlpha(18),
                borderRadius: BorderRadius.circular(8),
                border: Theme.of(context).brightness == Brightness.dark
                    ? Border.all(color: const Color(0xFF1976D2), width: 1)
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Name',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : kBlue,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Qty',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : kBlue,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Price',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : kBlue,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Total',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : kBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.9)
                              : Colors.black87,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.quantity.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.9)
                              : Colors.black87,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Rs ${formatIndianAmount(item.price)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.9)
                              : Colors.black87,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Rs ${formatIndianAmount(item.total)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const Divider(height: 20, thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Builder(
                builder: (context) {
                  // Calculate subtotal from items to ensure accuracy
                  final double subtotal = items.fold(
                    0.0,
                    (sum, item) => sum + item.total,
                  );

                  // Calculate discount amount (handle both percentage and fixed amount)
                  double discountAmount = 0.0;
                  if (bill.discount > 0) {
                    if (bill.discount <= 100) {
                      // Discount is a percentage
                      discountAmount = subtotal * (bill.discount / 100);
                    } else {
                      // Discount is a fixed amount
                      discountAmount = bill.discount;
                    }
                  }

                  // Calculate taxable amount (subtotal - discount)
                  final taxableAmount = subtotal - discountAmount;

                  // Calculate tax amount (if any)
                  double taxAmount = 0.0;
                  if (bill.tax > 0) {
                    taxAmount = taxableAmount * (bill.tax / 100);
                  }

                  // Calculate final total
                  final calculatedTotal = taxableAmount + taxAmount;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Display subtotal
                      _buildTotalRow(
                        context,
                        label: 'Subtotal',
                        amount: subtotal,
                      ),

                      // Display discount (if any)
                      if (bill.discount > 0)
                        _buildTotalRow(
                          context,
                          label: bill.discount <= 100
                              ? 'Discount (${bill.discount}%)'
                              : 'Discount',
                          amount: discountAmount,
                          textColor: Colors.red,
                          isDiscount: true,
                        ),

                      // Display tax (if any)
                      if (bill.tax > 0)
                        _buildTotalRow(
                          context,
                          label: 'Tax (${bill.tax}%)',
                          amount: taxAmount,
                        ),

                      // Divider before total
                      const Divider(height: 16, thickness: 1),

                      // Display grand total
                      _buildTotalRow(
                        context,
                        label: 'TOTAL',
                        amount: calculatedTotal,
                        isBold: true,
                        textSize: 15,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
