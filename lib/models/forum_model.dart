import 'user_model.dart';

class ForumPostModel {
  final String id;
  final String userId;
  final String title;
  final String content;
  final String? category;
  final List<String>? tags;
  final int upvotes;
  final int downvotes;
  final int viewCount;
  final int commentCount;
  final bool isClosed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserModel? author;
  final int? userVote;

  ForumPostModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    this.category,
    this.tags,
    this.upvotes = 0,
    this.downvotes = 0,
    this.viewCount = 0,
    this.commentCount = 0,
    this.isClosed = false,
    required this.createdAt,
    required this.updatedAt,
    this.author,
    this.userVote,
  });

  factory ForumPostModel.fromJson(Map<String, dynamic> json) {
    return ForumPostModel(
      id: json['id'] as String,
      userId: (json['author_id'] ?? json['user_id'] ?? '') as String,
      title: json['title'] as String,
      content: json['content'] as String,
      category: json['category'] as String?,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : null,
      upvotes: json['upvotes'] as int? ?? 0,
      downvotes: json['downvotes'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      isClosed: json['is_closed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      author: json['profiles'] != null
          ? UserModel.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
      userVote: json['user_vote'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'category': category,
      'tags': tags,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'view_count': viewCount,
      'is_closed': isClosed,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  int get score => upvotes - downvotes;

  ForumPostModel copyWith({
    int? upvotes,
    int? downvotes,
    int? userVote,
    int? commentCount,
  }) {
    return ForumPostModel(
      id: id,
      userId: userId,
      title: title,
      content: content,
      category: category,
      tags: tags,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      viewCount: viewCount,
      commentCount: commentCount ?? this.commentCount,
      isClosed: isClosed,
      createdAt: createdAt,
      updatedAt: updatedAt,
      author: author,
      userVote: userVote,
    );
  }
}

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String? parentId;
  final String content;
  final int upvotes;
  final int downvotes;
  final bool isBestAnswer;
  final DateTime createdAt;
  final UserModel? author;
  final int? userVote;
  final List<CommentModel>? replies;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    this.parentId,
    required this.content,
    this.upvotes = 0,
    this.downvotes = 0,
    this.isBestAnswer = false,
    required this.createdAt,
    this.author,
    this.userVote,
    this.replies,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: (json['author_id'] ?? json['user_id'] ?? '') as String,
      parentId: json['parent_id'] as String?,
      content: json['content'] as String,
      upvotes: json['upvotes'] as int? ?? 0,
      downvotes: json['downvotes'] as int? ?? 0,
      isBestAnswer: json['is_best_answer'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      author: json['profiles'] != null
          ? UserModel.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
      userVote: json['user_vote'] as int?,
      replies: json['replies'] != null
          ? (json['replies'] as List)
              .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'parent_id': parentId,
      'content': content,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'is_best_answer': isBestAnswer,
      'created_at': createdAt.toIso8601String(),
    };
  }

  int get score => upvotes - downvotes;

  CommentModel copyWith({
    int? upvotes,
    int? downvotes,
    int? userVote,
    bool? isBestAnswer,
  }) {
    return CommentModel(
      id: id,
      postId: postId,
      userId: userId,
      parentId: parentId,
      content: content,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      isBestAnswer: isBestAnswer ?? this.isBestAnswer,
      createdAt: createdAt,
      author: author,
      userVote: userVote,
      replies: replies,
    );
  }
}
