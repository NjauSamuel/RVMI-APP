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
  }) async {
    final client = ref.read(apiClientProvider);
    await client.patch<void>(
      '/review/$mediaItemId',
      data: {
        if (eventId != null) 'event_id': eventId,
        if (visibility != null) 'visibility_override': visibility,
        if (tagIds != null) 'tag_ids': tagIds,
        if (posterFrameBase64 != null) 'poster_frame_base64': posterFrameBase64,
      },
    );
  }

  /// Applies one event or visibility change to each id through the existing update.
  Future<void> updateEach(
    List<int> mediaItemIds, {
    int? eventId,
    String? visibility,
  }) async {
    for (final id in mediaItemIds) {
      await update(id, eventId: eventId, visibility: visibility);
    }
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
