import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models/media_item.dart';
import 'media_tile.dart';

/// A masonry grid sized from each item's aspect ratio. Only visible tiles
/// are built, and [onNearEnd] fires once the user scrolls close to the
/// bottom so the feed can paginate.
class MediaGrid extends StatefulWidget {
  const MediaGrid({
    super.key,
    required this.items,
    required this.onOpen,
    this.onNearEnd,
    this.loadingMore = false,
    this.crossAxisCount = 2,
    this.shrinkWrap = false,
    this.physics,
  });

  final List<MediaItem> items;
  final void Function(MediaItem item, int index) onOpen;
  final VoidCallback? onNearEnd;
  final bool loadingMore;
  final int crossAxisCount;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  State<MediaGrid> createState() => _MediaGridState();
}

class _MediaGridState extends State<MediaGrid> {
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
    final extra = widget.loadingMore ? widget.crossAxisCount : 0;
    return MasonryGridView.count(
      controller: _controller,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      crossAxisCount: widget.crossAxisCount,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      itemCount: widget.items.length + extra,
      itemBuilder: (context, index) {
        if (index >= widget.items.length) {
          return const AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0x11000000)),
            ),
          );
        }
        final item = widget.items[index];
        final aspect = item.aspectRatio <= 0 ? 1.0 : item.aspectRatio;
        return AspectRatio(
          aspectRatio: aspect,
          child: MediaTile(item: item, onTap: () => widget.onOpen(item, index)),
        );
      },
    );
  }
}
