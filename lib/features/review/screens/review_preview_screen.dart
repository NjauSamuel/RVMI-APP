import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';

/// Opens a review item from the URLs already on the review payload.
/// The gallery route only serves approved media, so this does not use it.
/// [pickFrame] pauses a video so a later moment can replace the opening poster.
class ReviewPreviewScreen extends StatefulWidget {
  const ReviewPreviewScreen({
    super.key,
    required this.url,
    required this.isVideo,
    this.pickFrame = false,
  });

  final String url;
  final bool isVideo;
  final bool pickFrame;

  @override
  State<ReviewPreviewScreen> createState() => _ReviewPreviewScreenState();
}

class _ReviewPreviewScreenState extends State<ReviewPreviewScreen> {
  VideoPlayerController? _controller;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _openVideo();
    } else {
      _loading = false;
    }
  }

  Future<void> _openVideo() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await controller.initialize();
      if (!widget.pickFrame) await controller.play();
      controller.addListener(_onTick);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _error = 'Could not play this video.';
          _loading = false;
        });
      }
    }
  }

  void _onTick() {
    if (mounted && widget.pickFrame) setState(() {});
  }

  Future<void> _useFrame() async {
    final controller = _controller;
    if (controller == null || _saving) return;
    setState(() => _saving = true);
    await controller.pause();
    try {
      final size = controller.value.size;
      final fitted = _posterSize(size.width, size.height);
      final bytes = await FcNativeVideoThumbnail().saveThumbnailToBytes(
        srcFile: widget.url,
        srcFileUri: true,
        width: fitted.$1,
        height: fitted.$2,
        format: 'jpeg',
        quality: 72,
        at: FcVideoThumbnailTime(
          controller.value.position.inMilliseconds,
          FcVideoThumbnailTimeUnit.milliseconds,
        ),
      );
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        _showFailure();
        return;
      }
      Navigator.pop(context, bytes);
    } catch (_) {
      if (mounted) _showFailure();
    }
  }

  void _showFailure() {
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not grab that frame. The opening frame stays.')),
    );
  }

  (int, int) _posterSize(double width, double height) {
    if (width <= 0 || height <= 0) return (720, 1280);
    final longEdge = width > height ? width : height;
    final scale = longEdge > 720 ? 720 / longEdge : 1;
    final fittedWidth = (width * scale).round().clamp(2, 720).toInt();
    final fittedHeight = (height * scale).round().clamp(2, 720).toInt();
    return (
      fittedWidth.isEven ? fittedWidth : fittedWidth + 1,
      fittedHeight.isEven ? fittedHeight : fittedHeight + 1,
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.pickFrame ? 'Choose frame' : ''),
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
    if (!widget.isVideo) {
      return PhotoView(
        imageProvider: NetworkImage(widget.url),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final durationMs = controller.value.duration.inMilliseconds;
    final positionMs = controller.value.position.inMilliseconds.clamp(0, durationMs == 0 ? 0 : durationMs);

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
              child: GestureDetector(
                onTap: widget.pickFrame
                    ? null
                    : () => setState(() {
                        controller.value.isPlaying ? controller.pause() : controller.play();
                      }),
                child: VideoPlayer(controller),
              ),
            ),
          ),
        ),
        if (widget.pickFrame)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Slider(
                    value: positionMs.toDouble(),
                    max: durationMs <= 0 ? 1 : durationMs.toDouble(),
                    onChanged: _saving || durationMs <= 0
                        ? null
                        : (value) => controller.seekTo(Duration(milliseconds: value.round())),
                  ),
                  FilledButton(
                    onPressed: _saving ? null : _useFrame,
                    child: Text(_saving ? 'Saving...' : 'Use this frame'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
