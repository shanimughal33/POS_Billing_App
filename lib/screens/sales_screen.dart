// ignore_for_file: sized_box_for_whitespace

import 'package:flutter/material.dart';
import '../repositories/bill_repository.dart';
import '../models/bill.dart';
import 'package:intl/intl.dart';
import '../models/activity.dart';
import '../repositories/activity_repository.dart';
import '../utils/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import './Calculator.dart';
import 'package:forward_billing_app/screens/Calculator.dart';

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
  final BillRepository _billRepo = BillRepository();
  List<Bill> _allBills = [];
  List<Bill> _filteredBills = [];
  bool _loading = true;
  String _searchQuery = '';
  DateTimeRange? _dateRange;
  String? _selectedCustomer;
  String? _selectedPaymentMethod;
  final Map<int, bool> _expanded = {}; // bill.id -> expanded

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    final bills = await _billRepo.getAllBills();
    // Only show bills that are not deleted
    final filtered = bills.where((b) => b.isDeleted != true).toList();
    setState(() {
      _allBills = filtered;
      _applyFilters();
      _loading = false;
      _expanded.clear();
    });
  }

  void _applyFilters() {
    List<Bill> bills = List.from(_allBills);
    if (_dateRange != null) {
      bills = bills
          .where(
            (b) =>
                b.date.isAfter(
                  _dateRange!.start.subtract(const Duration(days: 1)),
                ) &&
                b.date.isBefore(_dateRange!.end.add(const Duration(days: 1))),
          )
          .toList();
    }
    if (_selectedCustomer != null && _selectedCustomer!.isNotEmpty) {
      bills = bills
          .where(
            (b) => b.customerName.toLowerCase().contains(
              _selectedCustomer!.toLowerCase(),
            ),
          )
          .toList();
    }
    if (_selectedPaymentMethod != null && _selectedPaymentMethod!.isNotEmpty) {
      bills = bills
          .where((b) => b.paymentMethod == _selectedPaymentMethod)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      bills = bills.where((b) {
        final query = _searchQuery.toLowerCase();
        return b.customerName.toLowerCase().contains(query) ||
            (b.id?.toLowerCase().contains(query) ?? false) ||
            b.items.any((item) => item.name.toLowerCase().contains(query));
      }).toList();
    }
    setState(() {
      _filteredBills = bills;
    });
  }

  void _showFilterDialog() async {
    final customers = _allBills.map((b) => b.customerName).toSet().toList();
    final paymentMethods = _allBills
        .map((b) => b.paymentMethod)
        .toSet()
        .toList();
    DateTimeRange? tempDateRange = _dateRange;
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
                Container(
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kLightBorder),
                  ),
                  child: ListTile(
                    title: Text(
                      tempDateRange == null
                          ? 'Any Date'
                          : '${DateFormat('dd MMM yyyy').format(tempDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(tempDateRange!.end)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kBlue.withAlpha((0.1 * 255).toInt()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.date_range_rounded,
                        color: kBlue,
                        size: 20,
                      ),
                    ),
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        initialDateRange: tempDateRange,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: kBlue,
                                onPrimary: kWhite,
                                surface: kWhite,
                                onSurface: kBlack87,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setModalState(() => tempDateRange = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kLightBorder),
                  ),
                  child: DropdownButtonFormField<String?>(
                    value: tempCustomer,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Customer',
                      prefixIcon: Icon(Icons.person_rounded, color: kBlue),
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
              setState(() {
                _dateRange = tempDateRange;
                _selectedCustomer = tempCustomer;
                _selectedPaymentMethod = tempPayment;
                _applyFilters();
              });
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBill(Bill bill) async {
    // Set isDeleted flag in DB
    final billId = int.tryParse(bill.id ?? '') ?? -1;
    if (billId > 0) {
      await _billRepo.softDeleteBill(billId);
      await ActivityRepository().logActivity(
        Activity(
          type: 'sale_delete',
          description: 'Deleted bill #${bill.id} for ${bill.customerName}',
          timestamp: DateTime.now(),
          metadata: {
            'id': bill.id,
            'customer': bill.customerName,
            'total': bill.total,
          },
        ),
      );
      await _loadBills();
    }
  }

  double get _totalSales => _filteredBills.fold(0.0, (sum, b) => sum + b.total);
  int get _totalBills => _filteredBills.length;
  int get _totalQty => _filteredBills.fold(
    0,
    (sum, b) =>
        sum +
        b.items.fold(
          0,
          (s, i) =>
              s +
              (i.quantity is int
                  ? i.quantity as int
                  : (i.quantity is double
                        ? (i.quantity as double).round()
                        : int.tryParse(i.quantity.toString()) ?? 0)),
        ),
  );

  Future<void> _logBillCreation(Bill bill) async {
    await ActivityRepository().logActivity(
      Activity(
        type: 'sale_add',
        description:
            'Created bill for ${bill.customerName}, total: Rs ${bill.total}',
        timestamp: DateTime.now(),
        metadata: {
          'id': bill.id,
          'customer': bill.customerName,
          'total': bill.total,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentGreen = kBlue;
    // Calculate extra details for totals section
    final uniqueCustomers = _filteredBills
        .map((b) => b.customerName)
        .toSet()
        .length;
    String dateRangeLabel = '';
    if (_filteredBills.isNotEmpty) {
      final dates = _filteredBills.map((b) => b.date).toList()..sort();
      final first = dates.first;
      final last = dates.last;
      if (first == last) {
        dateRangeLabel = DateFormat('dd MMM yyyy').format(first);
      } else {
        dateRangeLabel =
            '${DateFormat('dd MMM yyyy').format(first)} - ${DateFormat('dd MMM yyyy').format(last)}';
      }
    }
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F0F0F) : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A2233) : Colors.white,
        centerTitle: true,
        title: Text(
          'Sales Management',
          style: TextStyle(
            fontSize: 22,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0A2342),
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: IconThemeData(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0A2342)),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kBlue),
              ),
            )
          : Column(
              children: [
                // Enhanced Totals Container
                Container(
                  margin: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 14,
                    bottom: 6,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 10,
                  ),
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
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Total Sales
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.attach_money_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Rs ' + formatIndianAmount(_totalSales),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      // Total Bills
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_totalBills',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bills',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      // Total Items
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_totalQty',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Items',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fade(duration: 400.ms).slideY(begin: -0.5),

                // Enhanced Search & Filter
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: kGrey500.withAlpha(25),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: kLightBorder, width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                                hintText:
                                    'Search by customer, bill #, or item...',
                            hintStyle: TextStyle(
                              color: kGrey500,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: kBlue,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                              _applyFilters();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: kBlue,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _showFilterDialog,
                          child: Container(
                            padding: const EdgeInsets.all(10),
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
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.filter_alt_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                    )
                    .animate()
                    .fade(delay: 200.ms, duration: 400.ms)
                    .slideY(begin: -0.5),

                const SizedBox(height: 20),

                // Enhanced Bill List
                Expanded(
                  child: _filteredBills.isEmpty
                      ? SingleChildScrollView(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const SizedBox(height: 80),
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 64,
                                  color: kBlue,
                                ),
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
                        )
                      : InteractiveViewer(
                          panEnabled: true,
                          scaleEnabled: true,
                          minScale: 1.0,
                          maxScale: 3.0,
                          child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredBills.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, idx) {
                            final bill = _filteredBills[idx];
                            final billKey = int.tryParse(bill.id ?? '') ?? idx;
                            final isOpen = _expanded[billKey] == true;
                            return Dismissible(
                              key: ValueKey('bill_${bill.id ?? idx}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: kRed100,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.delete_rounded,
                                  color: kRed,
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
                                            color: kRed.withAlpha(
                                              (0.1 * 255).toInt(),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                return res == true;
                              },
                              onDismissed: (direction) => _deleteBill(bill),
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: kWhite,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: kGrey500.withAlpha(18),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: kBlue.withAlpha(30),
                                        width: 1,
                                      ),
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.receipt_rounded,
                                          color: kBlue,
                                          size: 22,
                                        ),
                                      ),
                                      title: Text(
                                        'Bill #${bill.id ?? ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: kBlue,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        maxLines: 1,
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.person_rounded,
                                                size: 14,
                                                color: kGrey600,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  bill.customerName,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: kBlack87,
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                color: kGrey500,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  DateFormat(
                                                    'dd MMM, yyyy – hh:mm a',
                                                  ).format(bill.date),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: kGrey600,
                                                    fontWeight: FontWeight.w500,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'Rs ' +
                                                  formatIndianAmount(
                                                    bill.total,
                                                  ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: kBlue,
                                                fontSize: 14,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              maxLines: 1,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            bill.paymentMethod,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: kBlue,
                                              fontWeight: FontWeight.w600,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            maxLines: 1,
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _expanded[billKey] = !isOpen;
                                        });
                                      },
                                    ),
                                  ),
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeInOut,
                                    child: isOpen
                                        ? Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: kCardBg,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: kBlue.withAlpha(30),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: kGrey500.withAlpha(12),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Removed Bill ID and date/time row
                                                // Grid header
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 6,
                                                        horizontal: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: kBlue.withAlpha(18),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    children: const [
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          'Name',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13,
                                                            color: kBlue,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Text(
                                                          'Qty',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13,
                                                            color: kBlue,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Text(
                                                          'Price',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13,
                                                            color: kBlue,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Text(
                                                          'Total',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13,
                                                            color: kBlue,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                // Grid rows
                                                ...bill.items.map(
                                                  (item) => Container(
                                                    margin:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 2,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 6,
                                                          horizontal: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF232A36) : Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: kGrey500
                                                              .withAlpha(6),
                                                          blurRadius: 2,
                                                          offset: Offset(0, 1),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          flex: 2,
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .shopping_bag_outlined,
                                                                color: kBlue
                                                                    .withAlpha(
                                                                      180,
                                                                    ),
                                                                size: 16,
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Flexible(
                                                                child: Text(
                                                                  item.name,
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            '${item.quantity.toStringAsFixed(0)}',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: kBlue,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            'Rs ' +
                                                                formatIndianAmount(
                                                                  item.price,
                                                                ),
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            'Rs ' +
                                                                formatIndianAmount(
                                                                  item.total,
                                                                ),
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 12,
                                                              color: kBlue,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const Divider(height: 18),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      'Subtotal: Rs ' +
                                                          formatIndianAmount(
                                                            bill.subTotal,
                                                          ),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    if (bill.discount > 0) ...[
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Discount: Rs ' +
                                                            formatIndianAmount(
                                                              bill.discount,
                                                            ),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: kRed,
                                                        ),
                                                      ),
                                                    ],
                                                    if (bill.tax > 0) ...[
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Tax: Rs ' +
                                                            formatIndianAmount(
                                                              bill.tax,
                                                            ),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Total: Rs ' +
                                                          formatIndianAmount(
                                                            bill.total,
                                                          ),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                        color: kBlue,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                              ).animate().fade(delay: (100 * idx).ms).slideY(begin: 0.5);
                          },
                          ),
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
            );
          },
          tooltip: 'Add Bill',
        ),
      ),
    );
  }
}
