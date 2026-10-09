class ChurchEvent {
  const ChurchEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.eventDate,
    required this.visibility,
    required this.mediaCount,
    required this.coverThumbnailUrl,
    required this.coverBlurhash,
  });

  factory ChurchEvent.fromJson(Map<String, dynamic> json) => ChurchEvent(
    id: json['id'] as int,
    title: json['title'] as String,
    description: json['description'] as String?,
    eventDate: json['event_date'] as String?,
    visibility: json['visibility'] as String? ?? 'public',
    mediaCount: (json['media_count'] as num?)?.toInt() ?? 0,
    coverThumbnailUrl: json['cover_thumbnail_url'] as String?,
    coverBlurhash: json['cover_blurhash'] as String?,
  );

  final int id;
  final String title;
  final String? description;
  final String? eventDate;
  final String visibility;
  final int mediaCount;
  final String? coverThumbnailUrl;
  final String? coverBlurhash;

  bool get isPrivate => visibility == 'private';
}

class EventComment {
  const EventComment({
    required this.id,
    required this.body,
    required this.userName,
    required this.avatarUrl,
    required this.createdAt,
  });

  factory EventComment.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map ? Map<String, dynamic>.from(json['user'] as Map) : null;
    return EventComment(
      id: json['id'] as int,
      body: json['body'] as String,
      userName: user?['name'] as String? ?? 'Member',
      avatarUrl: user?['avatar_url'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  final int id;
  final String body;
  final String userName;
  final String? avatarUrl;
  final DateTime createdAt;
}
