import 'package:flutter/foundation.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String category;
  final String? action;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  final bool isRead;
  final String? imageUrl;
  final String? icon;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    this.action,
    this.data,
    required this.timestamp,
    this.isRead = false,
    this.imageUrl,
    this.icon,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      category: map['category'] as String,
      action: map['action'] as String?,
      data: map['data'] != null ? Map<String, dynamic>.from(map['data']) : null,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isRead: map['isRead'] as bool? ?? false,
      imageUrl: map['imageUrl'] as String?,
      icon: map['icon'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'category': category,
      'action': action,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'icon': icon,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? category,
    String? action,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool? isRead,
    String? imageUrl,
    String? icon,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      action: action ?? this.action,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl ?? this.imageUrl,
      icon: icon ?? this.icon,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationModel &&
        other.id == id &&
        other.title == title &&
        other.body == body &&
        other.category == category &&
        other.action == action &&
        mapEquals(other.data, data) &&
        other.timestamp == timestamp &&
        other.isRead == isRead &&
        other.imageUrl == imageUrl &&
        other.icon == icon;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        body.hashCode ^
        category.hashCode ^
        action.hashCode ^
        data.hashCode ^
        timestamp.hashCode ^
        isRead.hashCode ^
        imageUrl.hashCode ^
        icon.hashCode;
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, title: $title, body: $body, category: $category, action: $action, data: $data, timestamp: $timestamp, isRead: $isRead, imageUrl: $imageUrl, icon: $icon)';
  }
} 