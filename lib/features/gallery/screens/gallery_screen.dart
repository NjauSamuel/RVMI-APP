import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/session_controller.dart';
import '../../favorites/widgets/for_you_rail.dart';
import '../providers/gallery_feed_controller.dart';
import '../widgets/media_grid.dart';

/// The home timeline: everything the member is allowed to see, newest
/// first, loading progressively (BlurHash -> thumbnail -> full image on
/// open) the way Telegram does.
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  static const _filter = GalleryFeedFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(galleryFeedControllerProvider(_filter));
    final session = ref.watch(sessionControllerProvider);
    final canUpload = session is SessionAuthenticated && session.session.canUpload;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/branding/rvmi_logo.png', width: 26, height: 26),
            const SizedBox(width: 10),
            const Text('RVMI Media'),
          ],
        ),
        actions: [
          if (canUpload)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: () => context.push('/upload'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(galleryFeedControllerProvider(_filter).notifier).refresh(),
        child: feed.loading
            ? const Center(child: CircularProgressIndicator())
            : feed.items.isEmpty
                ? const Center(child: Text('No photos or videos yet.'))
                : Column(
                    children: [
                      const ForYouRail(),
                      Expanded(
                        child: MediaGrid(
                          items: feed.items,
                          loadingMore: feed.loadingMore,
                          onNearEnd: () =>
                              ref.read(galleryFeedControllerProvider(_filter).notifier).loadMore(),
                          onOpen: (item, index) => context.push('/media/${item.id}'),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
