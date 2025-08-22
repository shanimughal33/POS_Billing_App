import 'package:flutter/material.dart';

class LightTheme {
  // Primary Colors
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color primaryBlueDark = Color(0xFF1565C0);
  static const Color primaryBlueLight = Color(0xFF42A5F5);

  // Background Colors
  static const Color scaffoldBackground = Colors.white;
  static const Color cardBackground = Colors.white;
  static const Color surfaceBackground = Color(0xFFF8F9FA);
  static const Color inputBackground = Color(0xFFF5F6FA);

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  static const Color textInverse = Colors.white;

  // Border Colors
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderMedium = Color(0xFFCCCCCC);
  static const Color borderDark = Color(0xFF999999);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Neutral Colors
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);

  // Shadow Colors
  static const Color shadowLight = Color(0x0A000000);
  static const Color shadowMedium = Color(0x1A000000);
  static const Color shadowDark = Color(0x33000000);

  // Cursor Color
  static const Color cursorColor = primaryBlue;

  // Text Styles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.25,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.25,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.1,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    letterSpacing: 0.15,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    letterSpacing: 0.25,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    letterSpacing: 0.4,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.5,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textTertiary,
    letterSpacing: 0.5,
  );

  // Button Styles
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryBlue,
    foregroundColor: textInverse,
    elevation: 2,
    shadowColor: shadowMedium,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    textStyle: labelLarge.copyWith(fontWeight: FontWeight.w600),
  );

  static final ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: primaryBlue,
    elevation: 0,
    side: const BorderSide(color: primaryBlue, width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    textStyle: labelLarge.copyWith(fontWeight: FontWeight.w600),
  );

  static final ButtonStyle textButtonStyle = TextButton.styleFrom(
    foregroundColor: primaryBlue,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    textStyle: labelMedium.copyWith(fontWeight: FontWeight.w500),
  );

  // Input Decoration Theme
  static final InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: inputBackground,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: borderLight, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: borderLight, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: primaryBlue, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: error, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    labelStyle: labelMedium.copyWith(color: textSecondary),
    hintStyle: bodyMedium.copyWith(color: textTertiary),
    errorStyle: bodySmall.copyWith(color: error),
  );

  // Standardized Input Form Decoration (for dialog forms)
  static InputDecoration getStandardInputDecoration({
    required String labelText,
    required String hintText,
    IconData? prefixIcon,
    IconData? suffixIcon,
    VoidCallback? onSuffixIconTap,
    bool isDropdown = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: primaryBlue)
          : null,
      suffixIcon: suffixIcon != null
          ? GestureDetector(
              onTap: onSuffixIconTap,
              child: Icon(suffixIcon, color: primaryBlue),
            )
          : null,
      filled: true,
      fillColor: inputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: isDropdown
            ? BorderSide.none
            : const BorderSide(color: borderLight, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: isDropdown
            ? BorderSide.none
            : const BorderSide(color: borderLight, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: isDropdown
            ? BorderSide.none
            : const BorderSide(color: primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: labelLarge.copyWith(color: textSecondary, fontSize: 16),
      hintStyle: bodyLarge.copyWith(color: textTertiary, fontSize: 16),
      errorStyle: bodyMedium.copyWith(color: error, fontSize: 14),
    );
  }

  // Standardized Button Style for Save/Submit buttons
  static final ButtonStyle standardSaveButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: textInverse,
    elevation: 2,
    shadowColor: shadowMedium,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(25), // More round (was 20)
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: 31,
      vertical: 11,
    ), // Reduced by 1% (was 32, 12)
    textStyle: labelLarge.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
  );

  // Standardized Cancel Button Style
  static final ButtonStyle standardCancelButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: primaryBlue,
    elevation: 0,
    side: const BorderSide(color: primaryBlue, width: 1.5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(25), // More round (was 12)
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: 31,
      vertical: 11,
    ), // Reduced by 1% (was 32, 12)
    textStyle: labelLarge.copyWith(fontWeight: FontWeight.w600),
  );

  // Card Decoration
  static final BoxDecoration cardDecoration = BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: borderLight, width: 1),
    boxShadow: [
      BoxShadow(color: shadowLight, blurRadius: 8, offset: const Offset(0, 2)),
    ],
  );

  static final BoxDecoration elevatedCardDecoration = BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: shadowMedium,
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // App Bar Theme
  static const AppBarTheme appBarTheme = AppBarTheme(
    backgroundColor: scaffoldBackground,
    foregroundColor: textPrimary,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: titleLarge,
    iconTheme: IconThemeData(color: textPrimary, size: 24),
    actionsIconTheme: IconThemeData(color: textPrimary, size: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
    ),
  );

  // Bottom Navigation Bar Theme
  static const BottomNavigationBarThemeData bottomNavigationBarTheme =
      BottomNavigationBarThemeData(
        backgroundColor: cardBackground,
        selectedItemColor: primaryBlue,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: labelSmall,
        unselectedLabelStyle: labelSmall,
      );

  // Floating Action Button Theme
  static const FloatingActionButtonThemeData floatingActionButtonTheme =
      FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: textInverse,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      );

  // Icon Theme
  static const IconThemeData iconTheme = IconThemeData(
    color: textPrimary,
    size: 24,
  );

  // Divider Theme
  static const DividerThemeData dividerTheme = DividerThemeData(
    color: borderLight,
    thickness: 1,
    space: 1,
  );

  // Chip Theme
  static final ChipThemeData chipTheme = ChipThemeData(
    backgroundColor: grey100,
    selectedColor: primaryBlue,
    disabledColor: grey200,
    labelStyle: labelSmall,
    secondaryLabelStyle: labelSmall.copyWith(color: textInverse),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );

  // Snackbar Theme
  static final SnackBarThemeData snackBarTheme = SnackBarThemeData(
    backgroundColor: grey800,
    contentTextStyle: bodyMedium.copyWith(color: textInverse),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    behavior: SnackBarBehavior.floating,
  );

  // Dialog Theme
  static final DialogThemeData dialogTheme = DialogThemeData(
    backgroundColor: cardBackground,
    elevation: 8,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    titleTextStyle: titleLarge,
    contentTextStyle: bodyMedium,
  );

  // Bottom Sheet Theme
  static final BottomSheetThemeData bottomSheetTheme = BottomSheetThemeData(
    backgroundColor: cardBackground,
    elevation: 8,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
  );

  // Main Theme Data
  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: scaffoldBackground,
      cardColor: cardBackground,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: primaryBlueLight,
        surface: cardBackground,
        background: scaffoldBackground,
        error: error,
        onPrimary: textInverse,
        onSecondary: textInverse,
        onSurface: textPrimary,
        onBackground: textPrimary,
        onError: textInverse,
        brightness: Brightness.light,
      ),

      // Text Theme
      textTheme: const TextTheme(
        headlineLarge: headingLarge,
        headlineMedium: headingMedium,
        headlineSmall: headingSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      ),

      // Input Decoration Theme
      inputDecorationTheme: inputDecorationTheme,

      // App Bar Theme
      appBarTheme: appBarTheme,

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: bottomNavigationBarTheme,

      // Floating Action Button Theme
      floatingActionButtonTheme: floatingActionButtonTheme,

      // Icon Theme
      iconTheme: iconTheme,

      // Divider Theme
      dividerTheme: dividerTheme,

      // Chip Theme
      chipTheme: chipTheme,

      // Snackbar Theme
      snackBarTheme: snackBarTheme,

      // Dialog Theme
      dialogTheme: dialogTheme,

      // Bottom Sheet Theme
      bottomSheetTheme: bottomSheetTheme,

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(style: textButtonStyle),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButtonStyle),
    );
  }
}
