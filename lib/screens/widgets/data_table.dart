import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class DataTableWidget extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final void Function(String column, bool ascending)? onSort;
  final void Function(String query)? onSearch;
  final Widget? exportButton;

  const DataTableWidget({
    super.key,
    required this.data,
    this.onSort,
    this.onSearch,
    this.exportButton,
  });

  @override
  State<DataTableWidget> createState() => _DataTableWidgetState();
}

class _DataTableWidgetState extends State<DataTableWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Enhanced data table with better styling
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 11, // smaller font size
                color: isDark ? Colors.white : const Color(0xFF1976D2), // Blue
              ),
              dataTextStyle: GoogleFonts.poppins(
                fontSize: 10, // smaller font size
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
              headingRowColor: MaterialStateProperty.resolveWith(
                (states) => isDark
                    ? const Color(0xFF1976D2).withAlpha(25)
                    : const Color(0xFF1976D2).withAlpha(20),
              ),
              dataRowColor: MaterialStateProperty.resolveWith(
                (states) => isDark ? const Color(0xFF1A1A1A) : Colors.white,
              ),
              dividerThickness: 1.5,
              columnSpacing: 16,
              horizontalMargin: 12,
              sortAscending: true,
              columns: [
                DataColumn(
                  label: SizedBox(
                    width: 80,
                    child: _buildColumnHeader(
                      'Date & Time',
                      Icons.calendar_today_rounded,
                    ),
                  ),
                  onSort: (i, asc) => widget.onSort?.call('date', asc),
                ),
                DataColumn(
                  label: SizedBox(
                    width: 70,
                    child: _buildColumnHeader(
                      'Invoice ID',
                      Icons.receipt_rounded,
                    ),
                  ),
                  onSort: (i, asc) => widget.onSort?.call('invoiceId', asc),
                ),
                DataColumn(
                  label: SizedBox(
                    width: 90,
                    child: _buildColumnHeader('Customer', Icons.person_rounded),
                  ),
                  onSort: (i, asc) => widget.onSort?.call('customer', asc),
                ),
                DataColumn(
                  label: SizedBox(
                    width: 60,
                    child: _buildColumnHeader('Type', Icons.category_rounded),
                  ),
                  onSort: (i, asc) => widget.onSort?.call('type', asc),
                ),
                DataColumn(
                  label: SizedBox(
                    width: 70,
                    child: _buildColumnHeader(
                      'Amount',
                      Icons.attach_money_rounded,
                    ),
                  ),
                  onSort: (i, asc) => widget.onSort?.call('amount', asc),
                ),
                DataColumn(
                  label: SizedBox(
                    width: 80,
                    child: _buildColumnHeader('Payment', Icons.payment_rounded),
                  ),
                  onSort: (i, asc) => widget.onSort?.call('payment', asc),
                ),
                DataColumn(
                  label: SizedBox(
                    width: 70,
                    child: _buildColumnHeader('Status', Icons.verified_rounded),
                  ),
                  onSort: (i, asc) => widget.onSort?.call('status', asc),
                ),
              ],
              rows: _buildRows(),
            ),
          ),
        ),
        // Search bar and export button row (no container)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Search bar takes most of the space
              Expanded(
                flex: 5,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Search invoices, customers, or payment methods...',
                    hintStyle: GoogleFonts.poppins(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade500,
                      fontSize: 13,
                    ),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2).withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF1976D2),
                        size: 18,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.grey.shade700
                            : const Color(0xFF1976D2).withAlpha(76),
                        width: 1.2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF232323) : Colors.white,
                  ),
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    widget.onSearch?.call(value);
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Export icon (fixed width, perfectly aligned)
              Container(
                width: 48,
                height: 48,
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
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF1976D2).withOpacity(0.18),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: DropdownButton2<String>(
                    isExpanded: false,
                    underline: const SizedBox.shrink(),
                    customButton: Icon(
                      Icons.file_upload_rounded,
                      color: Colors.white,
                      size: 28, // Increased icon size
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'excel',
                        child: Row(
                          children: [
                            Icon(
                              Icons.grid_on,
                              color: Color(0xFF1976D2),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Excel',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'word',
                        child: Row(
                          children: [
                            Icon(
                              Icons.description,
                              color: Color(0xFF1976D2),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Word',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      // TODO: Implement export logic
                    },
                    buttonStyleData: ButtonStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      offset: const Offset(-120, 0),
                      width: 120,
                      useRootNavigator: true,
                      direction: DropdownDirection.right,
                    ),
                    menuItemStyleData: MenuItemStyleData(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColumnHeader(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2).withAlpha(25),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF1976D2)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return const Color(0xFF1976D2); // Blue
      case 'credit':
        return const Color(0xFF0A2342); // Dark Blue
      case 'online':
        return const Color(0xFF123060); // Blue shade
      default:
        return Colors.grey.shade600;
    }
  }

  List<DataRow> _buildRows() {
    return widget.data.map((row) {
      return DataRow(
        cells: [
          DataCell(
            // Removed container background for date
            Text(
              '${row['date']} ${row['time'] ?? ''}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DataCell(Text(row['invoiceId'] ?? '')),
          DataCell(Text(row['customer'] ?? '')),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getTypeColor(row['type'] ?? '').withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                row['type'] ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getTypeColor(row['type'] ?? ''),
                ),
              ),
            ),
          ),
          DataCell(
            Text(
              row['amount'] != null ? 'Rs ${row['amount'].toString()}' : '',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1976D2), // Blue
              ),
            ),
          ),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getPaymentMethodColor(
                  row['payment'] ?? '',
                ).withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                row['payment'] ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getPaymentMethodColor(row['payment'] ?? ''),
                ),
              ),
            ),
          ),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(row['status'] ?? '').withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                row['status'] ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(row['status'] ?? ''),
                ),
              ),
            ),
          ),
        ],
      );
    }).toList();
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'sales':
        return const Color(0xFF1976D2); // Blue
      case 'purchase':
        return const Color(0xFF123060); // Blue shade
      case 'expense':
        return const Color(0xFF0A2342); // Dark Blue
      default:
        return Colors.grey.shade600;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF1976D2); // Blue
      case 'pending':
        return const Color(0xFFF59E0B); // Amber
      case 'cancelled':
        return const Color(0xFFEF4444); // Red
      default:
        return Colors.grey.shade600;
    }
  }
}
