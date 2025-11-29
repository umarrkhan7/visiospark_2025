class UserModel {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final String? phone;
  final String? bio;
  final String role; // 'student' or 'society_handler'
  final String? societyId; // For society handlers (ACM, CLS, CSS)
  final String? societyName; // For display purposes
  final List<String>? interests; // For students (event recommendations)
  final int participationCount; // For leaderboard
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.phone,
    this.bio,
    this.role = 'student',
    this.societyId,
    this.societyName,
    this.interests,
    this.participationCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      role: json['role'] as String? ?? 'student',
      societyId: json['society_id'] as String?,
      societyName: json['society_name'] as String?,
      interests: json['interests'] != null 
          ? List<String>.from(json['interests'] as List)
          : null,
      participationCount: json['participation_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'phone': phone,
      'bio': bio,
      'role': role,
      'society_id': societyId,
      'society_name': societyName,
      'interests': interests,
      'participation_count': participationCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? avatarUrl,
    String? phone,
    String? bio,
    String? role,
    String? societyId,
    String? societyName,
    List<String>? interests,
    int? participationCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      societyId: societyId ?? this.societyId,
      societyName: societyName ?? this.societyName,
      interests: interests ?? this.interests,
      participationCount: participationCount ?? this.participationCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayName => fullName ?? email.split('@').first;

  String get initials {
    if (fullName != null && fullName!.isNotEmpty) {
      final parts = fullName!.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return parts[0][0].toUpperCase();
    }
    return email[0].toUpperCase();
  }

  // Role-based getters
  bool get isStudent => role == 'student';
  bool get isSocietyHandler => role == 'society_handler';
  
  // Society helper
  bool get hasSociety => societyId != null && societyId!.isNotEmpty;
  
  // Helper for display
  String get roleDisplay {
    switch (role) {
      case 'society_handler':
        return hasSociety ? 'Society Handler ($societyName)' : 'Society Handler';
      case 'student':
      default:
        return 'Student';
    }
  }
}
