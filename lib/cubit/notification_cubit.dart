import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/notification_model.dart';
import '../services/notification_repository.dart';
import '../services/notification_service.dart';

part 'notification_state.dart';

class NotificationCubit extends Cubit<NotificationState> {
  /// Add a sample notification (e.g., low stock alert)
  Future<void> addSampleNotification() async {
    final sample = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: "Low Stock Alert",
      body: "Some items are running low on stock. Please review your inventory.",
      category: "inventory",
      action: "view_inventory",
      data: {},
      timestamp: DateTime.now(),
      isRead: false,
    );
    await addNotification(sample);
  }

  final NotificationRepository _repository;
  final NotificationService _service;
  
  NotificationCubit({
    required NotificationRepository repository,
    required NotificationService service,
  })  : _repository = repository,
        _service = service,
        super(NotificationInitial()) {
    // Load notifications in background to avoid blocking initialization
    _loadNotifications().catchError((error) {
      debugPrint('NotificationCubit: Failed to load notifications during initialization: $error');
    });
  }

  /// Load all notifications
  Future<void> _loadNotifications() async {
    try {
      emit(NotificationLoading());
      final notifications = await _repository.getNotifications();
      final unreadCount = await _repository.getUnreadCount();
      emit(NotificationLoaded(notifications: notifications, unreadCount: unreadCount));
    } catch (e) {
      debugPrint('NotificationCubit: Error loading notifications: $e');
      emit(NotificationError('Failed to load notifications'));
    }
  }

  /// Refresh notifications
  Future<void> refreshNotifications() async {
    await _loadNotifications();
  }

  /// Add new notification
  Future<void> addNotification(NotificationModel notification) async {
    try {
      await _repository.saveNotification(notification);
      await _loadNotifications();
      
      // Show local notification
      await _service.showLocalNotification(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        payload: notification.data != null ? json.encode(notification.data) : null,
        category: notification.category,
      );
    } catch (e) {
      debugPrint('NotificationCubit: Error adding notification: $e');
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String id) async {
    try {
      await _repository.markAsRead(id);
      await _loadNotifications();
    } catch (e) {
      debugPrint('NotificationCubit: Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead();
      await _loadNotifications();
    } catch (e) {
      debugPrint('NotificationCubit: Error marking all notifications as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String id) async {
    try {
      await _repository.deleteNotification(id);
      await _loadNotifications();
    } catch (e) {
      debugPrint('NotificationCubit: Error deleting notification: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      await _repository.clearAllNotifications();
      await _loadNotifications();
    } catch (e) {
      debugPrint('NotificationCubit: Error clearing notifications: $e');
    }
  }

  /// Get notification settings
  Future<Map<String, dynamic>> getNotificationSettings() async {
    try {
      return await _repository.getNotificationSettings();
    } catch (e) {
      debugPrint('NotificationCubit: Error getting notification settings: $e');
      return {};
    }
  }

  /// Update notification setting
  Future<void> updateNotificationSetting(String key, dynamic value) async {
    try {
      await _repository.updateNotificationSetting(key, value);
    } catch (e) {
      debugPrint('NotificationCubit: Error updating notification setting: $e');
    }
  }

  /// Show sample notifications
  Future<void> showSampleNotifications() async {
    try {
      await _service.showSampleNotifications();
      
      // Add sample notifications to local storage
      final sampleNotifications = [
        NotificationModel(
          id: 'sample_1',
          title: 'New Sale Completed! 🎉',
          body: 'You just made a sale of Rs 2,500. Keep up the great work!',
          category: 'sales',
          action: 'view_sale',
          data: {'sale_id': 'sample_001'},
          timestamp: DateTime.now(),
        ),
        NotificationModel(
          id: 'sample_2',
          title: 'Low Stock Alert ⚠️',
          body: 'Item "Premium Coffee" is running low. Only 5 units remaining.',
          category: 'inventory',
          action: 'view_item',
          data: {'item_id': 'coffee_001'},
          timestamp: DateTime.now().subtract(Duration(minutes: 30)),
        ),
        NotificationModel(
          id: 'sample_3',
          title: 'Expense Added 💰',
          body: 'New expense of Rs 1,200 added for "Office Supplies".',
          category: 'expense',
          action: 'view_expense',
          data: {'expense_id': 'exp_001'},
          timestamp: DateTime.now().subtract(Duration(hours: 2)),
        ),
        NotificationModel(
          id: 'sample_4',
          title: 'Daily Reminder 📅',
          body: 'Don\'t forget to review your daily sales report!',
          category: 'reminder',
          action: 'view_report',
          data: {'report_type': 'daily'},
          timestamp: DateTime.now().subtract(Duration(hours: 4)),
        ),
      ];

      for (final notification in sampleNotifications) {
        await _repository.saveNotification(notification);
      }

      await _loadNotifications();
    } catch (e) {
      debugPrint('NotificationCubit: Error showing sample notifications: $e');
    }
  }

  /// Schedule reminder notification
  Future<void> scheduleReminder({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      await _service.scheduleReminder(
        id: DateTime.now().millisecondsSinceEpoch,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationCubit: Error scheduling reminder: $e');
    }
  }

  /// Get FCM token
  Future<String?> getFcmToken() async {
    try {
      return await _service.getFcmToken();
    } catch (e) {
      debugPrint('NotificationCubit: Error getting FCM token: $e');
      return null;
    }
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _service.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('NotificationCubit: Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _service.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('NotificationCubit: Error unsubscribing from topic: $e');
    }
  }
} 