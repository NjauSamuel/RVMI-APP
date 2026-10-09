import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../favorites/providers/favorites_repository.dart';
import '../providers/gallery_feed_controller.dart';
import '../widgets/media_grid.dart';

/// A single tag's own mini-timeline, e.g. every photo/video someone has
/// tagged "Samuel" - this is what a favorited/suggested chip opens into.
class TagTimelineScreen extends ConsumerWidget {
  const TagTimelineScreen({super.key, required this.tagId, required this.tagName});

  final int tagId;
  final String tagName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = GalleryFeedFilter(tagId: tagId);
    final state = ref.watch(galleryFeedControllerProvider(filter));
    final isFavorite = ref
        .watch(myFavoriteTagsProvider)
        .maybeWhen(data: (tags) => tags.any((t) => t.id == tagId), orElse: () => false);

    return Scaffold(
      appBar: AppBar(
        title: Text(tagName),
        actions: [
          IconButton(
            icon: Icon(isFavorite ? Icons.star : Icons.star_border),
            tooltip: isFavorite ? 'Remove from favorites' : 'Save as favorite',
            onPressed: () async {
              final repo = ref.read(favoritesRepositoryProvider);
              if (isFavorite) {
                await repo.unfavorite(tagId);
              } else {
                await repo.favorite(tagId);
              }
              ref.invalidate(myFavoriteTagsProvider);
            },
          ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(galleryFeedControllerProvider(filter).notifier).refresh(),
              child: MediaGrid(
                items: state.items,
                loadingMore: state.loadingMore,
                onNearEnd: () => ref.read(galleryFeedControllerProvider(filter).notifier).loadMore(),
                onOpen: (item, index) => context.push('/media/${item.id}'),
              ),
            ),
    );
  }
}
