import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../utils/auth_utils.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Notification channels for Android
  static const String _defaultChannelId = 'default_channel';
  static const String _salesChannelId = 'sales_channel';
  static const String _inventoryChannelId = 'inventory_channel';
  static const String _expenseChannelId = 'expense_channel';
  static const String _reminderChannelId = 'reminder_channel';

  // Notification categories
  static const String _salesCategory = 'sales';
  static const String _inventoryCategory = 'inventory';
  static const String _expenseCategory = 'expense';
  static const String _reminderCategory = 'reminder';
  static const String _systemCategory = 'system';

  String? _fcmToken;
  bool _isInitialized = false;

  // Getters
  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('NotificationService: Initializing...');

      // Initialize timezone
      tz.initializeTimeZones();

      // Request permissions (non-blocking)
      _requestPermissions().catchError((error) {
        debugPrint('NotificationService: Permission request failed: $error');
      });

      // Initialize local notifications (non-blocking)
      _initializeLocalNotifications().catchError((error) {
        debugPrint('NotificationService: Local notifications initialization failed: $error');
      });

      // Initialize Firebase Messaging (non-blocking)
      _initializeFirebaseMessaging().catchError((error) {
        debugPrint('NotificationService: Firebase Messaging initialization failed: $error');
      });

      // Set up message handlers
      _setupMessageHandlers();

      _isInitialized = true;
      debugPrint('NotificationService: Initialized successfully');
    } catch (e) {
      debugPrint('NotificationService: Initialization failed: $e');
      // Don't rethrow - allow app to continue without notifications
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      // Request FCM permissions
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('NotificationService: FCM permission status: ${settings.authorizationStatus}');

      // Request local notification permissions
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          // Permission is automatically granted on Android 13+ for local notifications
          debugPrint('NotificationService: Local notification permission available');
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Permission request failed: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels for Android
      await _createNotificationChannels();
    } catch (e) {
      debugPrint('NotificationService: Local notifications initialization failed: $e');
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
        _defaultChannelId,
        'Default Notifications',
        description: 'General app notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      const AndroidNotificationChannel salesChannel = AndroidNotificationChannel(
        _salesChannelId,
        'Sales Notifications',
        description: 'Notifications related to sales and transactions',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      const AndroidNotificationChannel inventoryChannel = AndroidNotificationChannel(
        _inventoryChannelId,
        'Inventory Notifications',
        description: 'Notifications related to inventory management',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      );

      const AndroidNotificationChannel expenseChannel = AndroidNotificationChannel(
        _expenseChannelId,
        'Expense Notifications',
        description: 'Notifications related to expenses',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      );

      const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
        _reminderChannelId,
        'Reminder Notifications',
        description: 'Reminder and scheduled notifications',
        importance: Importance.low,
        playSound: true,
        enableVibration: false,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(defaultChannel);
        await androidImplementation.createNotificationChannel(salesChannel);
        await androidImplementation.createNotificationChannel(inventoryChannel);
        await androidImplementation.createNotificationChannel(expenseChannel);
        await androidImplementation.createNotificationChannel(reminderChannel);
      }
    }
  }

  /// Initialize Firebase Messaging
  Future<void> _initializeFirebaseMessaging() async {
    try {
      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('NotificationService: FCM Token: $_fcmToken');

      // Save token to SharedPreferences
      if (_fcmToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFcmToken(newToken);
        debugPrint('NotificationService: FCM Token refreshed: $newToken');
      });

      // Set up foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from notification
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      debugPrint('NotificationService: Firebase Messaging initialization failed: $e');
    }
  }

  /// Set up message handlers
  void _setupMessageHandlers() {
    // Handle notification tap
    _localNotifications.initialize(
      const InitializationSettings(),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('NotificationService: Received foreground message: ${message.messageId}');
    
    // Show local notification
    showLocalNotification(
      id: message.hashCode,
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body ?? '',
      payload: json.encode(message.data),
      category: message.data['category'] ?? _systemCategory,
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('NotificationService: Notification tapped: ${message.messageId}');
    
    // Handle different notification types based on data
    final category = message.data['category'] ?? _systemCategory;
    final action = message.data['action'] ?? '';
    
    _handleNotificationAction(category, action, message.data);
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('NotificationService: Local notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        final category = data['category'] ?? _systemCategory;
        final action = data['action'] ?? '';
        
        _handleNotificationAction(category, action, data);
      } catch (e) {
        debugPrint('NotificationService: Error parsing notification payload: $e');
      }
    }
  }

  /// Handle notification actions
  void _handleNotificationAction(String category, String action, Map<String, dynamic> data) {
    switch (category) {
      case _salesCategory:
        _handleSalesNotification(action, data);
        break;
      case _inventoryCategory:
        _handleInventoryNotification(action, data);
        break;
      case _expenseCategory:
        _handleExpenseNotification(action, data);
        break;
      case _reminderCategory:
        _handleReminderNotification(action, data);
        break;
      default:
        _handleSystemNotification(action, data);
        break;
    }
  }

  /// Handle sales notifications
  void _handleSalesNotification(String action, Map<String, dynamic> data) {
    // Navigate to sales screen or specific sale
    debugPrint('NotificationService: Handling sales notification - $action');
  }

  /// Handle inventory notifications
  void _handleInventoryNotification(String action, Map<String, dynamic> data) {
    // Navigate to inventory screen or specific item
    debugPrint('NotificationService: Handling inventory notification - $action');
  }

  /// Handle expense notifications
  void _handleExpenseNotification(String action, Map<String, dynamic> data) {
    // Navigate to expense screen or specific expense
    debugPrint('NotificationService: Handling expense notification - $action');
  }

  /// Handle reminder notifications
  void _handleReminderNotification(String action, Map<String, dynamic> data) {
    // Handle reminder actions
    debugPrint('NotificationService: Handling reminder notification - $action');
  }

  /// Handle system notifications
  void _handleSystemNotification(String action, Map<String, dynamic> data) {
    // Handle system-level notifications
    debugPrint('NotificationService: Handling system notification - $action');
  }

  /// Show local notification (public method)
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String category = _defaultChannelId,
  }) async {
    try {
      String channelId = _defaultChannelId;
      
      // Determine channel based on category
      switch (category) {
        case _salesCategory:
          channelId = _salesChannelId;
          break;
        case _inventoryCategory:
          channelId = _inventoryChannelId;
          break;
        case _expenseCategory:
          channelId = _expenseChannelId;
          break;
        case _reminderCategory:
          channelId = _reminderChannelId;
          break;
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _defaultChannelId,
        'Default Notifications',
        channelDescription: 'General app notifications',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('NotificationService: Error showing local notification: $e');
    }
  }

  /// Save FCM token
  Future<void> _saveFcmToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
    } catch (e) {
      debugPrint('NotificationService: Error saving FCM token: $e');
    }
  }

  /// Get FCM token
  Future<String?> getFcmToken() async {
    if (_fcmToken != null) return _fcmToken;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _fcmToken = prefs.getString('fcm_token');
      return _fcmToken;
    } catch (e) {
      debugPrint('NotificationService: Error getting FCM token: $e');
      return null;
    }
  }

  /// Subscribe to topics
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('NotificationService: Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('NotificationService: Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topics
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('NotificationService: Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('NotificationService: Error unsubscribing from topic: $e');
    }
  }

  /// Show sample notifications
  Future<void> showSampleNotifications() async {
    // Sales notification
    await showLocalNotification(
      id: 1,
      title: 'New Sale Completed! 🎉',
      body: 'You just made a sale of Rs 2,500. Keep up the great work!',
      payload: json.encode({
        'category': _salesCategory,
        'action': 'view_sale',
        'sale_id': 'sample_001',
      }),
      category: _salesCategory,
    );

    // Inventory notification
    await showLocalNotification(
      id: 2,
      title: 'Low Stock Alert ⚠️',
      body: 'Item "Premium Coffee" is running low. Only 5 units remaining.',
      payload: json.encode({
        'category': _inventoryCategory,
        'action': 'view_item',
        'item_id': 'coffee_001',
      }),
      category: _inventoryCategory,
    );

    // Expense notification
    await showLocalNotification(
      id: 3,
      title: 'Expense Added 💰',
      body: 'New expense of Rs 1,200 added for "Office Supplies".',
      payload: json.encode({
        'category': _expenseCategory,
        'action': 'view_expense',
        'expense_id': 'exp_001',
      }),
      category: _expenseCategory,
    );

    // Reminder notification
    await showLocalNotification(
      id: 4,
      title: 'Daily Reminder 📅',
      body: 'Don\'t forget to review your daily sales report!',
      payload: json.encode({
        'category': _reminderCategory,
        'action': 'view_report',
        'report_type': 'daily',
      }),
      category: _reminderCategory,
    );
  }

  /// Schedule reminder notification
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final scheduledTZDate = tz.TZDateTime.from(scheduledDate, tz.local);
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _reminderChannelId,
        'Reminder Notifications',
        channelDescription: 'Reminder and scheduled notifications',
        importance: Importance.low,
        priority: Priority.low,
        showWhen: true,
        enableVibration: false,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTZDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      debugPrint('NotificationService: Scheduled reminder for $scheduledDate');
    } catch (e) {
      debugPrint('NotificationService: Error scheduling reminder: $e');
    }
  }

  /// Cancel notification
  Future<void> cancelNotification(int id) async {
    try {
      await _localNotifications.cancel(id);
      debugPrint('NotificationService: Cancelled notification with id: $id');
    } catch (e) {
      debugPrint('NotificationService: Error cancelling notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      debugPrint('NotificationService: Cancelled all notifications');
    } catch (e) {
      debugPrint('NotificationService: Error cancelling all notifications: $e');
    }
  }

  /// Get notification settings
  Future<NotificationSettings> getNotificationSettings() async {
    try {
      return await _firebaseMessaging.getNotificationSettings();
    } catch (e) {
      debugPrint('NotificationService: Error getting notification settings: $e');
      rethrow;
    }
  }

  /// Update notification settings
  Future<void> updateNotificationSettings({
    bool? alert,
    bool? badge,
    bool? sound,
  }) async {
    try {
      await _firebaseMessaging.requestPermission(
        alert: alert ?? true,
        badge: badge ?? true,
        sound: sound ?? true,
      );
      debugPrint('NotificationService: Updated notification settings');
    } catch (e) {
      debugPrint('NotificationService: Error updating notification settings: $e');
    }
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('NotificationService: Handling background message: ${message.messageId}');
  
  // Show local notification for background messages
  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
  
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    NotificationService._defaultChannelId,
    'Default Notifications',
    channelDescription: 'General app notifications',
    importance: Importance.high,
    priority: Priority.high,
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

  const NotificationDetails details = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  await localNotifications.show(
    message.hashCode,
    message.notification?.title ?? 'New Notification',
    message.notification?.body ?? '',
    details,
    payload: json.encode(message.data),
  );
} 