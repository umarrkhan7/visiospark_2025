import 'package:flutter/material.dart';
import 'event_model.dart';
import 'user_model.dart';

class FeedbackModel {
  final String id;
  final String eventId;
  final String userId;
  final int rating; // 1-5 stars
  final String? comment;
  final bool isAnonymous;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Nested objects (optional, loaded with joins)
  final EventModel? event;
  final UserModel? user;

  FeedbackModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.rating,
    this.comment,
    this.isAnonymous = false,
    required this.createdAt,
    required this.updatedAt,
    this.event,
    this.user,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      event: json['events'] != null
          ? EventModel.fromJson(json['events'] as Map<String, dynamic>)
          : null,
      user: json['profiles'] != null
          ? UserModel.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'rating': rating,
      'comment': comment,
      'is_anonymous': isAnonymous,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FeedbackModel copyWith({
    String? id,
    String? eventId,
    String? userId,
    int? rating,
    String? comment,
    bool? isAnonymous,
    DateTime? createdAt,
    DateTime? updatedAt,
    EventModel? event,
    UserModel? user,
  }) {
    return FeedbackModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      event: event ?? this.event,
      user: user ?? this.user,
    );
  }

  // Rating helpers
  String get ratingStars => '⭐' * rating;
  
  bool get hasComment => comment != null && comment!.isNotEmpty;

  String get authorName {
    if (isAnonymous) return 'Anonymous';
    if (user != null) return user!.displayName;
    return 'Unknown';
  }

  String get authorAvatar {
    if (isAnonymous || user == null) return '';
    return user!.avatarUrl ?? '';
  }

  // Sentiment based on rating
  String get sentiment {
    if (rating >= 4) return 'positive';
    if (rating == 3) return 'neutral';
    return 'negative';
  }

  Color get sentimentColor {
    switch (sentiment) {
      case 'positive':
        return const Color(0xFF10B981); // Green
      case 'negative':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFFF59E0B); // Yellow
    }
  }

  @override
  String toString() => 'Feedback($rating stars, $eventId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedbackModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
