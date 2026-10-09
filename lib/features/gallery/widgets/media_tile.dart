import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

import '../models/media_item.dart';

/// A single grid cell: paints the BlurHash immediately, then swaps in the
/// thumbnail as soon as it's cached - the Telegram-style progressive load
/// the client explicitly asked for.
class MediaTile extends StatelessWidget {
  const MediaTile({super.key, required this.item, this.onTap});

  final MediaItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.blurhash != null && item.blurhash!.isNotEmpty)
              BlurHash(hash: item.blurhash!)
            else
              Container(color: Colors.black12),
            if (item.thumbnailUrl != null)
              CachedNetworkImage(
                imageUrl: item.thumbnailUrl!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            if (item.isVideo)
              const Align(
                alignment: Alignment.center,
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 32,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
