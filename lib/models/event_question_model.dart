class EventQuestionModel {
  final String id;
  final String eventId;
  final String userId;
  final String question;
  final bool isAnswered;
  final int upvotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional nested data
  final String? userName;
  final String? userAvatar;
  final int answerCount;

  EventQuestionModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.question,
    this.isAnswered = false,
    this.upvotes = 0,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userAvatar,
    this.answerCount = 0,
  });

  factory EventQuestionModel.fromJson(Map<String, dynamic> json) {
    return EventQuestionModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      question: json['question'] as String,
      isAnswered: json['is_answered'] as bool? ?? false,
      upvotes: json['upvotes'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      userName: json['user_name'] as String?,
      userAvatar: json['user_avatar'] as String?,
      answerCount: json['answer_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'question': question,
      'is_answered': isAnswered,
      'upvotes': upvotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EventQuestionModel copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? question,
    bool? isAnswered,
    int? upvotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? userAvatar,
    int? answerCount,
  }) {
    return EventQuestionModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      question: question ?? this.question,
      isAnswered: isAnswered ?? this.isAnswered,
      upvotes: upvotes ?? this.upvotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      answerCount: answerCount ?? this.answerCount,
    );
  }

  @override
  String toString() => 'EventQuestion($id, $question)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventQuestionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
