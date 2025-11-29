import 'society_model.dart';

class EventModel {
  final String id;
  final String societyId;
  final String? categoryId;
  final String title;
  final String? description;
  final String eventType; // technical, literary, sports
  final DateTime dateTime;
  final DateTime? endTime;
  final String venue;
  final int capacity;
  final int registeredCount;
  final String status; // upcoming, ongoing, completed, cancelled
  final String? imageUrl;
  final List<String>? tags;
  final DateTime? registrationDeadline;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Nested objects (optional, loaded with joins)
  final SocietyModel? society;
  final int? feedbackCount;
  final double? averageRating;

  EventModel({
    required this.id,
    required this.societyId,
    this.categoryId,
    required this.title,
    this.description,
    required this.eventType,
    required this.dateTime,
    this.endTime,
    required this.venue,
    required this.capacity,
    this.registeredCount = 0,
    this.status = 'upcoming',
    this.imageUrl,
    this.tags,
    this.registrationDeadline,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.society,
    this.feedbackCount,
    this.averageRating,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      societyId: json['society_id'] as String,
      categoryId: json['category_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      eventType: json['event_type'] as String,
      dateTime: DateTime.parse(json['date_time'] as String),
      endTime: json['end_time'] != null 
          ? DateTime.parse(json['end_time'] as String)
          : null,
      venue: json['venue'] as String,
      capacity: json['capacity'] as int,
      registeredCount: json['registered_count'] as int? ?? 0,
      status: json['status'] as String? ?? 'upcoming',
      imageUrl: json['image_url'] as String?,
      tags: json['tags'] != null 
          ? List<String>.from(json['tags'] as List)
          : null,
      registrationDeadline: json['registration_deadline'] != null
          ? DateTime.parse(json['registration_deadline'] as String)
          : null,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      society: json['societies'] != null
          ? SocietyModel.fromJson(json['societies'] as Map<String, dynamic>)
          : null,
      feedbackCount: json['feedback_count'] as int?,
      averageRating: json['average_rating'] != null
          ? (json['average_rating'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'society_id': societyId,
      'category_id': categoryId,
      'title': title,
      'description': description,
      'event_type': eventType,
      'date_time': dateTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'venue': venue,
      'capacity': capacity,
      'registered_count': registeredCount,
      'status': status,
      'image_url': imageUrl,
      'tags': tags,
      'registration_deadline': registrationDeadline?.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EventModel copyWith({
    String? id,
    String? societyId,
    String? categoryId,
    String? title,
    String? description,
    String? eventType,
    DateTime? dateTime,
    DateTime? endTime,
    String? venue,
    int? capacity,
    int? registeredCount,
    String? status,
    String? imageUrl,
    List<String>? tags,
    DateTime? registrationDeadline,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    SocietyModel? society,
    int? feedbackCount,
    double? averageRating,
  }) {
    return EventModel(
      id: id ?? this.id,
      societyId: societyId ?? this.societyId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      description: description ?? this.description,
      eventType: eventType ?? this.eventType,
      dateTime: dateTime ?? this.dateTime,
      endTime: endTime ?? this.endTime,
      venue: venue ?? this.venue,
      capacity: capacity ?? this.capacity,
      registeredCount: registeredCount ?? this.registeredCount,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      society: society ?? this.society,
      feedbackCount: feedbackCount ?? this.feedbackCount,
      averageRating: averageRating ?? this.averageRating,
    );
  }

  // Status getters
  bool get isUpcoming => status == 'upcoming';
  bool get isOngoing => status == 'ongoing';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  // Capacity getters
  bool get isFull => registeredCount >= capacity;
  bool get hasSpots => registeredCount < capacity;
  int get spotsLeft => capacity - registeredCount;
  double get capacityPercentage => (registeredCount / capacity * 100).clamp(0, 100);

  // Registration deadline getters
  bool get hasRegistrationDeadline => registrationDeadline != null;
  bool get isRegistrationOpen {
    if (isCancelled || isCompleted) return false;
    if (hasRegistrationDeadline) {
      return DateTime.now().isBefore(registrationDeadline!);
    }
    return DateTime.now().isBefore(dateTime);
  }
  bool get isRegistrationClosed => !isRegistrationOpen;

  // Time getters
  bool get isToday {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return dateTime.year == tomorrow.year &&
        dateTime.month == tomorrow.month &&
        dateTime.day == tomorrow.day;
  }

  bool get isThisWeek {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    return dateTime.isAfter(weekStart) && dateTime.isBefore(weekEnd);
  }

  Duration get timeUntilEvent => dateTime.difference(DateTime.now());
  bool get isWithin24Hours => timeUntilEvent.inHours <= 24 && timeUntilEvent.inHours > 0;

  // Rating helpers
  bool get hasRating => averageRating != null && feedbackCount != null && feedbackCount! > 0;
  String get ratingDisplay {
    if (!hasRating) return 'No ratings yet';
    return '${averageRating!.toStringAsFixed(1)} ⭐ ($feedbackCount reviews)';
  }

  @override
  String toString() => title;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
