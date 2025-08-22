import 'package:flutter/material.dart';
import 'light_theme.dart';
import 'dark_theme.dart';

// Export theme classes for direct access
export 'light_theme.dart';
export 'dark_theme.dart';

class AppTheme {
  // Theme instances
  static final LightTheme lightTheme = LightTheme();
  static final DarkTheme darkTheme = DarkTheme();

  // Get theme data based on brightness
  static ThemeData getThemeData(Brightness brightness) {
    return brightness == Brightness.light
        ? LightTheme.themeData
        : DarkTheme.themeData;
  }

  // Get colors based on current theme context
  static ColorScheme getColorScheme(BuildContext context) {
    return Theme.of(context).colorScheme;
  }

  // Get text theme based on current theme context
  static TextTheme getTextTheme(BuildContext context) {
    return Theme.of(context).textTheme;
  }

  // Get primary color based on current theme context
  static Color getPrimaryColor(BuildContext context) {
    return Theme.of(context).primaryColor;
  }

  // Get background color based on current theme context
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  // Get card color based on current theme context
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).cardColor;
  }

  // Get text color based on current theme context
  static Color getTextColor(BuildContext context) {
    return Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
  }

  // Get secondary text color based on current theme context
  static Color getSecondaryTextColor(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
  }

  // Get border color based on current theme context
  static Color getBorderColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? DarkTheme.borderLight : LightTheme.borderLight;
  }

  // Get input background color based on current theme context
  static Color getInputBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? DarkTheme.inputBackground : LightTheme.inputBackground;
  }

  // Get cursor color based on current theme context
  static Color getCursorColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? DarkTheme.cursorColor : LightTheme.cursorColor;
  }

  // Get success color
  static Color getSuccessColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? DarkTheme.success : LightTheme.success;
  }

  // Get error color
  static Color getErrorColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? DarkTheme.error : LightTheme.error;
  }

  // Get warning color
  static Color getWarningColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? DarkTheme.warning : LightTheme.warning;
  }

  // Get info color
  static Color getInfoColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? DarkTheme.info : LightTheme.info;
  }

  // Get card decoration based on current theme context
  static BoxDecoration getCardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? DarkTheme.cardDecoration : LightTheme.cardDecoration;
  }

  // Get elevated card decoration based on current theme context
  static BoxDecoration getElevatedCardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? DarkTheme.elevatedCardDecoration
        : LightTheme.elevatedCardDecoration;
  }

  // Get input decoration theme based on current theme context
  static InputDecorationTheme getInputDecorationTheme(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? DarkTheme.inputDecorationTheme
        : LightTheme.inputDecorationTheme;
  }

  // Get standardized input decoration for forms
  static InputDecoration getStandardInputDecoration(
    BuildContext context, {
    required String labelText,
    required String hintText,
    IconData? prefixIcon,
    IconData? suffixIcon,
    VoidCallback? onSuffixIconTap,
    bool isDropdown = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? DarkTheme.getStandardInputDecoration(
            labelText: labelText,
            hintText: hintText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            onSuffixIconTap: onSuffixIconTap,
            isDropdown: isDropdown,
          )
        : LightTheme.getStandardInputDecoration(
            labelText: labelText,
            hintText: hintText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            onSuffixIconTap: onSuffixIconTap,
            isDropdown: isDropdown,
          );
  }

  // Get standardized save button style
  static ButtonStyle getStandardSaveButtonStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? DarkTheme.standardSaveButtonStyle
        : LightTheme.standardSaveButtonStyle;
  }

  // Get standardized cancel button style
  static ButtonStyle getStandardCancelButtonStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? DarkTheme.standardCancelButtonStyle
        : LightTheme.standardCancelButtonStyle;
  }

  // Get gradient save button style (like home screen total container)
  static ButtonStyle getGradientSaveButtonStyle(BuildContext context) {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25), // More round (was 20)
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 31,
        vertical: 11,
      ), // Reduced by 1% (was 32, 12)
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
    );
  }

  // Get gradient decoration for save buttons
  static BoxDecoration getGradientDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0A2342), Color(0xFF123060), Color(0xFF1976D2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(25), // More round (was 20)
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.12),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Get primary button style based on current theme context
  static ButtonStyle getPrimaryButtonStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? DarkTheme.primaryButtonStyle
        : LightTheme.primaryButtonStyle;
  }

  // Get secondary button style based on current theme context
  static ButtonStyle getSecondaryButtonStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? DarkTheme.secondaryButtonStyle
        : LightTheme.secondaryButtonStyle;
  }

  // Get text button style based on current theme context
  static ButtonStyle getTextButtonStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? DarkTheme.textButtonStyle : LightTheme.textButtonStyle;
  }

  // Check if current theme is dark
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // Get shadow color based on current theme context
  static Color getShadowColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? DarkTheme.shadowMedium : LightTheme.shadowMedium;
  }

  // Get surface color based on current theme context
  static Color getSurfaceColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? DarkTheme.surfaceBackground : LightTheme.surfaceBackground;
  }
}
