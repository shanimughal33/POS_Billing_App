import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/bill_item.dart';
import '../widgets/pos_receipt.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ReceiptScreen extends StatelessWidget {
  final List<BillItem> items;
  final double total;
  final String customerName;
  final String paymentMethod;
  final DateTime dateTime;
  final int billNumber;

  ReceiptScreen({
    Key? key,
    required this.items,
    required this.total,
    required this.customerName,
    required this.paymentMethod,
    required this.dateTime,
    required this.billNumber,
  }) : super(key: key);

  Future<void> _shareBill() async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (context) => _buildReceiptPdf(),
        ),
      );
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/Bill_$billNumber.pdf");
      await file.writeAsBytes(await pdf.save());
      await Share.shareFiles([file.path], text: 'Bill #$billNumber');
    } catch (e) {
      debugPrint('Error sharing bill: $e');
    }
  }

  Future<void> _printReceipt() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => _buildReceiptPdf(),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _buildReceiptPdf() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Store Logo
        pw.Center(
          child: pw.Container(
            width: 70,
            height: 70,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Center(
              child: pw.Icon(
                pw.IconData(0xe3af),
                size: 45,
                color: PdfColors.black,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 10),

        // Store Name with modern font
        pw.Center(
          child: pw.Text(
            'GROCERY STORE',
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 32,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 2,
              color: PdfColors.black,
            ),
          ),
        ),
        pw.SizedBox(height: 4),

        // Store Details with improved spacing
        pw.Center(
          child: pw.Text(
            '123 Main Street, City',
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 16,
              color: PdfColors.grey800,
            ),
          ),
        ),
        pw.Center(
          child: pw.Text(
            'Tel: (123) 456-7890',
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 16,
              color: PdfColors.grey800,
            ),
          ),
        ),
        pw.SizedBox(height: 10),

        // Fancy divider
        _buildFancyDividerPdf(),
        pw.SizedBox(height: 12),

        // Bill details with improved layout
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Bill #: ${billNumber.toString().padLeft(6, '0')}',
                    style: pw.TextStyle(
                      font: pw.Font.courier(),
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Text(
                    _formatDate(dateTime),
                    style: pw.TextStyle(
                      font: pw.Font.courier(),
                      fontSize: 14,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Text(
                    'Customer: ',
                    style: pw.TextStyle(
                      font: pw.Font.courier(),
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      customerName,
                      style: pw.TextStyle(
                        font: pw.Font.courier(),
                        fontSize: 14,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Text(
                    'Payment: ',
                    style: pw.TextStyle(
                      font: pw.Font.courier(),
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Text(
                    paymentMethod,
                    style: pw.TextStyle(
                      font: pw.Font.courier(),
                      fontSize: 14,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),

        // Items table with improved design
        pw.Container(
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Column(
            children: [
              // Table header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(8),
                    topRight: pw.Radius.circular(8),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text(
                        'ITEM',
                        style: pw.TextStyle(
                          font: pw.Font.courier(),
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        'QTY',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          font: pw.Font.courier(),
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        'AMOUNT',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          font: pw.Font.courier(),
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Table items
              ...items.map(
                (item) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 10,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300),
                    ),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              item.name,
                              style: pw.TextStyle(
                                font: pw.Font.courier(),
                                fontSize: 12,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Rs ${item.price.toStringAsFixed(2)} each',
                              style: pw.TextStyle(
                                font: pw.Font.courier(),
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          item.quantity.toStringAsFixed(0),
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: pw.Font.courier(),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'Rs ${item.total.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            font: pw.Font.courier(),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),

        // Totals section with improved design
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Column(
            children: [
              _buildTotalRowPdf('Subtotal:', total),
              _buildTotalRowPdf('Tax (16%):', total * 0.16),
              _buildTotalRowPdf('Discount:', 0),
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 8),
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey400),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        font: pw.Font.courier(),
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Rs ${(total * 1.16).toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        font: pw.Font.courier(),
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),

        // Thank you message with improved design
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              border: pw.Border.all(color: PdfColors.green700, width: 2),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(
              'THANK YOU FOR YOUR BUSINESS!',
              style: pw.TextStyle(
                font: pw.Font.courier(),
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 16),

        // Footer with improved design
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'Items once sold cannot be returned',
                style: pw.TextStyle(
                  font: pw.Font.courier(),
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'For support: (123) 456-7890',
                style: pw.TextStyle(
                  font: pw.Font.courier(),
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),

        // Barcode
        pw.Center(
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data: 'BILL${billNumber.toString().padLeft(6, '0')}',
            width: 200,
            height: 60,
            drawText: true,
            textStyle: pw.TextStyle(font: pw.Font.courier(), fontSize: 12),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildFancyDividerPdf() {
    return pw.Row(
      children: [
        pw.Expanded(child: pw.Container(height: 2, color: PdfColors.grey400)),
        pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 10),
          child: pw.Text(
            '✦',
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 14,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.Expanded(child: pw.Container(height: 2, color: PdfColors.grey400)),
      ],
    );
  }

  pw.Widget _buildTotalRowPdf(String label, double amount) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 14,
              color: PdfColors.grey800,
            ),
          ),
          pw.Text(
            'Rs ${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 14,
              color: PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    // Implement date formatting logic based on the dateTime
    return dateTime.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF128C7E),
        title: Text(
          'Bill #${billNumber.toString().padLeft(6, '0')}',
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Print button
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: _printReceipt,
          ),
          // Share button
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareBill,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: POSReceipt(
              items: items,
              total: total,
              customerName: customerName,
              paymentMethod: paymentMethod,
              dateTime: dateTime,
              billNumber: billNumber,
            ),
          ),
        ),
      ),
    );
  }
}
