class ReviewItem {
  ReviewItem({
    required this.id,
    required this.type,
    required this.stagingPreviewUrl,
    required this.eventId,
    required this.eventTitle,
    required this.visibility,
    required this.suggestedTags,
    required this.selectedTagIds,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    final event = json['event'] is Map ? Map<String, dynamic>.from(json['event'] as Map) : null;
    final tags = (json['tags'] as List? ?? [])
        .map((t) => ReviewTag.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList();
    return ReviewItem(
      id: json['id'] as int,
      type: json['type'] as String,
      stagingPreviewUrl: json['preview_url'] as String?,
      eventId: event?['id'] as int?,
      eventTitle: event?['title'] as String?,
      visibility: json['visibility'] as String? ?? 'public',
      suggestedTags: tags,
      selectedTagIds: tags.where((t) => t.selected).map((t) => t.id).toSet(),
    );
  }

  final int id;
  final String type;
  final String? stagingPreviewUrl;
  int? eventId;
  String? eventTitle;
  String visibility;
  List<ReviewTag> suggestedTags;
  Set<int> selectedTagIds;
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
