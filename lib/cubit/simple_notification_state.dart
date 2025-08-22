part of 'simple_notification_cubit.dart';

abstract class SimpleNotificationState {
  const SimpleNotificationState();
}

class SimpleNotificationInitial extends SimpleNotificationState {}

class SimpleNotificationLoading extends SimpleNotificationState {}

class SimpleNotificationLoaded extends SimpleNotificationState {
  final int notificationCount;

  const SimpleNotificationLoaded({
    required this.notificationCount,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SimpleNotificationLoaded &&
        other.notificationCount == notificationCount;
  }

  @override
  int get hashCode => notificationCount.hashCode;
}

class SimpleNotificationError extends SimpleNotificationState {
  final String message;

  const SimpleNotificationError(this.message);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SimpleNotificationError && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;
} 