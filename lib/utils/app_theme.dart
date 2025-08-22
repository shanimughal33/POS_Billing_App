// This file is deprecated. Please use the new theme system in lib/themes/
// Import the new theme system
export '../themes/app_theme.dart';
export '../themes/light_theme.dart';
export '../themes/dark_theme.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Legacy constants for backward compatibility
// Main dark blue colors
const Color kDarkBlue = Color(0xFF0A2342);
const Color kDarkBlue2 = Color(0xFF123060);
const Color kBlueGradientStart = kDarkBlue;
const Color kBlueGradientEnd = kBlue;
const Color kAccent = Color(0xFF128C7E);
const Color kCardBg = Color(0xFFF5F6FA);
const Color kInputBg = Color(0xFF1B2A41);
const Color kWhite = Color(0xFFFFFFFF);
const Color kTextPrimary = Colors.white;
const Color kTextSecondary = Color(0xFFB0BEC5);
const Color kError = Color(0xFFEF4444);
const Color kBlue = Color(0xFF1976D2);

const LinearGradient kBlueGradient = LinearGradient(
  colors: [kBlueGradientStart, kBlueGradientEnd],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// Text styles
const TextStyle kHeadingStyle = TextStyle(
  color: kWhite,
  fontWeight: FontWeight.bold,
  fontSize: 22,
  letterSpacing: 0.5,
);
const TextStyle kSubheadingStyle = TextStyle(
  color: kTextSecondary,
  fontWeight: FontWeight.w600,
  fontSize: 16,
);
const TextStyle kBodyStyle = TextStyle(color: kTextPrimary, fontSize: 14);
const TextStyle kButtonStyle = TextStyle(
  color: kWhite,
  fontWeight: FontWeight.bold,
  fontSize: 16,
);

// Card style
final BoxDecoration kCardDecoration = BoxDecoration(
  color: kCardBg,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ],
);

// Input decoration
final InputDecorationTheme kInputDecorationTheme = InputDecorationTheme(
  filled: true,
  fillColor: kInputBg,
  labelStyle: TextStyle(color: kTextSecondary, fontSize: 14),
  hintStyle: TextStyle(color: kTextSecondary.withOpacity(0.7)),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: kBlue, width: 1.2),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: kBlue, width: 1.2),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: kBlue, width: 2),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: kError, width: 1.2),
  ),
);

// ThemeData for the whole app
final ThemeData kAppTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: kBlue,
  scaffoldBackgroundColor: kDarkBlue,
  cardColor: kCardBg,
  textTheme: const TextTheme(
    headlineLarge: kHeadingStyle,
    titleLarge: kSubheadingStyle,
    bodyLarge: kBodyStyle,
    labelLarge: kButtonStyle,
  ),
  inputDecorationTheme: kInputDecorationTheme,
  appBarTheme: const AppBarTheme(
    backgroundColor: kDarkBlue,
    elevation: 0,
    iconTheme: IconThemeData(color: kWhite),
    titleTextStyle: kHeadingStyle,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: kBlue,
    foregroundColor: kWhite,
    elevation: 8,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kBlue,
      foregroundColor: kWhite,
      textStyle: kButtonStyle,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
    ),
  ),
  iconTheme: const IconThemeData(color: kWhite),
  colorScheme: const ColorScheme.dark(
    primary: kBlue,
    secondary: kAccent,
    background: kDarkBlue,
    surface: kCardBg,
    error: kError,
    onPrimary: kWhite,
    onSecondary: kWhite,
    onBackground: kTextPrimary,
    onSurface: kTextPrimary,
    onError: kWhite,
    brightness: Brightness.dark,
  ),
);

// Add missing color and style constants for use in all screens
const Color kLightBorder = Color(0xFFE0E0E0);
const Color kTransparent = Colors.transparent;
const Color kF8F9FA = Color(0xFFF8F9FA);
const Color kF1F3F4 = Color(0xFFF1F3F4);
const Color kBlack87 = Color(0xDD000000);
const Color kBlack54 = Color(0x8A000000);
const Color kRed = Color(0xFFEF4444);
const Color kRed100 = Color(0xFFFFCDD2);
const Color kGreen = Color(0xFF10B981);
const Color kGrey500 = Color(0xFF9E9E9E);
const Color kGrey600 = Color(0xFF757575);
const Color kGrey700 = Color(0xFF616161);
const Color kWhite70 = Color(0xB3FFFFFF);
const Color kBlack12 = Color(0x1F000000);

// Add these methods for theme persistence
Future<void> saveThemeMode(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('theme_mode', mode.toString());
}

Future<ThemeMode> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final savedMode = prefs.getString('theme_mode');
  switch (savedMode) {
    case 'ThemeMode.dark':
      return ThemeMode.dark;
    case 'ThemeMode.light':
      return ThemeMode.light;
    default:
      return ThemeMode.system;
  }
}

// Dark theme colors
 const darkBackground = Color(0xFF0A2342);
 const darkCardColor = Color(0xFF1A2233);
 const darkTextColor = Colors.white;
 const darkPrimaryColor = Color(0xFF1976D2);

// Dark theme styles
 final darkThemeData = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: darkBackground,
  cardColor: darkCardColor,
  primaryColor: darkPrimaryColor,
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: darkTextColor),
    bodyMedium: TextStyle(color: darkTextColor),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: darkCardColor,
    elevation: 0,
    iconTheme: IconThemeData(color: darkTextColor),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: darkCardColor,
    labelStyle: TextStyle(color: darkTextColor.withOpacity(0.87)),
    hintStyle: TextStyle(color: darkTextColor.withOpacity(0.6)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: darkPrimaryColor.withOpacity(0.15)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: darkPrimaryColor, width: 2),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: darkPrimaryColor,
      foregroundColor: darkTextColor,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: darkPrimaryColor,
    ),
  ),
);
