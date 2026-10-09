import 'package:flutter/material.dart';

import '../models/media_item.dart';
import 'media_tile.dart';

/// A virtualized grid (only visible tiles are ever built/laid out, courtesy
/// of `GridView.builder`) that calls [onNearEnd] once the user scrolls
/// close to the bottom, driving pagination.
class MediaGrid extends StatefulWidget {
  const MediaGrid({
    super.key,
    required this.items,
    required this.onOpen,
    this.onNearEnd,
    this.loadingMore = false,
    this.crossAxisCount = 3,
  });

  final List<MediaItem> items;
  final void Function(MediaItem item, int index) onOpen;
  final VoidCallback? onNearEnd;
  final bool loadingMore;
  final int crossAxisCount;

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
    return GridView.builder(
      controller: _controller,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      itemCount: widget.items.length + (widget.loadingMore ? widget.crossAxisCount : 0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        if (index >= widget.items.length) {
          return const DecoratedBox(
            decoration: BoxDecoration(color: Color(0x11000000)),
          );
        }
        final item = widget.items[index];
        return MediaTile(item: item, onTap: () => widget.onOpen(item, index));
      },
    );
  }
}
