class MediaTag {
  const MediaTag({required this.id, required this.name, required this.kind});

  factory MediaTag.fromJson(Map<String, dynamic> json) => MediaTag(
    id: json['id'] as int,
    name: json['name'] as String,
    kind: json['kind'] as String? ?? 'moment',
  );

  final int id;
  final String name;
  final String kind;

  bool get isPerson => kind == 'person';
}

class MediaItem {
  const MediaItem({
    required this.id,
    required this.type,
    required this.eventId,
    required this.thumbnailUrl,
    required this.fullUrl,
    required this.blurhash,
    required this.width,
    required this.height,
    required this.durationSeconds,
    required this.tags,
    required this.createdAt,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
    id: json['id'] as int,
    type: json['type'] as String? ?? 'image',
    eventId: json['event_id'] as int?,
    thumbnailUrl: json['thumbnail_url'] as String?,
    fullUrl: json['full_url'] as String?,
    blurhash: json['blurhash'] as String?,
    width: (json['width'] as num?)?.toInt(),
    height: (json['height'] as num?)?.toInt(),
    durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
    tags:
        (json['tags'] as List?)
            ?.map((e) => MediaTag.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        const [],
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now(),
  );

  final int id;
  final String type;
  final int? eventId;
  final String? thumbnailUrl;
  final String? fullUrl;
  final String? blurhash;
  final int? width;
  final int? height;
  final int? durationSeconds;
  final List<MediaTag> tags;
  final DateTime createdAt;

  bool get isVideo => type == 'video';

  double get aspectRatio {
    if (width != null && height != null && height! > 0) {
      return width! / height!;
    }
    return 1;
  }
}
