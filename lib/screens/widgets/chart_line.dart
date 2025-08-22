import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LineChartWidget extends StatefulWidget {
  final List<FlSpot> spots;
  final List<String> labels;
  final String legend;
  final Color color;
  final double maxY;

  const LineChartWidget({
    Key? key,
    required this.spots,
    required this.labels,
    this.legend = 'Sales',
    this.color = Colors.blue,

    this.maxY = 100,
  }) : super(key: key);

  @override
  State<LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<LineChartWidget> {
  late ScrollController _scrollController;
  double _zoomLevel = 1.0;
  double _minZoom = 0.3; // More aggressive minimum zoom
  double _maxZoom = 3.0;

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
          final chartWidth = ((widget.labels.length + 2) * 50.0).clamp(
            400.0,
            1200.0,
          );
          final padding = (chartWidth * 0.15).clamp(
            60.0,
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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel + 0.2).clamp(_minZoom, _maxZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel - 0.2).clamp(_minZoom, _maxZoom);
    });
  }

  void _resetZoom() {
    setState(() {
      _zoomLevel = 1.0;
    });
  }

  // Get font size based on zoom level
  double _getFontSize(double baseSize) {
    if (_zoomLevel <= 0.5) return baseSize * 0.7;
    if (_zoomLevel <= 0.8) return baseSize * 0.8;
    if (_zoomLevel <= 1.2) return baseSize;
    return baseSize * 1.1;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey.shade300 : Colors.grey.shade600;
    final gridColor = const Color(
      0xFF1976D2,
    ).withOpacity(0.25); // More visible blue grid
    final bgGradient = LinearGradient(
      colors: isDark
          ? [const Color(0xFF1A1A1A), const Color(0xFF232D36)]
          : [
              const Color.fromARGB(255, 244, 247, 250),
              const Color.fromARGB(255, 228, 240, 253),
            ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    // Calculate maxY as 1.1x the max value, minY as 0
    final maxY = widget.spots.isEmpty
        ? 100.0
        : (widget.spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.1)
              .ceilToDouble();

    // Calculate chart width based on zoom level - make it more compact when zoomed out
    final baseWidth = (widget.labels.length + 1) * 50.0;
    final chartWidth = (baseWidth * _zoomLevel).clamp(400.0, 1200.0);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280, maxHeight: 320),
      padding: const EdgeInsets.all(0), // Remove extra padding
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(0), // No outer rounding
        border: Border.all(color: Colors.transparent, width: 0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4.0,
                    horizontal: 6.0,
                  ),
                  child: Text(
                    widget.legend,
                    style: GoogleFonts.poppins(
                      fontSize: _getFontSize(15),
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Zoom controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _zoomOut,
                    icon: Icon(
                      Icons.zoom_out,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                      size: 18,
                    ),
                    tooltip: 'Zoom Out',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    child: Text(
                      '${(_zoomLevel * 100).toInt()}%',
                      style: GoogleFonts.poppins(
                        fontSize: _getFontSize(11),
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: _zoomIn,
                    icon: Icon(
                      Icons.zoom_in,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                      size: 18,
                    ),
                    tooltip: 'Zoom In',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                  if (_zoomLevel != 1.0)
                    IconButton(
                      onPressed: _resetZoom,
                      icon: Icon(
                        Icons.refresh,
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                        size: 16,
                      ),
                      tooltip: 'Reset Zoom',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 400,
                  maxWidth: chartWidth,
                ),
                child: Container(
                  width: 1200,
                  height: 340,
                  // Add extra right padding so the last X-axis label (e.g., dates like "Aug 15") doesn't get clipped
                  padding: const EdgeInsets.fromLTRB(8, 8, 28, 8),
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                        verticalInterval: 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: gridColor,
                            strokeWidth: 1.5,
                            dashArray: [6, 4],
                          );
                        },
                        getDrawingVerticalLine: (value) => FlLine(
                          color: gridColor,
                          strokeWidth: 1.5,
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
                                ),
                                child: Text(
                                  value.toInt().toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: _getFontSize(9),
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
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
                              if (idx >= 0 && idx < widget.labels.length) {
                                // Show days as Mon, Tue, etc. if label is a date
                                final label = widget.labels[idx];
                                String dayLabel = label;
                                try {
                                  final date = DateTime.tryParse(label);
                                  if (date != null) {
                                    dayLabel = [
                                      'Mon',
                                      'Tue',
                                      'Wed',
                                      'Thu',
                                      'Fri',
                                      'Sat',
                                      'Sun',
                                    ][date.weekday - 1];
                                  }
                                } catch (_) {}
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 4,
                                  ),
                                  child: Text(
                                    dayLabel,
                                    style: GoogleFonts.poppins(
                                      fontSize: _getFontSize(9),
                                      color: textColor,
                                      fontWeight: FontWeight.w500,
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
                        show: false,
                        border: Border.all(color: Colors.transparent, width: 0),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: widget.spots,
                          isCurved: true,
                          color: widget.color,
                          barWidth: _zoomLevel <= 0.8 ? 2 : 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: _zoomLevel <= 0.8 ? 3 : 5,
                                color: widget.color,
                                strokeWidth: 2,
                                strokeColor: isDark
                                    ? const Color(0xFF1A1A1A)
                                    : Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                widget.color.withAlpha((0.3 * 255).toInt()),
                                widget.color.withAlpha((0.1 * 255).toInt()),
                                Colors.transparent,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.7, 1.0],
                            ),
                          ),
                          shadow: Shadow(
                            blurRadius: 8,
                            color: widget.color.withAlpha((0.3 * 255).toInt()),
                            offset: const Offset(0, 4),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        handleBuiltInTouches: true,
                        touchSpotThreshold: 20,
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: isDark
                              ? const Color(0xFF2A2A2A)
                              : Colors.white,
                          tooltipRoundedRadius: 8,
                          tooltipPadding: const EdgeInsets.all(8),
                          tooltipBorder: BorderSide(
                            color: widget.color.withAlpha((0.3 * 255).toInt()),
                            width: 1,
                          ),
                          tooltipMargin: 2, // Reduced margin
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final idx = spot.x.toInt();
                              if (idx < 0 || idx >= widget.labels.length)
                                return null;
                              // Show days as Mon, Tue, etc. in tooltip
                              String dayLabel = widget.labels[idx];
                              try {
                                final date = DateTime.tryParse(
                                  widget.labels[idx],
                                );
                                if (date != null) {
                                  dayLabel = [
                                    'Mon',
                                    'Tue',
                                    'Wed',
                                    'Thu',
                                    'Fri',
                                    'Sat',
                                    'Sun',
                                  ][date.weekday - 1];
                                }
                              } catch (_) {}
                              return LineTooltipItem(
                                '$dayLabel\n',
                                GoogleFonts.poppins(
                                  color: textColor,
                                  fontSize: _getFontSize(10),
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  TextSpan(
                                    text: '${spot.y.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      color: widget.color,
                                      fontSize: _getFontSize(13),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
