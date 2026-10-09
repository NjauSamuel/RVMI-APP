import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/session_controller.dart';
import '../../gallery/providers/gallery_feed_controller.dart';
import '../providers/events_repository.dart';
import '../widgets/comment_thread.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final int eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(FutureProvider((ref) => ref.read(eventsRepositoryProvider).show(eventId)));
    final filter = GalleryFeedFilter(eventId: eventId);
    final feed = ref.watch(galleryFeedControllerProvider(filter));
    final session = ref.watch(sessionControllerProvider);
    final canUpload = session is SessionAuthenticated && session.session.canUpload;

    return Scaffold(
      appBar: AppBar(
        title: eventAsync.maybeWhen(data: (e) => Text(e.title), orElse: () => const Text('Event')),
      ),
      floatingActionButton: canUpload
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/upload?event_id=$eventId'),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add media'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(galleryFeedControllerProvider(filter).notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: feed.loading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox.shrink(),
            ),
            if (!feed.loading)
              SliverPadding(
                padding: const EdgeInsets.all(8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = feed.items[index];
                      return GestureDetector(
                        onTap: () => context.push('/media/${item.id}'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: item.thumbnailUrl != null
                              ? Image.network(item.thumbnailUrl!, fit: BoxFit.cover)
                              : Container(color: Colors.black12),
                        ),
                      );
                    },
                    childCount: feed.items.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(child: CommentThread(eventId: eventId)),
          ],
        ),
      ),
    );
  }
}
