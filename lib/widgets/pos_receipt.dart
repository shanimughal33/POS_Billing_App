import 'package:flutter/material.dart';
import '../models/bill_item.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../utils/business_info.dart';
import 'dart:io';

class POSReceipt extends StatelessWidget {
  final List<BillItem> items;
  final double total;
  final String customerName;
  final String paymentMethod;
  final DateTime dateTime;
  final int billNumber;
  final BusinessInfo businessInfo;
  final double discount;

  const POSReceipt({
    super.key,
    required this.items,
    required this.total,
    required this.customerName,
    required this.paymentMethod,
    required this.dateTime,
    required this.billNumber,
    required this.businessInfo,
    required this.discount,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final receiptWidth = screenWidth > 600 ? 400.0 : screenWidth - 24;
    // Calculate subtotal and tax
    final subtotal = items.fold(0.0, (sum, item) => sum + item.total);
    // Discount can be a fixed amount or a percentage (if you want to support both, see below)
    double discountAmount = 0.0;
    String discountLabel = 'Discount:';
    if (discount > 0) {
      double percent = discount;
      if (discount <= 1.0) {
        percent = discount;
        discountLabel = 'Discount (${(discount * 100).toStringAsFixed(0)}%):';
      } else {
        percent = discount / 100.0;
        discountLabel = 'Discount (${discount.toStringAsFixed(0)}%):';
      }
      discountAmount = subtotal * percent;
    }
    final taxRate = double.tryParse(businessInfo.taxRate) ?? 0.0;
    final taxAmount = ((subtotal - discountAmount) * (taxRate / 100));
    final grandTotal = subtotal - discountAmount + taxAmount;
    return Center(
      child: Container(
        width: receiptWidth,
        margin: const EdgeInsets.symmetric(vertical: 18, horizontal: 0),
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border.all(color: Colors.black, width: 1),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo and Store Name
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 6),
              child: Column(
                children: [
                  if (businessInfo.businessLogoPath.isNotEmpty)
                    Image.file(
                      File(businessInfo.businessLogoPath),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.storefront,
                          size: 38,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    businessInfo.name,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    businessInfo.address,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 15,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    'Tel: ${businessInfo.phone}',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 15,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
            _asciiDivider(),
            // Bill Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Bill #: ',
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                billNumber.toString().padLeft(6, '0'),
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'Date: ',
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                _formatDate(dateTime),
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Customer: ',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          customerName,
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 15,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Payment: ',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        paymentMethod,
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            _asciiDivider(),
            SizedBox(height: 20),
            // Items Table with full frame and solid lines
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Table(
                border: TableBorder.all(
                  color: Colors.grey[500]!,
                  width: 1.2,
                  borderRadius: BorderRadius.circular(6),
                ),
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(2),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  // Header row
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey[200]),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: Text(
                          'ITEM',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Center(
                        child: Text(
                          'QTY',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          'AMOUNT',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Item rows
                  ...items.map(
                    (item) => TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2),
                              Text(
                                '@ Rs ${item.priceAsInt} each',
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Center(
                          child: Text(
                            item.quantityAsInt.toString(),
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            'Rs ${item.total.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14),
            // Lighter solid line below table before totals
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              height: 1.5,
              color: Colors.grey[500],
            ),
            SizedBox(height: 10),
            // Totals Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal:',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        '${businessInfo.currency} ${subtotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  if (businessInfo.enableDiscounts && discount > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          discountLabel,
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 15,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '-${businessInfo.currency} ${discountAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 15,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tax (${businessInfo.taxRate}%):',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        '${businessInfo.currency} ${taxAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total:',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        '${businessInfo.currency} ${grandTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            _asciiDivider(),
            SizedBox(height: 10),
            // Signature line
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Container(height: 1, color: Colors.grey[400]),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Signature',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(height: 1, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Column(
                children: [
                  Text(
                    businessInfo.customFooter.isNotEmpty
                        ? businessInfo.customFooter
                        : 'Thank you for shopping with us!',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  _buildFooterText('Items once sold cannot be returned.'),
                  Text(
                    'Support: ${businessInfo.supportPhone}',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 13,
                      color: Colors.black,
                    ),
                  ),
                  _buildFooterText('Have a great day!'),
                ],
              ),
            ),
            SizedBox(height: 10),
            _asciiDivider(),
            SizedBox(height: 6),
            _cutReceipt(),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _asciiDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '------------------------------------------',
        style: TextStyle(
          fontFamily: 'Courier',
          fontSize: 13,
          color: Colors.grey[700],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black,
            ),
          ),
          Text(
            'Rs${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterText(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Courier',
        fontSize: 15,
        color: Colors.grey[800],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _cutReceipt() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(width: double.infinity, height: 1, color: Colors.grey[300]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: Colors.white,
          child: Text(
            'cut here',
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 10,
              color: Colors.grey[400],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
