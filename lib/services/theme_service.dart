import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _themeModeKey = 'theme_mode';
  static const String _manualThemeModeKey = 'manual_theme_mode';

  // Notifier that drives MaterialApp.themeMode
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier(ThemeMode.system);

  // Track last chosen manual theme (light/dark) when not following system
  static ThemeMode _manualTheme = ThemeMode.light;

  static Future<void> initTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getString(_themeModeKey);
    final manualSaved = prefs.getString(_manualThemeModeKey);

    if (manualSaved != null) {
      _manualTheme = ThemeMode.values.firstWhere(
        (e) => e.toString() == manualSaved,
        orElse: () => ThemeMode.light,
      );
    }

    if (savedValue != null) {
      final mode = ThemeMode.values.firstWhere(
        (e) => e.toString() == savedValue,
        orElse: () => ThemeMode.system,
      );
      themeNotifier.value = mode;
    }
  }

  // Legacy method: set explicit theme; prefer setFollowSystem/setManualMode
  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    // If setting manual value, remember it too
    if (mode == ThemeMode.dark || mode == ThemeMode.light) {
      _manualTheme = mode;
      await prefs.setString(_manualThemeModeKey, _manualTheme.toString());
    }
    await prefs.setString(_themeModeKey, mode.toString());
    themeNotifier.value = mode;
  }

  static Future<void> setFollowSystem(bool follow) async {
    final prefs = await SharedPreferences.getInstance();
    if (follow) {
      await prefs.setString(_themeModeKey, ThemeMode.system.toString());
      themeNotifier.value = ThemeMode.system;
    } else {
      // Switch to last manual mode (default light)
      await prefs.setString(_manualThemeModeKey, _manualTheme.toString());
      await prefs.setString(_themeModeKey, _manualTheme.toString());
      themeNotifier.value = _manualTheme;
    }
  }

  static Future<void> setManualMode(ThemeMode manualMode) async {
    assert(manualMode == ThemeMode.dark || manualMode == ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    _manualTheme = manualMode;
    await prefs.setString(_manualThemeModeKey, _manualTheme.toString());
    // Only apply immediately if we're not following system
    if (themeNotifier.value != ThemeMode.system) {
      await prefs.setString(_themeModeKey, _manualTheme.toString());
      themeNotifier.value = _manualTheme;
    }
  }

  static bool isFollowingSystem() => themeNotifier.value == ThemeMode.system;

  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}
