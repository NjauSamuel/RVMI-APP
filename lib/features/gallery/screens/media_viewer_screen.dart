import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../models/media_item.dart';
import '../providers/gallery_repository.dart';

/// Full-screen single-item viewer. Loads the full-resolution image/video
/// lazily (only once the user opens it, per the Telegram-style loading
/// strategy) and shares the *actual file* to WhatsApp/etc rather than a
/// link - required since media stays scoped to signed-in users.
class MediaViewerScreen extends ConsumerStatefulWidget {
  const MediaViewerScreen({super.key, required this.initialMediaId});

  final int initialMediaId;

  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  MediaItem? _item;
  bool _loading = true;
  bool _sharing = false;
  String? _error;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(galleryRepositoryProvider);
      final item = await repo.show(widget.initialMediaId);
      await repo.recordView(widget.initialMediaId);

      if (item.isVideo && item.fullUrl != null) {
        final controller = VideoPlayerController.networkUrl(Uri.parse(item.fullUrl!));
        await controller.initialize();
        _videoController = controller;
      }

      if (mounted) setState(() { _item = item; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _shareAsFile() async {
    final item = _item;
    if (item?.fullUrl == null) return;

    setState(() => _sharing = true);
    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        item!.fullUrl!,
        options: Options(responseType: ResponseType.bytes),
      );

      final dir = await getTemporaryDirectory();
      final extension = item.isVideo ? 'mp4' : 'jpg';
      final file = File('${dir.path}/rvmi_media_${item.id}.$extension');
      await file.writeAsBytes(response.data!);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_item != null)
            IconButton(
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.share),
              onPressed: _sharing ? null : _shareAsFile,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.white)));
    }

    final item = _item!;

    if (item.isVideo) {
      final controller = _videoController;
      if (controller == null || !controller.value.isInitialized) {
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      }
      return Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: GestureDetector(
            onTap: () => setState(() {
              controller.value.isPlaying ? controller.pause() : controller.play();
            }),
            child: VideoPlayer(controller),
          ),
        ),
      );
    }

    return PhotoView(
      imageProvider: NetworkImage(item.fullUrl!),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 3,
    );
  }
}
