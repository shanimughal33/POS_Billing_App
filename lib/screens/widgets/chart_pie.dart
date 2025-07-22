import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PieChartWidget extends StatelessWidget {
  final List<PieChartSectionData> sections;
  final List<String> labels;
  final List<Color> colors;
  final String title;

  const PieChartWidget({
    Key? key,
    required this.sections,
    required this.labels,
    required this.colors,
    this.title = 'Sales by Category',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey.shade300 : Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Chart title
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // Pie chart
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
                borderData: FlBorderData(show: false),
                pieTouchData: PieTouchData(
                  enabled: true,
                  touchCallback: (event, response) {},
                  mouseCursorResolver: (event, response) {
                    return response == null || response.touchedSection == null
                        ? SystemMouseCursors.basic
                        : SystemMouseCursors.click;
                  },
                ),
              ),
              swapAnimationDuration: const Duration(milliseconds: 800),
              swapAnimationCurve: Curves.easeInOutCubic,
            ),
          ),
          const SizedBox(height: 12),

          // Enhanced legend
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Breakdown',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: List.generate(
                    labels.length,
                    (i) => _buildLegendItem(labels[i], colors[i], textColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).toInt()),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withAlpha((0.3 * 255).toInt()),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha((0.3 * 255).toInt()),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
