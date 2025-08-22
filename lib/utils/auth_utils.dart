import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gets the current user UID with proper fallback logic
/// First checks Firebase Auth current user, then falls back to SharedPreferences
Future<String?> getCurrentUserUid() async {
  try {
    // First, try to get the current user from Firebase Auth
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.uid.isNotEmpty) {
      // Save to SharedPreferences for consistency
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_uid', currentUser.uid);
      return currentUser.uid;
    }
    
    // Fallback to SharedPreferences if Firebase Auth user is not available
    final prefs = await SharedPreferences.getInstance();
    final storedUid = prefs.getString('current_uid');
    
    if (storedUid != null && storedUid.isNotEmpty) {
      return storedUid;
    }
    
    return null;
  } catch (e) {
    print('Error getting current user UID: $e');
    // Final fallback to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('current_uid');
    } catch (prefsError) {
      print('Error accessing SharedPreferences: $prefsError');
      return null;
    }
  }
}

/// Saves the user UID to SharedPreferences
Future<void> saveUserUid(String uid) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_uid', uid);
    print('Saved UID to SharedPreferences: \'$uid\'');
  } catch (e) {
    print('Error saving UID to SharedPreferences: $e');
  }
}

/// Clears the stored user UID from SharedPreferences
Future<void> clearUserUid() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_uid');
    print('Cleared UID from SharedPreferences');
  } catch (e) {
    print('Error clearing UID from SharedPreferences: $e');
  }
}

/// Checks if a user is currently authenticated
Future<bool> isUserAuthenticated() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      return true;
    }
    
    // Fallback check to SharedPreferences
    final uid = await getCurrentUserUid();
    return uid != null && uid.isNotEmpty;
  } catch (e) {
    print('Error checking authentication status: $e');
    return false;
  }
} 