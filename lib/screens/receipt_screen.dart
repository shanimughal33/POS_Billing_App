// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/bill_item.dart';
import '../widgets/pos_receipt.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../utils/business_info.dart';

class ReceiptScreen extends StatelessWidget {
  final List<BillItem> items;
  final double total;
  final String customerName;
  final String paymentMethod;
  final DateTime dateTime;
  final int billNumber;

  const ReceiptScreen({
    super.key,
    required this.items,
    required this.total,
    required this.customerName,
    required this.paymentMethod,
    required this.dateTime,
    required this.billNumber,
  });

  Future<void> _shareBill() async {
    try {
      final businessInfo = await BusinessInfo.load();
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (context) => _buildReceiptPdf(businessInfo),
        ),
      );
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/Bill_$billNumber.pdf");
      await file.writeAsBytes(await pdf.save());
      await Share.shareFiles([file.path], text: 'Bill #$billNumber');
    } catch (e) {
      print('Error sharing bill: $e');
    }
  }

  Future<void> _printReceipt() async {
    final businessInfo = await BusinessInfo.load();
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => _buildReceiptPdf(businessInfo),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _buildReceiptPdf(BusinessInfo businessInfo) {
    final subtotal = items.fold(0.0, (sum, item) => sum + item.total);
    final taxRate = double.tryParse(businessInfo.taxRate) ?? 0.0;
    final taxAmount = subtotal * (taxRate / 100);
    final grandTotal = subtotal + taxAmount;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Center(
          child: pw.Container(
            width: 60,
            height: 60,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Center(
              child: pw.Icon(
                pw.IconData(0xe3af),
                size: 38,
                color: PdfColors.black,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            businessInfo.name,
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.5,
              color: PdfColors.black,
            ),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            businessInfo.address,
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 15,
              color: PdfColors.grey800,
            ),
          ),
        ),
        pw.Center(
          child: pw.Text(
            'Tel: ${businessInfo.phone}',
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 15,
              color: PdfColors.grey800,
            ),
          ),
        ),
        if (businessInfo.email.isNotEmpty)
          pw.Center(
            child: pw.Text(
              'Email: ${businessInfo.email}',
              style: pw.TextStyle(
                font: pw.Font.courier(),
                fontSize: 15,
                color: PdfColors.grey800,
              ),
            ),
          ),
        pw.SizedBox(height: 8),
        _asciiDividerPdf(),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Bill #: ${billNumber.toString().padLeft(6, '0')}',
              style: pw.TextStyle(
                font: pw.Font.courier(),
                fontSize: 15,
                color: PdfColors.black,
              ),
            ),
            pw.Text(
              _formatDate(dateTime),
              style: pw.TextStyle(
                font: pw.Font.courier(),
                fontSize: 15,
                color: PdfColors.black,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Text(
              'Customer: ',
              style: pw.TextStyle(
                font: pw.Font.courier(),
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                customerName,
                style: pw.TextStyle(
                  font: pw.Font.courier(),
                  fontSize: 15,
                  color: PdfColors.black,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Text(
              'Payment: ',
              style: pw.TextStyle(
                font: pw.Font.courier(),
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.Text(
              paymentMethod,
              style: pw.TextStyle(
                font: pw.Font.courier(),
                fontSize: 15,
                color: PdfColors.black,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Subtotal:',
              style: pw.TextStyle(font: pw.Font.courier(), fontSize: 15),
            ),
            pw.Text(
              '${businessInfo.currency} ${subtotal.toStringAsFixed(2)}',
              style: pw.TextStyle(font: pw.Font.courier(), fontSize: 15),
            ),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Tax (${businessInfo.taxRate}%):',
              style: pw.TextStyle(font: pw.Font.courier(), fontSize: 15),
            ),
            pw.Text(
              '${businessInfo.currency} ${taxAmount.toStringAsFixed(2)}',
              style: pw.TextStyle(font: pw.Font.courier(), fontSize: 15),
            ),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Total:',
              style: pw.TextStyle(
                font: pw.Font.courier(),
                fontWeight: pw.FontWeight.bold,
                fontSize: 16,
              ),
            ),
            pw.Text(
              '${businessInfo.currency} ${grandTotal.toStringAsFixed(2)}',
              style: pw.TextStyle(
                font: pw.Font.courier(),
                fontWeight: pw.FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        _asciiDividerPdf(),
        // Items Table
        pw.Container(
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.grey500, width: 1.2),
          ),
          child: pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey500, width: 1.2),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(2),
            },
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: pw.Text(
                      'ITEM',
                      style: pw.TextStyle(
                        font: pw.Font.courier(),
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      'QTY',
                      style: pw.TextStyle(
                        font: pw.Font.courier(),
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      'AMOUNT',
                      style: pw.TextStyle(
                        font: pw.Font.courier(),
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                ],
              ),
              ...items.map(
                (item) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            item.name,
                            style: pw.TextStyle(
                              font: pw.Font.courier(),
                              fontSize: 15,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '@ Rs ${item.price.toStringAsFixed(0)} each',
                            style: pw.TextStyle(
                              font: pw.Font.courier(),
                              fontSize: 15,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Center(
                      child: pw.Text(
                        item.quantity.toStringAsFixed(0),
                        style: pw.TextStyle(
                          font: pw.Font.courier(),
                          fontSize: 14,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    pw.Center(
                      child: pw.Text(
                        'Rs ${item.total.toStringAsFixed(0)}',
                        style: pw.TextStyle(
                          font: pw.Font.courier(),
                          fontSize: 15,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Container(height: 1.5, color: PdfColors.grey500),
        pw.SizedBox(height: 10),
        // Totals Section
        pw.Container(
          color: PdfColors.grey100,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: pw.Column(
            children: [
              _buildTotalRowPdf('Subtotal:', total, isBold: false),
              _buildTotalRowPdf('Tax (16%):', total * 0.16, isBold: false),
              _buildTotalRowPdf('Discount:', 0, isBold: false),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        font: pw.Font.courier(),
                        fontSize: 21,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.Text(
                      'Rs${(total * 1.16).toStringAsFixed(0)}',
                      style: pw.TextStyle(
                        font: pw.Font.courier(),
                        fontSize: 21,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        _asciiDividerPdf(),
        pw.SizedBox(height: 10),
        // Payment Info
        pw.Row(
          children: [
            pw.Text(
              'Paid by: ',
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
        if (paymentMethod.toLowerCase().contains('card'))
          pw.Text(
            'Card: **** 1234',
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 13,
              color: PdfColors.grey600,
            ),
          ),
        if (paymentMethod.toLowerCase() == 'cash')
          pw.Text(
            'Change Due: Rs 0',
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 13,
              color: PdfColors.grey600,
            ),
          ),
        pw.SizedBox(height: 10),
        _asciiDividerPdf(),
        pw.SizedBox(height: 16),
        // Thank You Stamp
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              border: pw.Border.all(color: PdfColors.green700, width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'PAID - THANK YOU!',
              style: pw.TextStyle(
                font: pw.Font.courier(),
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 16),
        // Barcode
        pw.Center(
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data: 'BILL${billNumber.toString().padLeft(6, '0')}',
            width: 180,
            height: 56,
            drawText: true,
            textStyle: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 14,
              color: PdfColors.black,
            ),
            color: PdfColors.black,
            backgroundColor: PdfColors.white,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text(
            'Scan for digital copy',
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 13,
              color: PdfColors.grey800,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        _asciiDividerPdf(),
        pw.SizedBox(height: 10),
        // Signature line
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Container(height: 1, color: PdfColors.grey400),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'Signature',
              style: pw.TextStyle(
                font: pw.Font.courier(),
                fontSize: 12,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Container(height: 1, color: PdfColors.grey400),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        // Support/Thank you section
        pw.Center(
          child: pw.Text(
            'Support: ${businessInfo.phone}',
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 13,
              color: PdfColors.black,
            ),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'Thank you for shopping with us!',
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        _asciiDividerPdf(),
        pw.SizedBox(height: 10),
        // Footer
        pw.Center(
          child: pw.Text(
            'Items once sold cannot be returned.',
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 15,
              color: PdfColors.grey800,
            ),
          ),
        ),
        pw.Center(
          child: pw.Text(
            'For support: (123) 456-7890',
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 15,
              color: PdfColors.grey800,
            ),
          ),
        ),
        pw.Center(
          child: pw.Text(
            'Have a great day!',
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 15,
              color: PdfColors.grey800,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        _asciiDividerPdf(),
        pw.SizedBox(height: 6),
        // Cut line
        pw.Center(
          child: pw.Text(
            '------------------------------------------',
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 13,
              color: PdfColors.grey400,
            ),
          ),
        ),
        pw.Center(
          child: pw.Text(
            'cut here',
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 10,
              color: PdfColors.grey400,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _asciiDividerPdf() {
    return pw.Center(
      child: pw.Text(
        '------------------------------------------',
        style: pw.TextStyle(
          font: pw.Font.courier(),
          fontSize: 13,
          color: PdfColors.grey700,
        ),
      ),
    );
  }

  pw.Widget _buildTotalRowPdf(
    String label,
    double amount, {
    bool isBold = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: pw.Font.courier(),
            fontSize: 14,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          'Rs${amount.toStringAsFixed(0)}',
          style: pw.TextStyle(
            font: pw.Font.courier(),
            fontSize: 14,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dateTime) {
    // Implement date formatting logic based on the dateTime
    return dateTime.toString();
  }

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
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            backgroundColor: Colors.white,
            title: Text(
              'Bill #${billNumber.toString().padLeft(6, '0')}',
              style: const TextStyle(fontSize: 18, color: Color(0xFF0A2342)),
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Color(0xFF0A2342),
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.print, color: Color(0xFF0A2342)),
                onPressed: _printReceipt,
              ),
              IconButton(
                icon: const Icon(Icons.share, color: Color(0xFF0A2342)),
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
                      color: Colors.grey.withAlpha(76),
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
                  businessInfo: businessInfo,
                  discount: (businessInfo.enableDiscounts
                      ? (businessInfo.defaultDiscount ?? 0.0)
                      : 0.0),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
