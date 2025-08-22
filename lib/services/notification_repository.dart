import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  static const String _notificationsKey = 'notifications';
  static const String _notificationSettingsKey = 'notification_settings';
  static const String _lowStockNotifiedKey = 'low_stock_notified_ids';
  static const String _zeroQtyNotifiedKey = 'zero_qty_notified_ids';

  /// Save notification to local storage
  Future<void> saveNotification(NotificationModel notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList(_notificationsKey) ?? [];
      
      // Add new notification
      notificationsJson.add(json.encode(notification.toMap()));
      
      // Keep only last 100 notifications
      if (notificationsJson.length > 100) {
        notificationsJson.removeRange(0, notificationsJson.length - 100);
      }
      
      await prefs.setStringList(_notificationsKey, notificationsJson);
    } catch (e) {
      print('Error saving notification: $e');
    }
  }

  /// Get all notifications
  Future<List<NotificationModel>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList(_notificationsKey) ?? [];
      
      return notificationsJson
          .map((jsonString) => NotificationModel.fromMap(json.decode(jsonString)))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }

  /// Get unread notifications count
  Future<int> getUnreadCount() async {
    try {
      final notifications = await getNotifications();
      return notifications.where((notification) => !notification.isRead).length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList(_notificationsKey) ?? [];
      
      final updatedNotifications = notificationsJson.map((jsonString) {
        final notification = NotificationModel.fromMap(json.decode(jsonString));
        if (notification.id == id) {
          return json.encode(notification.copyWith(isRead: true).toMap());
        }
        return jsonString;
      }).toList();
      
      await prefs.setStringList(_notificationsKey, updatedNotifications);
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList(_notificationsKey) ?? [];
      
      final updatedNotifications = notificationsJson.map((jsonString) {
        final notification = NotificationModel.fromMap(json.decode(jsonString));
        return json.encode(notification.copyWith(isRead: true).toMap());
      }).toList();
      
      await prefs.setStringList(_notificationsKey, updatedNotifications);
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList(_notificationsKey) ?? [];
      
      final updatedNotifications = notificationsJson.where((jsonString) {
        final notification = NotificationModel.fromMap(json.decode(jsonString));
        return notification.id != id;
      }).toList();
      
      await prefs.setStringList(_notificationsKey, updatedNotifications);
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notificationsKey);
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }

  /// Get the set of item IDs that have already triggered low-stock notifications
  Future<Set<String>> getLowStockNotifiedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_lowStockNotifiedKey) ?? <String>[];
      return list.toSet();
    } catch (e) {
      print('Error getting low stock notified IDs: $e');
      return <String>{};
    }
  }

  /// Add an item ID to the low-stock notified set
  Future<void> addLowStockNotifiedId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_lowStockNotifiedKey) ?? <String>[];
      if (!list.contains(id)) {
        list.add(id);
        await prefs.setStringList(_lowStockNotifiedKey, list);
      }
    } catch (e) {
      print('Error adding low stock notified ID: $e');
    }
  }

  /// Remove an item ID from the low-stock notified set (e.g., after replenishment)
  Future<void> removeLowStockNotifiedId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_lowStockNotifiedKey) ?? <String>[];
      if (list.contains(id)) {
        list.remove(id);
        await prefs.setStringList(_lowStockNotifiedKey, list);
      }
    } catch (e) {
      print('Error removing low stock notified ID: $e');
    }
  }

  /// Clear all low-stock notified IDs
  Future<void> clearLowStockNotifiedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lowStockNotifiedKey);
    } catch (e) {
      print('Error clearing low stock notified IDs: $e');
    }
  }

  /// Get the set of item IDs that have already triggered zero-qty notifications
  Future<Set<String>> getZeroQtyNotifiedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_zeroQtyNotifiedKey) ?? <String>[];
      return list.toSet();
    } catch (e) {
      print('Error getting zero qty notified IDs: $e');
      return <String>{};
    }
  }

  /// Add an item ID to the zero-qty notified set
  Future<void> addZeroQtyNotifiedId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_zeroQtyNotifiedKey) ?? <String>[];
      if (!list.contains(id)) {
        list.add(id);
        await prefs.setStringList(_zeroQtyNotifiedKey, list);
      }
    } catch (e) {
      print('Error adding zero qty notified ID: $e');
    }
  }

  /// Remove an item ID from the zero-qty notified set (e.g., after replenishment)
  Future<void> removeZeroQtyNotifiedId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_zeroQtyNotifiedKey) ?? <String>[];
      if (list.contains(id)) {
        list.remove(id);
        await prefs.setStringList(_zeroQtyNotifiedKey, list);
      }
    } catch (e) {
      print('Error removing zero qty notified ID: $e');
    }
  }

  /// Clear all zero-qty notified IDs
  Future<void> clearZeroQtyNotifiedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_zeroQtyNotifiedKey);
    } catch (e) {
      print('Error clearing zero qty notified IDs: $e');
    }
  }

  /// Save notification settings
  Future<void> saveNotificationSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notificationSettingsKey, json.encode(settings));
    } catch (e) {
      print('Error saving notification settings: $e');
    }
  }

  /// Get notification settings
  Future<Map<String, dynamic>> getNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_notificationSettingsKey);
      
      if (settingsJson != null) {
        return json.decode(settingsJson);
      }
      
      // Return default settings
      return {
        'sales_notifications': true,
        'inventory_notifications': true,
        'expense_notifications': true,
        'reminder_notifications': true,
        'system_notifications': true,
        'sound_enabled': true,
        'vibration_enabled': true,
        'daily_reminder_time': '09:00',
      };
    } catch (e) {
      print('Error getting notification settings: $e');
      return {};
    }
  }

  /// Update notification setting
  Future<void> updateNotificationSetting(String key, dynamic value) async {
    try {
      final settings = await getNotificationSettings();
      settings[key] = value;
      await saveNotificationSettings(settings);
    } catch (e) {
      print('Error updating notification setting: $e');
    }
  }
} 