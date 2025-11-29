class SocietyModel {
  final String id;
  final String name;
  final String shortName; // ACM, CLS, CSS
  final String? description;
  final String color; // Hex color for UI
  final String? icon;
  final String? logoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  SocietyModel({
    required this.id,
    required this.name,
    required this.shortName,
    this.description,
    required this.color,
    this.icon,
    this.logoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SocietyModel.fromJson(Map<String, dynamic> json) {
    return SocietyModel(
      id: json['id'] as String,
      name: json['name'] as String,
      shortName: json['short_name'] as String,
      description: json['description'] as String?,
      color: json['color'] as String,
      icon: json['icon'] as String?,
      logoUrl: json['logo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'short_name': shortName,
      'description': description,
      'color': color,
      'icon': icon,
      'logo_url': logoUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SocietyModel copyWith({
    String? id,
    String? name,
    String? shortName,
    String? description,
    String? color,
    String? icon,
    String? logoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SocietyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      logoUrl: logoUrl ?? this.logoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Society type helpers
  bool get isACM => shortName == 'ACM';
  bool get isCLS => shortName == 'CLS';
  bool get isCSS => shortName == 'CSS';

  String get displayName => shortName; // For badges and quick display
  String get fullDisplayName => '$shortName - $name'; // For details

  @override
  String toString() => shortName;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SocietyModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
