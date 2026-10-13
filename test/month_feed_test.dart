import 'package:flutter_test/flutter_test.dart';
import 'package:rvmi_media/features/gallery/models/media_item.dart';
import 'package:rvmi_media/features/gallery/widgets/month_feed.dart';

MediaItem _photo({
  required int id,
  required DateTime at,
  int width = 1000,
  int height = 1000,
}) {
  return MediaItem(
    id: id,
    type: 'image',
    eventId: null,
    thumbnailUrl: null,
    fullUrl: null,
    blurhash: null,
    width: width,
    height: height,
    durationSeconds: null,
    tags: const [],
    createdAt: at,
    takenAt: at,
  );
}

void main() {
  test('groups backdated photos onto their own day without splitting later days', () {
    final now = DateTime(2026, 10, 13);
    final items = [
      _photo(id: 1, at: DateTime(2026, 10, 13, 10)),
      _photo(id: 2, at: DateTime(2026, 10, 10, 9)),
      _photo(id: 3, at: DateTime(2026, 10, 10, 8)),
      _photo(id: 4, at: DateTime(2026, 9, 1, 12)),
    ];

    final sections = groupByUploadMonth(items, now: now);

    expect(sections.map((s) => s.label).toList(), ['October 2026', 'September 2026']);
    expect(sections[0].days.map((d) => d.label).toList(), ['Today', 'Sat, 10th Oct']);
    expect(sections[0].days[0].items.map((i) => i.id), [1]);
    expect(sections[0].days[1].items.map((i) => i.id), [2, 3]);
    expect(sections[1].days.single.items.map((i) => i.id), [4]);
  });

  test('masonry height is the taller column so the list extent stays stable', () {
    final items = [
      _photo(id: 1, at: DateTime(2026, 10, 10), width: 1000, height: 2000),
      _photo(id: 2, at: DateTime(2026, 10, 10), width: 1000, height: 1000),
      _photo(id: 3, at: DateTime(2026, 10, 10), width: 1000, height: 1000),
    ];

    final height = dayMasonryHeight(items: items, columns: 2, columnWidth: 100);

    // Col 0: 200, col 1: 100 + 4 + 100 = 204.
    expect(height, 204);
  });
}
