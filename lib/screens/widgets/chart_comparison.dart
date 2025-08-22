import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ComparisonChartWidget extends StatefulWidget {
  final List<FlSpot> salesData;
  final List<FlSpot> purchaseData;
  final List<String> labels;
  final Color salesColor;
  final Color purchaseColor;
  final bool showZoomControlsBelow;

  const ComparisonChartWidget({
    super.key,
    required this.salesData,
    required this.purchaseData,
    required this.labels,
    this.salesColor = const Color(0xFF25D366), // WhatsApp green
    this.purchaseColor = const Color(0xFF128C7E), // WhatsApp dark green
    this.showZoomControlsBelow = false,
  });

  // Static builder for display-only filter chips
  static Widget buildFilterChipStatic(BuildContext context, String label) {
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
          fontSize: 13,
          letterSpacing: 1.1,
        ),
      ),
      selected: false,
      selectedColor: const Color(0xFF1976D2),
      backgroundColor: Colors.grey[200],
      onSelected: null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
      pressElevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    );
  }

  @override
  State<ComparisonChartWidget> createState() => _ComparisonChartWidgetState();
}

class _ComparisonChartWidgetState extends State<ComparisonChartWidget> {
  late ScrollController _scrollController;
  // Remove _zoomLevel, _minZoom, _maxZoom, and all zoom functions

  // Filter state
  String _selectedFilter = 'Daily';

  List<FlSpot> get _filteredSalesData {
    if (_selectedFilter == 'Daily') return widget.salesData;
    if (_selectedFilter == 'Weekly') {
      // Group every 7 days
      List<FlSpot> result = [];
      for (int i = 0; i < widget.salesData.length; i += 7) {
        double sum = 0;
        for (int j = i; j < i + 7 && j < widget.salesData.length; j++) {
          sum += widget.salesData[j].y;
        }
        result.add(FlSpot((i / 7).toDouble(), sum));
      }
      return result;
    }
    if (_selectedFilter == 'Monthly') {
      // Group every 30 days
      List<FlSpot> result = [];
      for (int i = 0; i < widget.salesData.length; i += 30) {
        double sum = 0;
        for (int j = i; j < i + 30 && j < widget.salesData.length; j++) {
          sum += widget.salesData[j].y;
        }
        result.add(FlSpot((i / 30).toDouble(), sum));
      }
      return result;
    }
    return widget.salesData;
  }

  List<FlSpot> get _filteredPurchaseData {
    if (_selectedFilter == 'Daily') return widget.purchaseData;
    if (_selectedFilter == 'Weekly') {
      List<FlSpot> result = [];
      for (int i = 0; i < widget.purchaseData.length; i += 7) {
        double sum = 0;
        for (int j = i; j < i + 7 && j < widget.purchaseData.length; j++) {
          sum += widget.purchaseData[j].y;
        }
        result.add(FlSpot((i / 7).toDouble(), sum));
      }
      return result;
    }
    if (_selectedFilter == 'Monthly') {
      List<FlSpot> result = [];
      for (int i = 0; i < widget.purchaseData.length; i += 30) {
        double sum = 0;
        for (int j = i; j < i + 30 && j < widget.purchaseData.length; j++) {
          sum += widget.purchaseData[j].y;
        }
        result.add(FlSpot((i / 30).toDouble(), sum));
      }
      return result;
    }
    return widget.purchaseData;
  }

