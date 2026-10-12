class ReviewItem {
  ReviewItem({
    required this.id,
    required this.type,
    required this.status,
    required this.thumbnailUrl,
    required this.fullUrl,
    required this.eventId,
    required this.eventTitle,
    required this.visibility,
    required this.suggestedTags,
    required this.selectedTagIds,
    required this.createdAt,
    this.takenAt,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    final event = json['event'] is Map ? Map<String, dynamic>.from(json['event'] as Map) : null;
    final tags = (json['tags'] as List? ?? [])
        .map((t) => ReviewTag.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList();
    return ReviewItem(
      id: json['id'] as int,
      type: json['type'] as String,
      status: json['status'] as String? ?? 'pending_review',
      thumbnailUrl: json['thumbnail_url'] as String?,
      fullUrl: json['full_url'] as String?,
      eventId: event?['id'] as int?,
      eventTitle: event?['title'] as String?,
      visibility: json['visibility_override'] as String? ?? 'public',
      suggestedTags: tags,
      selectedTagIds: tags.where((t) => t.selected).map((t) => t.id).toSet(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      takenAt: DateTime.tryParse(json['taken_at']?.toString() ?? ''),
    );
  }

  final int id;
  final String type;
  final String status;
  final String? thumbnailUrl;
  final String? fullUrl;

  bool get isVideo => type == 'video';

  bool get isPreparing => status == 'pending_processing';
  int? eventId;
  String? eventTitle;
  String visibility;
  List<ReviewTag> suggestedTags;
  Set<int> selectedTagIds;
  final DateTime createdAt;
  final DateTime? takenAt;
}

class ReviewTag {
  ReviewTag({required this.id, required this.name, required this.kind, required this.selected});

  factory ReviewTag.fromJson(Map<String, dynamic> json) => ReviewTag(
    id: json['id'] as int,
    name: json['name'] as String,
    kind: json['kind'] as String? ?? 'scene',
    selected: json['selected'] as bool? ?? true,
  );

  final int id;
  final String name;
  final String kind;
  bool selected;
}
