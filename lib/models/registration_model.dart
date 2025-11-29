import 'event_model.dart';
import 'user_model.dart';

class RegistrationModel {
  final String id;
  final String eventId;
  final String userId;
  final String status; // registered, attended, cancelled
  final DateTime registeredAt;
  final DateTime? attendedAt;
  final DateTime? cancelledAt;

  // Nested objects (optional, loaded with joins)
  final EventModel? event;
  final UserModel? user;

  RegistrationModel({
    required this.id,
    required this.eventId,
    required this.userId,
    this.status = 'registered',
    required this.registeredAt,
    this.attendedAt,
    this.cancelledAt,
    this.event,
    this.user,
  });

  factory RegistrationModel.fromJson(Map<String, dynamic> json) {
    return RegistrationModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String? ?? 'registered',
      registeredAt: DateTime.parse(json['registered_at'] as String),
      attendedAt: json['attended_at'] != null
          ? DateTime.parse(json['attended_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
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
      'status': status,
      'registered_at': registeredAt.toIso8601String(),
      'attended_at': attendedAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
    };
  }

  RegistrationModel copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? status,
    DateTime? registeredAt,
    DateTime? attendedAt,
    DateTime? cancelledAt,
    EventModel? event,
    UserModel? user,
  }) {
    return RegistrationModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      registeredAt: registeredAt ?? this.registeredAt,
      attendedAt: attendedAt ?? this.attendedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      event: event ?? this.event,
      user: user ?? this.user,
    );
  }

  // Status getters
  bool get isRegistered => status == 'registered';
  bool get isAttended => status == 'attended';
  bool get isCancelled => status == 'cancelled';

  // Helpers
  bool get canCancel => isRegistered && event != null && event!.isUpcoming;
  bool get canMarkAttendance => isRegistered && event != null && !event!.isUpcoming;

  @override
  String toString() => 'Registration($eventId, $status)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RegistrationModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
