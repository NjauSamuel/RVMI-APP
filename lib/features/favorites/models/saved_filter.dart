import 'tag.dart';

/// A month (`YYYY-MM`), tag, event, or media kind drawn from one saved list.
class SavedFilter {
  const SavedFilter({
    this.tagId,
    this.eventId,
    this.type,
    this.savedMonth,
    this.contentMonth,
  });

  final int? tagId;
  final int? eventId;

  /// `image` or `video`.
  final String? type;

  /// Month the item was saved, `YYYY-MM`.
  final String? savedMonth;

  /// Month of the photo, or the event date, `YYYY-MM`.
  final String? contentMonth;

  bool get active =>
      tagId != null || eventId != null || type != null || savedMonth != null || contentMonth != null;

  Map<String, Object> toQuery() {
    final saved = monthBounds(savedMonth);
    final content = monthBounds(contentMonth);
    return {
      'tag_id': ?tagId,
      'event_id': ?eventId,
      'type': ?type,
      'saved_from': ?saved.$1,
      'saved_to': ?saved.$2,
      'from': ?content.$1,
      'to': ?content.$2,
    };
  }
}

class SavedFacetEvent {
  const SavedFacetEvent({required this.id, required this.title});

  factory SavedFacetEvent.fromJson(Map<String, dynamic> json) => SavedFacetEvent(
    id: json['id'] as int,
    title: json['title'] as String,
  );

  final int id;
  final String title;
}

class SavedFacets {
  const SavedFacets({
    required this.tags,
    required this.events,
    required this.types,
    required this.savedMonths,
    required this.contentMonths,
  });

  factory SavedFacets.fromJson(Map<String, dynamic> json) => SavedFacets(
    tags: (json['tags'] as List? ?? [])
        .map((tag) => Tag.fromJson(Map<String, dynamic>.from(tag as Map)))
        .toList(),
    events: (json['events'] as List? ?? [])
        .map((event) => SavedFacetEvent.fromJson(Map<String, dynamic>.from(event as Map)))
        .toList(),
    types: (json['types'] as List? ?? []).map((type) => type.toString()).toList(),
    savedMonths: (json['saved_months'] as List? ?? []).map((month) => month.toString()).toList(),
    contentMonths: (json['content_months'] as List? ?? []).map((month) => month.toString()).toList(),
  );

  final List<Tag> tags;
  final List<SavedFacetEvent> events;
  final List<String> types;
  final List<String> savedMonths;
  final List<String> contentMonths;

  bool get isEmpty =>
      tags.isEmpty && events.isEmpty && types.length < 2 && savedMonths.isEmpty && contentMonths.isEmpty;
}

(String?, String?) monthBounds(String? month) {
  if (month == null) return (null, null);
  final parts = month.split('-');
  if (parts.length != 2) return (null, null);
  final year = int.tryParse(parts[0]);
  final monthNumber = int.tryParse(parts[1]);
  if (year == null || monthNumber == null) return (null, null);
  final start = DateTime(year, monthNumber, 1);
  final end = DateTime(year, monthNumber + 1, 0, 23, 59, 59);
  return (start.toUtc().toIso8601String(), end.toUtc().toIso8601String());
}
