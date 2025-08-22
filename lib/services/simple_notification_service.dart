import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple notification service that doesn't block app startup
class SimpleNotificationService {
  static final SimpleNotificationService _instance = SimpleNotificationService._internal();
  factory SimpleNotificationService() => _instance;
  SimpleNotificationService._internal();

  bool _isInitialized = false;
  int _notificationCount = 0;

  /// Get notification count
  int get notificationCount => _notificationCount;

  /// Initialize the service (non-blocking)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('SimpleNotificationService: Initializing...');
      
      // Load notification count from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _notificationCount = prefs.getInt('notification_count') ?? 0;
      
      _isInitialized = true;
      debugPrint('SimpleNotificationService: Initialized successfully with $_notificationCount notifications');
    } catch (e) {
      debugPrint('SimpleNotificationService: Initialization failed: $e');
      // Don't rethrow - allow app to continue
    }
  }

  /// Add a notification
  Future<void> addNotification(String title, String body) async {
    try {
      _notificationCount++;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('notification_count', _notificationCount);
      
      debugPrint('SimpleNotificationService: Added notification - $_notificationCount total');
    } catch (e) {
      debugPrint('SimpleNotificationService: Failed to add notification: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearNotifications() async {
    try {
      _notificationCount = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('notification_count', 0);
      
      debugPrint('SimpleNotificationService: Cleared all notifications');
    } catch (e) {
      debugPrint('SimpleNotificationService: Failed to clear notifications: $e');
    }
  }

  /// Mark notifications as read
  Future<void> markAsRead() async {
    try {
      _notificationCount = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('notification_count', 0);
      
      debugPrint('SimpleNotificationService: Marked notifications as read');
    } catch (e) {
      debugPrint('SimpleNotificationService: Failed to mark notifications as read: $e');
    }
  }
} 