  List<String> get _filteredLabels {
    if (_selectedFilter == 'Daily') return widget.labels;
    if (_selectedFilter == 'Weekly') {
      List<String> result = [];
      for (int i = 0; i < widget.labels.length; i += 7) {
        result.add(widget.labels[i]);
      }
      return result;
    }
    if (_selectedFilter == 'Monthly') {
      List<String> result = [];
      for (int i = 0; i < widget.labels.length; i += 30) {
        result.add(widget.labels[i]);
      }
      return result;
    }
    return widget.labels;
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Auto-scroll to the latest date (rightmost point) after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && widget.labels.isNotEmpty) {
        // Calculate the position to scroll to show the latest date with substantial padding
        final maxScrollExtent = _scrollController.position.maxScrollExtent;
        if (maxScrollExtent > 0) {
          // Calculate padding based on chart width to ensure tooltip visibility
          final chartWidth = ((widget.labels.length + 2) * 60.0).clamp(
            500.0,
            1200.0,
          );
          final padding = (chartWidth * 0.15).clamp(
            75.0,
            150.0,
          ); // Reduced padding
          final scrollPosition = maxScrollExtent - padding;
          _scrollController.animateTo(
            scrollPosition > 0 ? scrollPosition : maxScrollExtent,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant ComparisonChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the labels changed (data refreshed), auto-scroll again
    if (widget.labels.length != oldWidget.labels.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && widget.labels.isNotEmpty) {
          final maxScrollExtent = _scrollController.position.maxScrollExtent;
          if (maxScrollExtent > 0) {
            final chartWidth = ((widget.labels.length + 2) * 60.0).clamp(
              500.0,
              1200.0,
            );
            final padding = (chartWidth * 0.15).clamp(75.0, 150.0);
            final scrollPosition = maxScrollExtent - padding;
            _scrollController.animateTo(
              scrollPosition > 0 ? scrollPosition : maxScrollExtent,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Remove all unused zoom functions and state

  // Get font size based on zoom level
  double _getFontSize(double baseSize) {
    // Remove all unused zoom functions and state
    return baseSize * 1.1;
  }

  double _getMaxY() {
    final allValues = <double>[];
    allValues.addAll(widget.salesData.map((spot) => spot.y));
    allValues.addAll(widget.purchaseData.map((spot) => spot.y));

    if (allValues.isEmpty) return 100.0;

    final maxValue = allValues.reduce((a, b) => a > b ? a : b);
    // Add more headroom to prevent top clipping
    return maxValue + (maxValue * 0.25) + 8;
  }

  double _getMinY() {
    final allValues = <double>[];
    allValues.addAll(widget.salesData.map((spot) => spot.y));
    allValues.addAll(widget.purchaseData.map((spot) => spot.y));
    if (allValues.isEmpty) return 0.0;
    final minValue = allValues.reduce((a, b) => a < b ? a : b);
    final minY = (minValue * 0.9).floorToDouble();
    return minY < 0 ? 0 : minY;
  }

  Widget _buildLegendDot(Color color) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey.shade300 : Colors.grey.shade600;
    final gridColor = Colors.grey[600]!; // More visible, darker grey
    final salesLineColor = const Color(0xFF1976D2);
    final purchaseLineColor = const Color(0xFF128C7E);
    final bgGradient = LinearGradient(
      colors: isDark
          ? [const Color(0xFF1A1A1A), const Color(0xFF232D36)]
          : [const Color(0xFFF8FBFF), const Color(0xFFEAF1FB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final minY = _getMinY();
    final maxY = _getMaxY();
    final baseWidth = (_filteredLabels.length + 1) * 60.0;
    final chartWidth = baseWidth.clamp(600.0, 1200.0);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 360, maxHeight: 400),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16), // Increased padding
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 600,
            maxWidth: chartWidth,
          ),
          child: Container(
            width: chartWidth,
            height: 300,
            padding: const EdgeInsets.fromLTRB(20, 16, 40, 20),
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: gridColor,
                    strokeWidth: 1.4,
                    dashArray: [6, 4],
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: gridColor,
                    strokeWidth: 1.2,
                    dashArray: [3, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50, // Increased to prevent clipping
                      interval: maxY > 0 ? maxY / 4 : 1,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            right: 8,
                            left: 4,
                            top: 4,
                            bottom: 4,
                          ),
                          child: Text(
                            value.toInt().toString(),
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: textColor,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30, // Increased for better spacing
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < _filteredLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(
                              _filteredLabels[idx],
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: gridColor, width: 1.2),
                    left: BorderSide(color: gridColor, width: 1.2),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true, // Enables pinch zoom
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.white,
                    tooltipRoundedRadius: 8,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    tooltipBorder: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    getTooltipItems: (touchedSpots) {
                      if (touchedSpots.isEmpty) return [];
                      // Show both sales and purchase values at the touched index
                      final List<LineTooltipItem> items = [];
                      for (final spot in touchedSpots) {
                        final isSales = spot.barIndex == 0;
                        final label = isSales ? 'Sales' : 'Purchase';
                        final color = isSales
                            ? salesLineColor
                            : purchaseLineColor;
                        items.add(
                          LineTooltipItem(
                            '$label: ',
                            GoogleFonts.montserrat(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 13,
                            ),
                            children: [
                              TextSpan(
                                text: spot.y.toStringAsFixed(2),
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return items;
                    },
                  ),
                ),
                lineBarsData: [
                  // Sales line
                  LineChartBarData(
                    spots: _filteredSalesData,
                    isCurved: false,
                    color: salesLineColor,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: salesLineColor,
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                  ),
                  // Purchase line
                  LineChartBarData(
                    spots: _filteredPurchaseData,
                    isCurved: false,
                    color: purchaseLineColor,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: purchaseLineColor,
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
