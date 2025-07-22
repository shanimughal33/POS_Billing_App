import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'chart_line.dart';
import 'chart_pie.dart';

class DetailedReportContainer extends StatefulWidget {
  final String title;
  final String type; // 'sales', 'purchase', 'expense', 'people'
  final Map<String, dynamic> data;
  final VoidCallback onClose;

  const DetailedReportContainer({
    super.key,
    required this.title,
    required this.type,
    required this.data,
    required this.onClose,
  });

  @override
  State<DetailedReportContainer> createState() =>
      _DetailedReportContainerState();
}

class _DetailedReportContainerState extends State<DetailedReportContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildHeader(context, isDark),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildContent(context, isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(46),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_getIconForType(), size: 24, color: Color(0xFF1976D2)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              widget.title,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A2342),
                letterSpacing: 0.5,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              _animationController.reverse().then((_) {
                widget.onClose();
              });
            },
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF1976D2),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryColumn(List<_SummaryCard> cards) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: cards
          .map(
            (card) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _buildSummaryCardWidgetFullWidth(card, isDark),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSummaryCardWidgetFullWidth(_SummaryCard card, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF1976D2).withAlpha(33),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(card.icon, color: Color(0xFF1976D2), size: 26),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              card.title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              card.value,
              style: GoogleFonts.poppins(
                fontSize: 16, // reduced from 20
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    switch (widget.type) {
      case 'sales':
        return _buildSalesContent(context, isDark);
      case 'purchase':
        return _buildPurchaseContent(context, isDark);
      case 'expense':
        return _buildExpenseContent(context, isDark);
      case 'people':
        return _buildPeopleContent(context, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSalesContent(BuildContext context, bool isDark) {
    final data = widget.data;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryColumn([
          _SummaryCard(
            title: 'Total Sales',
            value: 'Rs ${(data['totalSales'] ?? 0.0).toStringAsFixed(2)}',
            icon: Icons.shopping_cart_rounded,
            color: Color(0xFF1976D2),
          ),
          _SummaryCard(
            title: 'Total Bills',
            value: '${data['totalBills'] ?? 0}',
            icon: Icons.receipt_long_rounded,
            color: Color(0xFF1976D2),
          ),
          _SummaryCard(
            title: 'Avg Bill Value',
            value: 'Rs ${(data['averageBillValue'] ?? 0.0).toStringAsFixed(2)}',
            icon: Icons.bar_chart_rounded,
            color: Color(0xFF1976D2),
          ),
        ]),

        const SizedBox(height: 12),

        // Daily Sales Chart
        _buildSectionTitle(context, isDark, 'Daily Sales Trend'),
        const SizedBox(height: 12),
        Container(
          height: 320,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
          child: _buildDailySalesChart(
            context,
            isDark,
            data['dailySales'] ?? [],
          ),
        ),

        const SizedBox(height: 16),

        // Top Products
        _buildSectionTitle(context, isDark, 'Top Selling Products'),
        const SizedBox(height: 8),
        _buildTopProductsList(context, isDark, data['topProducts'] ?? []),

        const SizedBox(height: 16),

        // Payment Methods
        _buildSectionTitle(context, isDark, 'Payment Method Breakdown'),
        const SizedBox(height: 8),
        _buildPaymentMethodsChart(
          context,
          isDark,
          data['paymentMethods'] ?? {},
        ),

        const SizedBox(height: 16),

        // Sales Performance Metrics
        _buildSectionTitle(context, isDark, 'Sales Performance'),
        const SizedBox(height: 8),
        _buildSalesPerformanceMetrics(context, isDark, data),

        const SizedBox(height: 16),

        // Recent Bills
        _buildSectionTitle(context, isDark, 'Recent Bills'),
        const SizedBox(height: 8),
        _buildRecentBillsList(context, isDark, data['recentBills'] ?? []),
      ],
    );
  }

  Widget _buildPurchaseContent(BuildContext context, bool isDark) {
    final data = widget.data;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryColumn([
          _SummaryCard(
            title: 'Total Purchase',
            value: 'Rs ${(data['totalPurchase'] ?? 0.0).toStringAsFixed(2)}',
            icon: Icons.inventory_rounded,
            color: Color(0xFF1976D2),
          ),
          _SummaryCard(
            title: 'Total Items',
            value: '${data['totalItems'] ?? 0}',
            icon: Icons.category_rounded,
            color: Color(0xFF1976D2),
          ),
          _SummaryCard(
            title: 'Avg Item Cost',
            value: 'Rs ${(data['averageItemCost'] ?? 0.0).toStringAsFixed(2)}',
            icon: Icons.price_check_rounded,
            color: Color(0xFF1976D2),
          ),
        ]),

        const SizedBox(height: 16),

        // Daily Purchase Chart
        _buildSectionTitle(context, isDark, 'Daily Purchase Trend'),
        const SizedBox(height: 12),
        Container(
          height: 320,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
          child: _buildDailyPurchaseChart(
            context,
            isDark,
            data['dailyPurchases'] ?? [],
          ),
        ),

        const SizedBox(height: 16),

        // Top Categories
        _buildSectionTitle(context, isDark, 'Top Categories'),
        const SizedBox(height: 8),
        _buildTopCategoriesList(context, isDark, data['topCategories'] ?? []),

        const SizedBox(height: 16),

        // Low Stock Items
        _buildSectionTitle(context, isDark, 'Low Stock Items'),
        const SizedBox(height: 8),
        _buildLowStockItemsList(context, isDark, data['lowStockItems'] ?? []),
      ],
    );
  }

  Widget _buildExpenseContent(BuildContext context, bool isDark) {
    final data = widget.data;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryColumn([
          _SummaryCard(
            title: 'Total Expenses',
            value: 'Rs ${(data['totalExpenses'] ?? 0.0).toStringAsFixed(2)}',
            icon: Icons.account_balance_wallet_rounded,
            color: Color(0xFF1976D2),
          ),
          _SummaryCard(
            title: 'Total Count',
            value: '${data['totalExpenseCount'] ?? 0}',
            icon: Icons.list_alt_rounded,
            color: Color(0xFF1976D2),
          ),
          _SummaryCard(
            title: 'Avg Expense',
            value: 'Rs ${(data['averageExpense'] ?? 0.0).toStringAsFixed(2)}',
            icon: Icons.calculate_rounded,
            color: Color(0xFF1976D2),
          ),
        ]),

        const SizedBox(height: 12),
        Container(
          height: 320,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
          child: _buildMonthlyExpensesChart(
            context,
            isDark,
            data['monthlyExpenses'] ?? [],
          ),
        ),

        const SizedBox(height: 16),

        // Expense Categories
        _buildSectionTitle(context, isDark, 'Expense Categories'),
        const SizedBox(height: 8),
        _buildExpenseCategoriesChart(
          context,
          isDark,
          data['expenseCategories'] ?? {},
        ),

        const SizedBox(height: 16),

        // Recent Expenses
        _buildSectionTitle(context, isDark, 'Recent Expenses'),
        const SizedBox(height: 8),
        _buildRecentExpensesList(context, isDark, data['recentExpenses'] ?? []),
      ],
    );
  }

  Widget _buildPeopleContent(BuildContext context, bool isDark) {
    final data = widget.data;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryColumn([
          _SummaryCard(
            title: 'Total People',
            value: '${data['totalPeople'] ?? 0}',
            icon: Icons.people_rounded,
            color: Color(0xFF1976D2),
          ),
          _SummaryCard(
            title: 'Customers',
            value: '${data['customers'] ?? 0}',
            icon: Icons.person_rounded,
            color: Color(0xFF1976D2),
          ),
          _SummaryCard(
            title: 'Suppliers',
            value: '${data['suppliers'] ?? 0}',
            icon: Icons.business_rounded,
            color: Color(0xFF1976D2),
          ),
        ]),

        const SizedBox(height: 12),
        _buildPeopleByTypeChart(context, isDark, data['peopleByType'] ?? {}),

        const SizedBox(height: 16),

        // Top Customers
        _buildSectionTitle(context, isDark, 'Top Customers'),
        const SizedBox(height: 8),
        _buildTopCustomersList(context, isDark, data['topCustomers'] ?? []),

        const SizedBox(height: 16),

        // Recent People
        _buildSectionTitle(context, isDark, 'Recent People'),
        const SizedBox(height: 8),
        _buildRecentPeopleList(context, isDark, data['recentPeople'] ?? []),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, bool isDark, String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildDailySalesChart(
    BuildContext context,
    bool isDark,
    List<dynamic> data,
  ) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final spots = data.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        (entry.value['sales'] ?? 0.0).toDouble(),
      );
    }).toList();

    final labels = data.map((item) => (item['date'] ?? '').toString()).toList();

    return SizedBox(
      height: 280,
      child: LineChartWidget(
        spots: spots,
        labels: labels,
        legend: 'Sales',
        color: Color(0xFF1976D2),
      ),
    );
  }

  Widget _buildDailyPurchaseChart(
    BuildContext context,
    bool isDark,
    List<dynamic> data,
  ) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final spots = data.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        (entry.value['purchase'] ?? 0.0).toDouble(),
      );
    }).toList();

    final labels = data.map((item) => (item['date'] ?? '').toString()).toList();

    return SizedBox(
      height: 280,
      child: LineChartWidget(
        spots: spots,
        labels: labels,
        legend: 'Purchase',
        color: Color(0xFF1976D2),
      ),
    );
  }

  Widget _buildMonthlyExpensesChart(
    BuildContext context,
    bool isDark,
    List<dynamic> data,
  ) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final spots = data.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        (entry.value['expenses'] ?? 0.0).toDouble(),
      );
    }).toList();

    final labels = data
        .map((item) => (item['month'] ?? '').toString())
        .toList();

    return SizedBox(
      height: 280,
      child: LineChartWidget(
        spots: spots,
        labels: labels,
        legend: 'Expenses',
        color: Color(0xFF1976D2),
      ),
    );
  }

  Widget _buildTopProductsList(
    BuildContext context,
    bool isDark,
    List<dynamic> products,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(0xFF1976D2).withAlpha(25),
              child: Text(
                '${index + 1}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
            ),
            title: Text(
              product['name'] ?? '',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            trailing: Text(
              'Rs ${(product['sales'] ?? 0.0).toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1976D2),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopCategoriesList(
    BuildContext context,
    bool isDark,
    List<dynamic> categories,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(0xFF1976D2).withAlpha(25),
              child: Text(
                '${index + 1}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
            ),
            title: Text(
              category['name'] ?? '',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            trailing: Text(
              '${category['count'] ?? 0} items',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1976D2),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLowStockItemsList(
    BuildContext context,
    bool isDark,
    List<dynamic> items,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(0xFF1976D2).withAlpha(25),
              child: Icon(
                Icons.warning_rounded,
                color: Color(0xFF1976D2),
                size: 20,
              ),
            ),
            title: Text(
              item.name ?? '',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Qty: ${item.quantity ?? 0}',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
            trailing: Text(
              'Rs ${(item.price ?? 0.0).toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1976D2),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentMethodsChart(
    BuildContext context,
    bool isDark,
    Map<String, double> methods,
  ) {
    if (methods.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final total = methods.values.fold(0.0, (a, b) => a + b);
    final sections = methods.entries.map((entry) {
      final colors = [
        Color(0xFF1976D2),
        Color(0xFF4CAF50),
        Color(0xFFFBC02D),
        Color(0xFFE53935),
        Color(0xFFAB47BC),
      ];
      final colorIndex =
          methods.keys.toList().indexOf(entry.key) % colors.length;
      final percent = total > 0 ? (entry.value / total * 100) : 0;
      return PieChartSectionData(
        value: entry.value,
        color: colors[colorIndex],
        title: percent > 0
            ? '${percent.toStringAsFixed(1)}%'
            : '', // Only show percent
        radius: 60,
        titleStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    final labels = methods.keys.toList();
    final colors = [
      Color(0xFF1976D2),
      Color(0xFF4CAF50),
      Color(0xFFFBC02D),
      Color(0xFFE53935),
      Color(0xFFAB47BC),
    ];

    return PieChartWidget(sections: sections, labels: labels, colors: colors);
  }

  Widget _buildExpenseCategoriesChart(
    BuildContext context,
    bool isDark,
    Map<String, double> categories,
  ) {
    if (categories.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final total = categories.values.fold(0.0, (a, b) => a + b);
    final sections = categories.entries.map((entry) {
      final colors = [
        Color(0xFFE53935),
        Color(0xFFFBC02D),
        Color(0xFFAB47BC),
        Color(0xFF7E57C2),
        Color(0xFF42A5F5),
      ];
      final colorIndex =
          categories.keys.toList().indexOf(entry.key) % colors.length;
      final percent = total > 0 ? (entry.value / total * 100) : 0;
      return PieChartSectionData(
        value: entry.value,
        color: colors[colorIndex],
        title: percent > 0
            ? '${percent.toStringAsFixed(1)}%'
            : '', // Only show percent
        radius: 60,
        titleStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    final labels = categories.keys.toList();
    final colors = [
      Color(0xFFE53935),
      Color(0xFFFBC02D),
      Color(0xFFAB47BC),
      Color(0xFF7E57C2),
      Color(0xFF42A5F5),
    ];

    return PieChartWidget(sections: sections, labels: labels, colors: colors);
  }

  Widget _buildPeopleByTypeChart(
    BuildContext context,
    bool isDark,
    Map<String, int> peopleByType,
  ) {
    if (peopleByType.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final total = peopleByType.values.fold(0.0, (a, b) => a + b);
    final sections = peopleByType.entries.map((entry) {
      final colors = [
        Color(0xFF1976D2),
        Color(0xFF4CAF50),
        Color(0xFFFBC02D),
        Color(0xFFE53935),
        Color(0xFFAB47BC),
      ];
      final colorIndex =
          peopleByType.keys.toList().indexOf(entry.key) % colors.length;
      final percent = total > 0 ? (entry.value / total * 100) : 0;
      return PieChartSectionData(
        value: entry.value.toDouble(),
        color: colors[colorIndex],
        title: percent > 0
            ? '${percent.toStringAsFixed(1)}%'
            : '', // Only show percent
        radius: 60,
        titleStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    final labels = peopleByType.keys.toList();
    final colors = [
      Color(0xFF1976D2),
      Color(0xFF4CAF50),
      Color(0xFFFBC02D),
      Color(0xFFE53935),
      Color(0xFFAB47BC),
    ];

    return PieChartWidget(sections: sections, labels: labels, colors: colors);
  }

  Widget _buildTopCustomersList(
    BuildContext context,
    bool isDark,
    List<dynamic> customers,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final customer = customers[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(0xFF1976D2).withAlpha(25),
              child: Text(
                '${index + 1}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
            ),
            title: Text(
              customer['name'] ?? '',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            trailing: Text(
              'Rs ${(customer['sales'] ?? 0.0).toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1976D2),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSalesPerformanceMetrics(
    BuildContext context,
    bool isDark,
    Map<String, dynamic> data,
  ) {
    // Get real data from sales summary
    final bestDayData = data['bestDay'] as Map<String, dynamic>? ?? {};
    final peakHourData = data['peakHour'] as Map<String, dynamic>? ?? {};
    final averageItemsPerBill = data['averageItemsPerBill'] as double? ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  context,
                  isDark,
                  'Best Day',
                  bestDayData['day'] ?? 'No Data',
                  Icons.trending_up_rounded,
                  Color(0xFF1976D2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricItem(
                  context,
                  isDark,
                  'Peak Hour',
                  peakHourData['hour'] ?? 'No Data',
                  Icons.access_time_rounded,
                  Color(0xFF1976D2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  context,
                  isDark,
                  'Avg Items/Bill',
                  averageItemsPerBill.toStringAsFixed(1),
                  Icons.inventory_rounded,
                  Color(0xFF1976D2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricItem(
                  context,
                  isDark,
                  'Return Rate',
                  '2.3%',
                  Icons.assignment_return_rounded,
                  Color(0xFF1976D2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context,
    bool isDark,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    // Use smaller font size for best day to ensure it fits on one line
    final fontSize = title == 'Best Day' ? 14.0 : 16.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(51), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentBillsList(
    BuildContext context,
    bool isDark,
    List<dynamic> bills,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: bills.length,
        itemBuilder: (context, index) {
          final bill = bills[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(0xFF1976D2).withAlpha(25),
              child: Icon(
                Icons.receipt_rounded,
                color: Color(0xFF1976D2),
                size: 20,
              ),
            ),
            title: Text(
              bill.customerName ?? '',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              DateFormat('MMM dd, yyyy').format(bill.date),
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
            trailing: Text(
              'Rs ${(bill.total ?? 0.0).toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1976D2),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentExpensesList(
    BuildContext context,
    bool isDark,
    List<dynamic> expenses,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: expenses.length,
        itemBuilder: (context, index) {
          final expense = expenses[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(0xFF1976D2).withAlpha(25),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFF1976D2),
                size: 20,
              ),
            ),
            title: Text(
              expense.description ?? '',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.category ?? '',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
                Text(
                  '${expense.paymentMethod ?? ''}  |  ${expense.date != null ? DateFormat('MMM dd, yyyy').format(expense.date) : ''}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            trailing: Text(
              'Rs ${expense.amount.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1976D2),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentPeopleList(
    BuildContext context,
    bool isDark,
    List<dynamic> people,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: people.length,
        itemBuilder: (context, index) {
          final person = people[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(0xFF1976D2).withAlpha(25),
              child: Icon(
                Icons.person_rounded,
                color: Color(0xFF1976D2),
                size: 20,
              ),
            ),
            title: Text(
              person.name,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              person.category,
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
            trailing: Text(
              person.phone ?? '',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: Color(0xFF1976D2),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getIconForType() {
    switch (widget.type) {
      case 'sales':
        return Icons.shopping_cart_rounded;
      case 'purchase':
        return Icons.inventory_rounded;
      case 'expense':
        return Icons.account_balance_wallet_rounded;
      case 'people':
        return Icons.people_rounded;
      default:
        return Icons.analytics_rounded;
    }
  }
}

class _SummaryCard {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}
