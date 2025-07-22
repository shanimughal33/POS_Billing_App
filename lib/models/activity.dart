import 'package:flutter/foundation.dart';

class Activity {
  final int? id;
  final String type; // e.g., sale, purchase, people_add, people_edit, etc.
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata; // For extra info (amount, ids, etc.)

  Activity({
    this.id,
    required this.type,
    required this.description,
    required this.timestamp,
    this.metadata,
  });

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      id: map['id'] as int?,
      type: map['type'] as String,
      description: map['description'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(_decodeMetadata(map['metadata']))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata != null ? _encodeMetadata(metadata!) : null,
    };
  }

  static String _encodeMetadata(Map<String, dynamic> meta) {
    return meta.toString(); // You may use jsonEncode for more robust storage
  }

  static Map<String, dynamic> _decodeMetadata(dynamic meta) {
    // You may use jsonDecode for more robust storage
    if (meta is Map<String, dynamic>) return meta;
    if (meta is String) {
      // Try to parse as Map
      try {
        // This is a placeholder; replace with jsonDecode if using JSON
        return {};
      } catch (_) {
        return {};
      }
    }
    return {};
  }
}
