import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../services/simple_notification_service.dart';

part 'simple_notification_state.dart';

class SimpleNotificationCubit extends Cubit<SimpleNotificationState> {
  final SimpleNotificationService _service;
  
  SimpleNotificationCubit({
    required SimpleNotificationService service,
  })  : _service = service,
        super(SimpleNotificationInitial()); // No loading in constructor

  /// Load notifications (call this from UI after app is running)
  Future<void> loadNotifications() async {
    try {
      emit(SimpleNotificationLoading());
      await _service.initialize();
      final count = _service.notificationCount;
      emit(SimpleNotificationLoaded(notificationCount: count));
    } catch (e) {
      debugPrint('SimpleNotificationCubit: Error loading notifications: $e');
      emit(SimpleNotificationError('Failed to load notifications'));
    }
  }

  /// Refresh notifications
  Future<void> refreshNotifications() async {
    await loadNotifications();
  }

  /// Add notification
  Future<void> addNotification(String title, String body) async {
    try {
      await _service.addNotification(title, body);
      await loadNotifications();
    } catch (e) {
      debugPrint('SimpleNotificationCubit: Error adding notification: $e');
    }
  }

  /// Mark notifications as read
  Future<void> markAsRead() async {
    try {
      await _service.markAsRead();
      await loadNotifications();
    } catch (e) {
      debugPrint('SimpleNotificationCubit: Error marking notifications as read: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearNotifications() async {
    try {
      await _service.clearNotifications();
      await loadNotifications();
    } catch (e) {
      debugPrint('SimpleNotificationCubit: Error clearing notifications: $e');
    }
  }
} 