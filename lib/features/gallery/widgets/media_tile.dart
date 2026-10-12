import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

import '../../../core/media/media_cache.dart';
import '../models/media_item.dart';

/// A single grid cell: paints the BlurHash immediately, then swaps in the
/// thumbnail as soon as it's cached - the Telegram-style progressive load
/// the client explicitly asked for.
class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selectionMode = false,
    this.selectable = true,
  });

  final MediaItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool selectionMode;
  final bool selectable;

  /// Photos without a thumbnail stay on the BlurHash. The grid does not
  /// download the full original.
  String? get _previewUrl => item.thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final showMark = selectionMode && selectable;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.blurhash != null && item.blurhash!.isNotEmpty)
              BlurHash(hash: item.blurhash!)
            else
              Container(color: Colors.black12),
            if (_previewUrl != null)
              GridPreviewImage(mediaId: item.id, url: _previewUrl!),
            if (item.isVideo)
              const Align(
                alignment: Alignment.center,
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            if (selected) const ColoredBox(color: Color(0x33000000)),
            if (showMark)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: Colors.white,
                    shadows: const [
                      Shadow(blurRadius: 6, color: Colors.black54),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Grid picture cached by media id. A new signed link reuses the file
/// already on the phone, and the decode stays near the tile size so
/// scrolling back does not fill memory with full-size bitmaps.
class GridPreviewImage extends StatelessWidget {
  const GridPreviewImage({super.key, required this.mediaId, required this.url});

  final int mediaId;
  final String url;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width / 2;
        final cachePixels = (tileWidth * MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(240, 720);
        return _image(cachePixels);
      },
    );
  }

  Widget _image(int cachePixels) {
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: MediaCaches.thumbs,
      cacheKey: MediaCaches.thumbKey(mediaId),
      memCacheWidth: cachePixels,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => const ColoredBox(color: Color(0x14000000)),
      errorWidget: (_, _, _) => const ColoredBox(
        color: Color(0x14000000),
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}
