import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';

import '../models/media_item.dart';
import 'media_tile.dart';

class UploadMonthSection {
  UploadMonthSection(this.label);

  final String label;
  final List<MediaItem> items = [];
}

/// Groups a newest-first feed by upload month. A month that continues onto
/// the next page keeps a single header.
List<UploadMonthSection> groupByUploadMonth(List<MediaItem> items) {
  final sections = <UploadMonthSection>[];
  final format = DateFormat('MMMM y');

  for (final item in items) {
    final label = format.format(item.createdAt.toLocal());
    if (sections.isEmpty || sections.last.label != label) {
      sections.add(UploadMonthSection(label));
    }
    sections.last.items.add(item);
  }

  return sections;
}

/// Home feed: one outer scroll, a full-width month label, then that month's
/// masonry tiles. [onNearEnd] pages the feed.
class MonthGroupedFeed extends StatefulWidget {
  const MonthGroupedFeed({
    super.key,
    required this.items,
    required this.onOpen,
    this.onNearEnd,
    this.onToggle,
    this.onLongPress,
    this.selectedIds = const {},
    this.selecting = false,
    this.loadingMore = false,
  });

  final List<MediaItem> items;
  final void Function(MediaItem item, int index) onOpen;
  final VoidCallback? onNearEnd;
  final void Function(MediaItem item)? onToggle;
  final void Function(MediaItem item)? onLongPress;
  final Set<int> selectedIds;
  final bool selecting;
  final bool loadingMore;

  @override
  State<MonthGroupedFeed> createState() => _MonthGroupedFeedState();
}

class _MonthGroupedFeedState extends State<MonthGroupedFeed> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final threshold = _controller.position.maxScrollExtent - 600;
    if (_controller.offset >= threshold) {
      widget.onNearEnd?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = groupByUploadMonth(widget.items);
    final slivers = <Widget>[];

    var offset = 0;
    for (final section in sections) {
      final start = offset;
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
            child: Text(
              section.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childCount: section.items.length,
            itemBuilder: (context, index) {
              final item = section.items[index];
              final flatIndex = start + index;
              final aspect = item.aspectRatio <= 0 ? 1.0 : item.aspectRatio;
              return AspectRatio(
                aspectRatio: aspect,
                child: MediaTile(
                  item: item,
                  selected: widget.selectedIds.contains(item.id),
                  selectionMode: widget.selecting,
                  onTap: () {
                    if (widget.selecting) {
                      widget.onToggle?.call(item);
                      return;
                    }
                    widget.onOpen(item, flatIndex);
                  },
                  onLongPress: widget.onLongPress == null ? null : () => widget.onLongPress!(item),
                ),
              );
            },
          ),
        ),
      );
      offset += section.items.length;
    }

    if (widget.loadingMore) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));

    return CustomScrollView(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: slivers,
    );
  }
}
