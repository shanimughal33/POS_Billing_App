import 'package:flutter/material.dart';

class ExportButtonsWidget extends StatelessWidget {
  final VoidCallback? onExportPdf;
  final VoidCallback? onExportExcel;

  const ExportButtonsWidget({Key? key, this.onExportPdf, this.onExportExcel})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: onExportPdf,
          icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
          label: const Text('PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: onExportExcel,
          icon: const Icon(Icons.grid_on, color: Colors.green),
          label: const Text('Excel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
      ],
    );
  }
}
