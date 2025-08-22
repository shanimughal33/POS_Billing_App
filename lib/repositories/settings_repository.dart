import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';
import 'dart:convert';

class SettingsRepository extends ChangeNotifier {
  final firestore.FirebaseFirestore _firestore =
      firestore.FirebaseFirestore.instance;

  static const String _localSettingsKeyPrefix = 'localSettings_';
  static const String _isDarkModeKey = 'isDarkMode';
  static const String _themePreferenceKey = 'themePreference';
  static const String _userThemeKey = 'userTheme';

  Future<void> saveSettings(Settings settings) {
    debugPrint(
      'SettingsRepository: saveSettings for userId=${settings.userId}',
    );

    // Save to Firestore (writes to cache + syncs to server)
    final future = _firestore
        .collection('users')
        .doc(settings.userId)
        .collection('settings')
        .doc('default')
        .set(settings.toMap());

    // Save a local copy in SharedPreferences for guaranteed offline access
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(
        '$_localSettingsKeyPrefix${settings.userId}',
        jsonEncode(settings.toMap()),
      );
    });

    notifyListeners();
    return future;
  }

  Future<Settings?> getSettings(String userId) {
    debugPrint('SettingsRepository: getSettings for userId=$userId');

    // 1️⃣ Try Firestore local cache first
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('default')
        .get(const firestore.GetOptions(source: firestore.Source.cache))
        .then<Settings?>((doc) {
          if (doc.exists) {
            return Settings.fromMap(doc.data()!);
          }

          // 2️⃣ If not in Firestore cache, try server
          return _firestore
              .collection('users')
              .doc(userId)
              .collection('settings')
              .doc('default')
              .get()
              .then<Settings?>((serverDoc) {
                if (serverDoc.exists) {
                  return Settings.fromMap(serverDoc.data()!);
                }

                // 3️⃣ If no server data, try local SharedPreferences
                return SharedPreferences.getInstance().then<Settings?>((prefs) {
                  final jsonString = prefs.getString(
                    '$_localSettingsKeyPrefix$userId',
                  );
                  if (jsonString != null) {
                    return Settings.fromMap(
                      Map<String, dynamic>.from(jsonDecode(jsonString)),
                    );
                  }
                  return null;
                });
              })
              .catchError((error) {
                debugPrint("Error fetching from server: $error");

                // Fallback to SharedPreferences if server fails
                return SharedPreferences.getInstance().then<Settings?>((prefs) {
                  final jsonString = prefs.getString(
                    '$_localSettingsKeyPrefix$userId',
                  );
                  if (jsonString != null) {
                    return Settings.fromMap(
                      Map<String, dynamic>.from(jsonDecode(jsonString)),
                    );
                  }
                  return null;
                });
              });
        })
        .catchError((error) {
          debugPrint("Error fetching from cache: $error");

          // Fallback to SharedPreferences if Firestore cache fails
          return SharedPreferences.getInstance().then<Settings?>((prefs) {
            final jsonString = prefs.getString(
              '$_localSettingsKeyPrefix$userId',
            );
            if (jsonString != null) {
              return Settings.fromMap(
                Map<String, dynamic>.from(jsonDecode(jsonString)),
              );
            }
            return null;
          });
        })
        .then((settings) {
          // Always return a valid Settings object with safe defaults
          return settings ?? Settings(userId: userId);
        });
  }

  Future<void> deleteSettings(String userId) {
    debugPrint('SettingsRepository: deleteSettings for userId=$userId');

    // Delete from Firestore
    final future = _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('default')
        .delete();

    // Also remove from local SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('$_localSettingsKeyPrefix$userId');
    });

    notifyListeners();
    return future;
  }

  Future<void> setThemeMode(bool isDark, String? userId) {
    return SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_isDarkModeKey, isDark);
      prefs.setString(_themePreferenceKey, isDark ? 'dark' : 'light');

      if (userId != null) {
        prefs.setString('${_userThemeKey}_$userId', isDark ? 'dark' : 'light');
      }
    });
  }

  Future<bool> getThemeMode([String? userId]) {
    return SharedPreferences.getInstance().then((prefs) {
      if (userId != null) {
        final userTheme = prefs.getString('${_userThemeKey}_$userId');
        if (userTheme != null) {
          return userTheme == 'dark';
        }
      }
      return prefs.getBool(_isDarkModeKey) ?? false;
    });
  }
}
