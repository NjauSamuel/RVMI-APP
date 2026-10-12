import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
import '../models/review_item.dart';

class ReviewRepository {
  ReviewRepository(this.ref);

  final Ref ref;

  Future<List<ReviewItem>> pending() async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>('/review/pending');
    return (response.data!['data'] as List)
        .map((e) => ReviewItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> update(
    int mediaItemId, {
    int? eventId,
    String? visibility,
    List<int>? tagIds,
    String? posterFrameBase64,
    DateTime? takenAt,
    bool setTakenAt = false,
  }) async {
    final client = ref.read(apiClientProvider);
    await client.patch<void>(
      '/review/$mediaItemId',
      data: {
        'event_id': ?eventId,
        'visibility_override': ?visibility,
        'tag_ids': ?tagIds,
        'poster_frame_base64': ?posterFrameBase64,
        if (setTakenAt) 'taken_at': _photoDate(takenAt),
      },
    );
  }

  /// Applies one event, visibility, or photo-date change to each id.
  Future<void> updateEach(
    List<int> mediaItemIds, {
    int? eventId,
    String? visibility,
    DateTime? takenAt,
    bool setTakenAt = false,
  }) async {
    for (final id in mediaItemIds) {
      await update(
        id,
        eventId: eventId,
        visibility: visibility,
        takenAt: takenAt,
        setTakenAt: setTakenAt,
      );
    }
  }

  String? _photoDate(DateTime? day) {
    if (day == null) return null;
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  Future<void> approve(int mediaItemId) async {
    final client = ref.read(apiClientProvider);
    await client.post<void>('/review/$mediaItemId/approve');
  }

  Future<void> bulkApprove(List<int> mediaItemIds) async {
    final client = ref.read(apiClientProvider);
    await client.post<void>('/review/bulk-approve', data: {'media_item_ids': mediaItemIds});
  }

  Future<void> reject(int mediaItemId) async {
    final client = ref.read(apiClientProvider);
    await client.post<void>('/review/$mediaItemId/reject');
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref);
});

final pendingReviewProvider = FutureProvider.autoDispose<List<ReviewItem>>((ref) {
  return ref.read(reviewRepositoryProvider).pending();
});
