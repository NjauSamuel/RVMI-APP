import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/session_controller.dart';
import '../../gallery/providers/gallery_feed_controller.dart';
import '../../gallery/screens/media_viewer_screen.dart';
import '../../gallery/widgets/media_grid.dart';
import '../providers/events_repository.dart';
import '../widgets/comment_thread.dart';
import 'events_screen.dart';

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
    final canManage = session is SessionAuthenticated && session.session.canManageEvents;
    final event = eventAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: eventAsync.maybeWhen(data: (e) => Text(e.title), orElse: () => const Text('Event')),
        actions: [
          if (canManage && event != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmDeleteEvent(context, event) || !context.mounted) return;
                await ref.read(eventsRepositoryProvider).delete(event.id);
                ref.invalidate(eventsListProvider);
                ref.invalidate(deletedEventsProvider);
                if (context.mounted) context.pop();
              },
            ),
        ],
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
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (feed.loading && feed.items.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (feed.items.isNotEmpty)
              SliverToBoxAdapter(
                child: MediaGrid(
                  items: feed.items,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onOpen: (item, index) => openMediaViewer(
                    context,
                    items: feed.items,
                    index: index,
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
