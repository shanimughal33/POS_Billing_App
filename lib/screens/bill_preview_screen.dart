import 'package:flutter/material.dart';
import '../models/bill.dart';
import '../utils/business_info.dart';

class BillPreviewScreen extends StatelessWidget {
  final Bill bill;

  const BillPreviewScreen({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BusinessInfo>(
      future: BusinessInfo.load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final businessInfo = snapshot.data!;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF128C7E),
            title: const Text('Bill Preview'),
            actions: [
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: () => _handlePrint(context),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _handleShare(context),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(businessInfo),
                const SizedBox(height: 20),
                _buildCustomerInfo(),
                const SizedBox(height: 20),
                _buildItemsTable(),
                const SizedBox(height: 20),
                _buildTotals(),
                const SizedBox(height: 20),
                _buildFooter(),
              ],
            ),
          ),
          bottomNavigationBar: BottomAppBar(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF128C7E),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _handleSave(context),
                      child: const Text('Save Bill'),
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

  Widget _buildHeader(BusinessInfo businessInfo) {
    return Column(
      children: [
        Text(
          businessInfo.name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(businessInfo.address, style: const TextStyle(fontSize: 14)),
        Text(
          'Phone: ${businessInfo.phone}',
          style: const TextStyle(fontSize: 14),
        ),
        if (businessInfo.email.isNotEmpty)
          Text(
            'Email: ${businessInfo.email}',
            style: const TextStyle(fontSize: 14),
          ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bill No:  {bill.id ?? "N/A"}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              'Date:  {_formatDate(bill.date)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomerInfo() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer: ${bill.customerName}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            'Payment Method: ${bill.paymentMethod}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: const [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('No.', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Item',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Amount',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        ...bill.items.map(
          (item) => TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(item.serialNo.toString()),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(item.name),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(item.quantity.toString()),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Rs ${item.total.toStringAsFixed(2)}'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotals() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildTotalRow('Sub Total:', bill.subTotal),
          if (bill.discount > 0) _buildTotalRow('Discount:', bill.discount),
          if (bill.tax > 0) _buildTotalRow('Tax (${bill.tax}%):', bill.tax),
          const Divider(),
          _buildTotalRow(
            'Total:',
            bill.total,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount, {
    TextStyle style = const TextStyle(),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('Rs ${amount.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return const Column(
      children: [
        Text(
          'Thank you for your business!',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Text('Visit us again', style: TextStyle(fontSize: 14)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _handlePrint(BuildContext context) {}

  void _handleShare(BuildContext context) {}

  void _handleSave(BuildContext context) {
    Navigator.pop(context);
  }
}
