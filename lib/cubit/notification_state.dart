part of 'notification_cubit.dart';

abstract class NotificationState {
  const NotificationState();
}

class NotificationInitial extends NotificationState {}

class NotificationLoading extends NotificationState {}

class NotificationLoaded extends NotificationState {
  final List<NotificationModel> notifications;
  final int unreadCount;

  const NotificationLoaded({
    required this.notifications,
    required this.unreadCount,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationLoaded &&
        other.notifications == notifications &&
        other.unreadCount == unreadCount;
  }

  @override
  int get hashCode => notifications.hashCode ^ unreadCount.hashCode;
}

class NotificationError extends NotificationState {
  final String message;

  const NotificationError(this.message);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationError && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;
} 