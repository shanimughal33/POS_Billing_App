import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class KpiCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final double percentChange;
  final bool isUp;
  final Color? color;

  const KpiCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.percentChange,
    required this.isUp,
    this.color,
  }) : super(key: key);

  @override
  State<KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<KpiCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
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

  Color _getKpiIconColor(String title) {
    switch (title.toLowerCase()) {
      case 'total sales':
      case 'sales':
        return Color(0xFF1976D2); // Blue
      case 'purchase':
      case 'total purchase':
        return Color(0xFF8B5CF6); // Purple
      case 'expense':
      case 'total expenses':
        return Color(0xFFF59E0B); // Orange
      case 'people':
      case 'total people':
        return Color(0xFF10B981); // Green
      default:
        return Color(0xFF1976D2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Define colors based on theme
    final Color upColor = const Color(0xFF10B981); // Emerald
    final Color downColor = const Color(0xFFEF4444); // Red
    final Color cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final Color iconBgColor = widget.color ?? _getKpiIconColor(widget.title);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(6), // Less rounded for a more square look
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: iconBgColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    // Add haptic feedback
                    HapticFeedback.lightImpact();
                    // TODO: Navigate to detailed view
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with icon and trend
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Icon container
                            Icon(widget.icon, color: iconBgColor, size: 28),
                            // Trend indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    (widget.isUp ? upColor : downColor)
                                        .withAlpha((0.15 * 255).toInt()),
                                    (widget.isUp ? upColor : downColor)
                                        .withAlpha((0.05 * 255).toInt()),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (widget.isUp ? upColor : downColor)
                                      .withAlpha((0.4 * 255).toInt()),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (widget.isUp ? upColor : downColor)
                                        .withAlpha((0.2 * 255).toInt()),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.isUp
                                        ? Icons.trending_up_rounded
                                        : Icons.trending_down_rounded,
                                    color: widget.isUp ? upColor : downColor,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${widget.percentChange.abs().toStringAsFixed(1)}%',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: widget.isUp ? upColor : downColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Title
                        Text(
                          widget.title,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Value
                        Text(
                          widget.value,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Subtle indicator line
                        const SizedBox(height: 16),
                        Container(
                          height: 4,
                          width: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                iconBgColor.withAlpha((0.7 * 255).toInt()),
                                iconBgColor.withAlpha((0.4 * 255).toInt()),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(
                                color: iconBgColor.withAlpha(
                                  (0.3 * 255).toInt(),
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
