import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_item.dart';
import 'gallery_repository.dart';

class GalleryFeedFilter {
  const GalleryFeedFilter({
    this.eventId,
    this.tagId,
    this.from,
    this.to,
    this.type,
  });

  final int? eventId;
  final int? tagId;

  /// Inclusive range as ISO-8601 instants. Null means that side is open.
  final String? from;
  final String? to;

  /// `image`, `video`, or null for both.
  final String? type;

  bool get hasConstraints =>
      eventId != null || tagId != null || from != null || to != null || type != null;

  @override
  bool operator ==(Object other) =>
      other is GalleryFeedFilter &&
      other.eventId == eventId &&
      other.tagId == tagId &&
      other.from == from &&
      other.to == to &&
      other.type == type;

  @override
  int get hashCode => Object.hash(eventId, tagId, from, to, type);
}

class GalleryFeedState {
  const GalleryFeedState({
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final List<MediaItem> items;
  final int page;
  final bool hasMore;
  final bool loading;
  final bool loadingMore;
  final String? error;

  GalleryFeedState copyWith({
    List<MediaItem>? items,
    int? page,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    String? error,
  }) {
    return GalleryFeedState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error,
    );
  }
}

/// Paginated, Telegram-style timeline feed. One instance per filter (all
/// media, a single event, or a single tag) via the family param.
class GalleryFeedController extends Notifier<GalleryFeedState> {
  GalleryFeedController(this.arg);

  final GalleryFeedFilter arg;

  @override
  GalleryFeedState build() {
    Future.microtask(refresh);
    return const GalleryFeedState(loading: true);
  }

  Future<void> refresh() async {
    if (!ref.mounted) return;
    state = state.copyWith(loading: state.items.isEmpty, error: null);
    try {
      final result = await ref.read(galleryRepositoryProvider).fetch(
        page: 1,
        eventId: arg.eventId,
        tagId: arg.tagId,
        from: arg.from,
        to: arg.to,
        type: arg.type,
      );
      if (!ref.mounted) return;
      state = GalleryFeedState(
        items: result.items,
        page: result.currentPage,
        hasMore: result.hasMore,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!ref.mounted || state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final result = await ref.read(galleryRepositoryProvider).fetch(
        page: state.page + 1,
        eventId: arg.eventId,
        tagId: arg.tagId,
        from: arg.from,
        to: arg.to,
        type: arg.type,
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        items: [...state.items, ...result.items],
        page: result.currentPage,
        hasMore: result.hasMore,
        loadingMore: false,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(loadingMore: false);
    }
  }
}

final galleryFeedControllerProvider = NotifierProvider.autoDispose
    .family<GalleryFeedController, GalleryFeedState, GalleryFeedFilter>(
  GalleryFeedController.new,
);
