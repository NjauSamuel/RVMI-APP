import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/media_cache.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/session_controller.dart';
import '../models/media_item.dart';
import '../providers/gallery_feed_controller.dart';
import '../providers/gallery_repository.dart';

/// The feed the viewer was opened from, so a swipe can move to the next
/// or previous photo/video without a custom transport control.
class MediaViewerArgs {
  const MediaViewerArgs({required this.items, required this.index});

  final List<MediaItem> items;
  final int index;
}

Future<void> openMediaViewer(
  BuildContext context, {
  required List<MediaItem> items,
  required int index,
}) async {
  if (items.isEmpty) return;
  final safeIndex = index.clamp(0, items.length - 1);
  await context.push(
    '/media/${items[safeIndex].id}',
    extra: MediaViewerArgs(items: items, index: safeIndex),
  );
}

/// Full-screen viewer. Loads the full-resolution image/video lazily and
/// shares or saves the actual file rather than a link, since media stays
/// scoped to signed-in users. Swipe up or down to move through the list.
class MediaViewerScreen extends ConsumerStatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.initialMediaId,
    this.items,
    this.initialIndex = 0,
  });

  final int initialMediaId;
  final List<MediaItem>? items;
  final int initialIndex;

  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _bounce;
  late final Animation<double> _bounceOffset;
  List<MediaItem> _items = const [];
  int _index = 0;
  bool _bootstrapping = true;
  bool _sharing = false;
  bool _downloading = false;
  String? _error;
  final _shareButtonKey = GlobalKey();
  bool _zoomed = false;
  bool _sideways = false;
  bool _hinted = false;
  static const _hintKey = 'rvmi.vertical_scroll_hint';

  /// Full photos already on the phone. Sliding back paints these instead of
  /// downloading them again. The grid's thumbnail cache is separate.
  final Set<int> _fullReady = {};
  final Map<int, bool> _favorite = {};

  /// +1 follows the next item, -1 follows the previous. Opening counts as +1.
  int _travel = 1;
  int? _prefetchingId;

  @override
  void initState() {
    super.initState();
    final provided = widget.items;
    if (provided != null && provided.isNotEmpty) {
      _items = List<MediaItem>.from(provided);
      _index = _resolveIndex(_items);
      _bootstrapping = false;
    }
    _pageController = PageController(initialPage: _index);
    _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _bounceOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -22), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -22, end: 14), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 14, end: -18), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -18, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeInOut));
    if (_bootstrapping) {
      _loadSingle();
    } else {
      _hintOnce();
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _hintOnce() async {
    if (_hinted) return;
    _hinted = true;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_hintKey) == true || !mounted) return;
    await prefs.setBool(_hintKey, true);
    if (mounted) _playBounce();
  }

  Future<void> _playBounce() async {
    if (!mounted || _bounce.isAnimating) return;
    await _bounce.forward(from: 0);
  }

  int _resolveIndex(List<MediaItem> items) {
    final requested = widget.initialIndex;
    if (requested >= 0 && requested < items.length && items[requested].id == widget.initialMediaId) {
      return requested;
    }
    final found = items.indexWhere((item) => item.id == widget.initialMediaId);
    return found >= 0 ? found : 0;
  }

  Future<void> _loadSingle() async {
    try {
      final item = await ref.read(galleryRepositoryProvider).show(widget.initialMediaId);
      if (!mounted) return;
      setState(() {
        _items = [item];
        _index = 0;
        _bootstrapping = false;
      });
      _hintOnce();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _bootstrapping = false;
        });
      }
    }
  }

  MediaItem? get _current => _items.isEmpty ? null : _items[_index];

  void _replaceItem(MediaItem fresh) {
    final index = _items.indexWhere((item) => item.id == fresh.id);
    if (index < 0) return;
    setState(() => _items[index] = fresh);
  }

  void _onPageChanged(int index) {
    if (index != _index) _travel = index > _index ? 1 : -1;
    setState(() => _index = index);
  }

  void _onFullReady() {
    if (!mounted || _items.isEmpty) return;
    final id = _items[_index].id;
    if (_fullReady.add(id)) setState(() {});
    if (!_items[_index].isVideo) unawaited(MediaCaches.rememberFullPhoto(id));
    unawaited(_prefetchAhead());
  }

  /// Download the next photo in the direction of travel once the current
  /// photo is on screen. Videos are left until that page is current.
  Future<void> _prefetchAhead() async {
    if (!mounted || _items.isEmpty || _prefetchingId != null) return;
    final current = _items[_index];
    if (current.isVideo || !_fullReady.contains(current.id)) return;
    final nextIndex = _index + _travel;
    if (nextIndex < 0 || nextIndex >= _items.length) return;
    final next = _items[nextIndex];
    final url = next.fullUrl;
    if (next.isVideo || url == null || _fullReady.contains(next.id)) return;

    final targetId = next.id;
    _prefetchingId = targetId;
    try {
      await precacheImage(
        CachedNetworkImageProvider(
          url,
          cacheKey: MediaCaches.fullKey(targetId),
          cacheManager: MediaCaches.fullPhotos,
        ),
        context,
      );
      if (!mounted) return;
      setState(() => _fullReady.add(targetId));
      unawaited(MediaCaches.rememberFullPhoto(targetId));
    } catch (_) {
      // The slide can still load this photo when it becomes current.
    } finally {
      if (_prefetchingId == targetId) _prefetchingId = null;
    }
    if (!mounted) return;
    final follow = _index + _travel;
    if (follow < 0 || follow >= _items.length) return;
    if (_items[follow].id != targetId) unawaited(_prefetchAhead());
  }

  Future<void> _shareAsFile() async {
    final item = _current;
    if (item?.fullUrl == null || _sharing || _downloading) return;

    setState(() => _sharing = true);
    File? prepared;
    try {
      prepared = await _materializeFullFile(item!);
      if (!mounted) return;

      final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = (box != null && box.hasSize) ? box.localToGlobal(Offset.zero) & box.size : null;
      setState(() => _sharing = false);

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              prepared.path,
              mimeType: _mimeForExtension(_extensionOf(prepared.path), video: item.isVideo),
              name: p.basename(prepared.path),
            ),
          ],
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not prepare this file to share.')),
        );
      }
    } finally {
      await _deleteIfExists(prepared);
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _downloadToGallery() async {
    final item = _current;
    if (item?.fullUrl == null || _sharing || _downloading) return;

    setState(() => _downloading = true);
    File? prepared;
    try {
      final granted = await Gal.requestAccess();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Allow photo access to save this to your gallery.')),
          );
        }
        return;
      }

      prepared = await _materializeFullFile(item!);
      if (!mounted) return;

      if (item.isVideo) {
        await Gal.putVideo(prepared.path);
      } else {
        await Gal.putImage(prepared.path);
      }
      if (!mounted) return;
      final kind = item.isVideo ? 'Video' : 'Photo';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$kind saved to your gallery.'),
          action: SnackBarAction(label: 'Open', onPressed: Gal.open),
        ),
      );
    } on GalException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_galleryErrorMessage(error))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this file to your gallery.')),
        );
      }
    } finally {
      await _deleteIfExists(prepared);
      if (mounted) setState(() => _downloading = false);
    }
  }

  /// The bytes already on screen when the full photo is cached, otherwise
  /// the original file from [MediaItem.fullUrl]. Never re-encodes.
  Future<File> _materializeFullFile(MediaItem item) async {
    final dir = await getTemporaryDirectory();
    if (!item.isVideo) {
      final cached = await MediaCaches.fullPhotos.getFileFromCache(MediaCaches.fullKey(item.id));
      if (cached != null && await cached.file.exists()) {
        final ext = _extensionOf(cached.file.path) ?? _extensionForItem(item);
        final dest = File('${dir.path}/rvmi_media_${item.id}.$ext');
        return cached.file.copy(dest.path);
      }
    }

    final fallbackExt = _extensionForItem(item);
    final staging = File('${dir.path}/rvmi_media_${item.id}.download');
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    final response = await dio.download(item.fullUrl!, staging.path);
    final ext = _extensionFromContentType(response.headers.value('content-type')) ??
        _extensionFromUrl(item.fullUrl) ??
        fallbackExt;
    final dest = File('${dir.path}/rvmi_media_${item.id}.$ext');
    if (await dest.exists()) await dest.delete();
    return staging.rename(dest.path);
  }

  bool _isFavorite(MediaItem item) => _favorite[item.id] ?? item.isFavorite;

  Future<void> _toggleFavorite() async {
    final item = _current;
    if (item == null) return;
    final next = !_isFavorite(item);
    setState(() => _favorite[item.id] = next);
    try {
      final repo = ref.read(galleryRepositoryProvider);
      if (next) {
        await repo.favorite(item.id);
      } else {
        await repo.unfavorite(item.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _favorite[item.id] = !next);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update saved photos.')),
      );
    }
  }

  Future<void> _delete() async {
    final item = _current;
    if (item == null) return;

    final kind = item.isVideo ? 'video' : 'photo';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete this $kind?'),
        content: Text('This $kind will leave the gallery. The file stays in storage.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(galleryRepositoryProvider).delete(item.id);
    ref.invalidate(galleryFeedControllerProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final canDelete = session is SessionAuthenticated && session.session.can('delete-records');
    final item = _current;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (item != null)
            IconButton(
              tooltip: 'Download',
              icon: _downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download),
              onPressed: (_downloading || _sharing) ? null : _downloadToGallery,
            ),
          if (item != null)
            IconButton(
              tooltip: _isFavorite(item) ? 'Remove from saved' : 'Save',
              icon: Icon(_isFavorite(item) ? Icons.bookmark : Icons.bookmark_border),
              onPressed: _toggleFavorite,
            ),
          if (item != null && canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          if (item != null)
            IconButton(
              key: _shareButtonKey,
              tooltip: 'Share',
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.share),
              onPressed: (_sharing || _downloading) ? null : _shareAsFile,
            ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_bootstrapping) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.white)));
    }
    if (_items.isEmpty) {
      return const Center(child: Text('Nothing to show.', style: TextStyle(color: Colors.white)));
    }

    return PhotoViewGestureDetectorScope(
      axis: Axis.vertical,
      child: Listener(
        onPointerMove: (event) {
          if (_zoomed) return;
          if (event.delta.dx.abs() > 12 && event.delta.dx.abs() > event.delta.dy.abs()) {
            _sideways = true;
          }
        },
        onPointerUp: (_) {
          if (_sideways && !_zoomed) _playBounce();
          _sideways = false;
        },
        onPointerCancel: (_) => _sideways = false,
        child: AnimatedBuilder(
          animation: _bounceOffset,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _bounceOffset.value),
            child: child,
          ),
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            allowImplicitScrolling: true,
            itemCount: _items.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final item = _items[index];
              return _ViewerPage(
                key: ValueKey(item.id),
                item: item,
                current: index == _index,
                showFull: index == _index || _fullReady.contains(item.id),
                onFullReady: _onFullReady,
                onItemRefreshed: _replaceItem,
                onZoomed: (zoomed) {
                  if (_zoomed != zoomed) setState(() => _zoomed = zoomed);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ViewerPage extends ConsumerStatefulWidget {
  const _ViewerPage({
    super.key,
    required this.item,
    required this.current,
    required this.showFull,
    required this.onFullReady,
    required this.onItemRefreshed,
    required this.onZoomed,
  });

  final MediaItem item;
  final bool current;
  final bool showFull;
  final VoidCallback onFullReady;
  final ValueChanged<MediaItem> onItemRefreshed;
  final ValueChanged<bool> onZoomed;

  @override
  ConsumerState<_ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends ConsumerState<_ViewerPage> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  bool _opening = false;
  String? _error;
  bool _recorded = false;
  int _ticket = 0;
  Timer? _bufferWatch;
  Duration _lastPosition = Duration.zero;
  DateTime _lastAdvance = DateTime.now();
  bool _buffering = false;
  bool _showPlay = false;
  bool _userPaused = false;
  ImageStream? _fullStream;
  ImageStreamListener? _fullListener;
  int? _listenedId;
  bool _reported = false;

  /// 0 is the link from the gallery list. 1 is the fresh link fetched after
  /// that request failed, usually because the signed URL had expired.
  var _generation = 0;
  var _recovering = false;
  var _gaveUp = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchFullPhoto();
  }

  @override
  void didUpdateWidget(covariant _ViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
    _watchFullPhoto();
  }

  @override
  void dispose() {
    _stopWatch();
    _ticket++;
    _bufferWatch?.cancel();
    final chewie = _chewie;
    final video = _video;
    video?.removeListener(_evaluateBuffer);
    _chewie = null;
    _video = null;
    super.dispose();
    chewie?.dispose();
    video?.dispose();
  }

  void _watchFullPhoto() {
    final item = widget.item;
    if (!widget.current || item.isVideo || item.fullUrl == null) {
      _reported = false;
      _stopWatch();
      return;
    }
    if (_listenedId == item.id) return;
    _stopWatch();
    _listenedId = item.id;
    final provider = CachedNetworkImageProvider(
      item.fullUrl!,
      cacheKey: MediaCaches.fullKey(item.id),
      cacheManager: MediaCaches.fullPhotos,
    );
    _fullStream = provider.resolve(const ImageConfiguration());
    final generation = _generation;
    _fullListener = ImageStreamListener(
      (_, _) => _reportReady(),
      onError: (_, _) => _onMediaError(generation),
    );
    _fullStream!.addListener(_fullListener!);
  }

  void _stopWatch() {
    if (_fullStream != null && _fullListener != null) {
      _fullStream!.removeListener(_fullListener!);
    }
    _fullStream = null;
    _fullListener = null;
    _listenedId = null;
  }

  void _reportReady() {
    if (_reported || !widget.current) return;
    _reported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.current) widget.onFullReady();
    });
  }

  void _sync() {
    if (widget.current && !_recorded) {
      _recorded = true;
      ref.read(galleryRepositoryProvider).recordView(widget.item.id).ignore();
    }

    final item = widget.item;
    if (!item.isVideo || item.fullUrl == null || _error != null) return;

    if (!widget.current) {
      _ticket++;
      _releasePlayer();
      return;
    }

    if (_video == null && !_opening) {
      _open(item.fullUrl!);
      return;
    }

    final video = _video;
    if (video != null && video.value.isInitialized) {
      if (widget.current) {
        video.play();
      } else {
        video.pause();
      }
    }
  }

  Future<void> _open(String url) async {
    final ticket = ++_ticket;
    _opening = true;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      if (!mounted || ticket != _ticket || !widget.current) {
        await controller.dispose();
        return;
      }
      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: widget.current,
        showControls: true,
        showOptions: false,
        showPlayButton: false,
        pauseOnBackgroundTap: true,
        allowFullScreen: false,
        allowPlaybackSpeedChanging: false,
        draggableProgressBar: true,
        placeholder: const Center(child: CircularProgressIndicator(color: Colors.white)),
        // Chewie's Android buffering check misses network stalls and shows
        // the play button instead. The page draws its own spinner.
        bufferingBuilder: (_) => const SizedBox.shrink(),
        errorBuilder: (_, _) => const Center(
          child: Text('Could not play this video.', style: TextStyle(color: Colors.white)),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.white,
          handleColor: Colors.white,
          bufferedColor: Colors.white38,
          backgroundColor: Colors.white24,
        ),
      );
      if (!widget.current) await controller.pause();
      if (!mounted || ticket != _ticket) {
        chewie.dispose();
        await controller.dispose();
        return;
      }
      controller.addListener(_evaluateBuffer);
      _lastPosition = controller.value.position;
      _lastAdvance = DateTime.now();
      _userPaused = false;
      _bufferWatch?.cancel();
      _bufferWatch = Timer.periodic(const Duration(milliseconds: 300), (_) => _evaluateBuffer());
      setState(() {
        _video = controller;
        _chewie = chewie;
        _opening = false;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted && ticket == _ticket) _onMediaError(_generation);
    }
  }

  void _releasePlayer() {
    _bufferWatch?.cancel();
    _bufferWatch = null;
    final chewie = _chewie;
    final video = _video;
    video?.removeListener(_evaluateBuffer);
    _chewie = null;
    _video = null;
    _opening = false;
    _buffering = false;
    if (chewie == null && video == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      chewie?.dispose();
      video?.dispose();
    });
  }

  /// A stall while we still expect playback is a network wait. A pause with
  /// data still buffered is the viewer pausing on purpose.
  void _evaluateBuffer() {
    final video = _video;
    if (!mounted || video == null || !video.value.isInitialized) return;
    final value = video.value;
    final atEnd = value.duration > Duration.zero &&
        value.position + const Duration(milliseconds: 400) >= value.duration;

    if (value.position != _lastPosition) {
      _lastPosition = value.position;
      _lastAdvance = DateTime.now();
    }
    if (value.isPlaying) _userPaused = false;

    final bufferEnd = value.buffered.isEmpty ? Duration.zero : value.buffered.last.end;
    final noHeadroom = value.buffered.isEmpty || value.position + const Duration(milliseconds: 300) >= bufferEnd;
    if (!value.isPlaying && !noHeadroom && !atEnd) _userPaused = true;

    final stalled = DateTime.now().difference(_lastAdvance) >= const Duration(milliseconds: 450);
    final waitingOnNetwork = !atEnd &&
        !_userPaused &&
        ((value.isPlaying && stalled) || (!value.isPlaying && noHeadroom && value.position > Duration.zero));
    final showPlay = !waitingOnNetwork && !value.isPlaying && !atEnd;

    if (waitingOnNetwork != _buffering || showPlay != _showPlay) {
      setState(() {
        _buffering = waitingOnNetwork;
        _showPlay = showPlay;
      });
    }
  }

  void _resumeFromUser() {
    final video = _video;
    if (video == null) return;
    _userPaused = false;
    _lastAdvance = DateTime.now();
    setState(() {
      _buffering = false;
      _showPlay = false;
    });
    video.play();
  }

  void _onMediaError(int generation) {
    if (!mounted || generation != _generation || _recovering || _gaveUp) return;
    if (_generation > 0) {
      setState(() {
        _gaveUp = true;
        _opening = false;
        if (widget.item.isVideo) _error = 'Could not play this video.';
      });
      return;
    }
    _recovering = true;
    unawaited(_recoverLink());
  }

  /// The gallery list holds a short-lived view link. Ask for a new one and
  /// load that, instead of leaving the failed picture on screen.
  Future<void> _recoverLink() async {
    final item = widget.item;
    try {
      final url = item.fullUrl;
      if (url != null && url.isNotEmpty) {
        await CachedNetworkImageProvider(
          url,
          cacheKey: MediaCaches.fullKey(item.id),
          cacheManager: MediaCaches.fullPhotos,
        ).evict();
      }
      try {
        await MediaCaches.fullPhotos.removeFile(MediaCaches.fullKey(item.id));
      } catch (_) {}
      final fresh = await ref.read(galleryRepositoryProvider).show(item.id);
      if (!mounted) return;
      if (fresh.fullUrl == null || fresh.fullUrl!.isEmpty) {
        setState(() {
          _recovering = false;
          _gaveUp = true;
          _opening = false;
          if (item.isVideo) _error = 'Could not play this video.';
        });
        return;
      }
      widget.onItemRefreshed(fresh);
      if (item.isVideo) {
        _ticket++;
        _releasePlayer();
      }
      setState(() {
        _recovering = false;
        _generation = 1;
        _gaveUp = false;
        _error = null;
        _opening = false;
        _reported = false;
      });
      _stopWatch();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recovering = false;
        _gaveUp = true;
        _opening = false;
        if (widget.item.isVideo) _error = 'Could not play this video.';
      });
    }
  }

  Widget _waitingPhoto(MediaItem item) {
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _cachedStandIn(item)),
          if (widget.current)
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (!item.isVideo) {
      if (!widget.showFull || item.fullUrl == null) {
        if (item.fullUrl == null && !_gaveUp) {
          final generation = _generation;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _onMediaError(generation);
          });
          return _waitingPhoto(item);
        }
        if (item.fullUrl == null && item.thumbnailUrl == null) {
          return const Center(child: Text('Could not load this photo.', style: TextStyle(color: Colors.white)));
        }
        return _cachedStandIn(item);
      }
      return PhotoView(
        key: ValueKey('${item.id}-$_generation'),
        imageProvider: CachedNetworkImageProvider(
          item.fullUrl!,
          cacheKey: MediaCaches.fullKey(item.id),
          cacheManager: MediaCaches.fullPhotos,
        ),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        gaplessPlayback: true,
        loadingBuilder: (context, event) => _waitingPhoto(item),
        errorBuilder: (context, error, stackTrace) {
          final generation = _generation;
          if (!_gaveUp) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _onMediaError(generation);
            });
            return _waitingPhoto(item);
          }
          return const Center(
            child: Text('Could not load this photo.', style: TextStyle(color: Colors.white)),
          );
        },
        scaleStateChangedCallback: widget.current
            ? (state) {
                final zoomed = state == PhotoViewScaleState.zoomedIn || state == PhotoViewScaleState.covering;
                widget.onZoomed(zoomed);
              }
            : null,
      );
    }

    if (!widget.current) {
      return _cachedStandIn(item, playMark: true);
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.white)));
    }

    final chewie = _chewie;
    if (chewie == null || _video == null || !_video!.value.isInitialized) {
      return Stack(
        alignment: Alignment.center,
        children: [
          _cachedStandIn(item),
          const CircularProgressIndicator(color: Colors.white),
        ],
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Chewie(controller: chewie),
        if (_buffering)
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
          )
        else if (_showPlay)
          IconButton(
            iconSize: 64,
            onPressed: _resumeFromUser,
            icon: const Icon(Icons.play_circle_fill, color: Colors.white70),
          ),
      ],
    );
  }
}

/// Thumbnail already stored for the grid. Used until the full photo is saved,
/// and as the poster for a video that is not the open page.
Widget _cachedStandIn(MediaItem item, {bool playMark = false}) {
  final url = item.thumbnailUrl;
  return ColoredBox(
    color: Colors.black,
    child: Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        if (url != null)
          CachedNetworkImage(
            imageUrl: url,
            cacheManager: MediaCaches.thumbs,
            cacheKey: MediaCaches.thumbKey(item.id),
            fit: BoxFit.contain,
            fadeInDuration: Duration.zero,
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
        if (playMark) const Icon(Icons.play_circle_fill, color: Colors.white70, size: 64),
      ],
    ),
  );
}

Future<void> _deleteIfExists(File? file) async {
  if (file == null) return;
  if (await file.exists()) await file.delete();
}

String? _extensionOf(String path) {
  final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
  if (ext.isEmpty || ext == 'download' || ext == 'bin') return null;
  return ext == 'jpeg' ? 'jpg' : ext;
}

String _extensionForItem(MediaItem item) {
  if (item.isVideo) return 'mp4';
  return _extensionFromUrl(item.fullUrl) ?? 'jpg';
}

String? _extensionFromUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final path = Uri.tryParse(url)?.path ?? url;
  return _extensionOf(path);
}

String? _extensionFromContentType(String? contentType) {
  if (contentType == null) return null;
  final type = contentType.split(';').first.trim().toLowerCase();
  return switch (type) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/gif' => 'gif',
    'image/heic' => 'heic',
    'image/heif' => 'heif',
    'video/mp4' => 'mp4',
    'video/quicktime' => 'mov',
    _ => null,
  };
}

String _mimeForExtension(String? extension, {required bool video}) {
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'jpg' || 'jpeg' => 'image/jpeg',
    _ => video ? 'video/mp4' : 'image/jpeg',
  };
}

String _galleryErrorMessage(GalException error) {
  return switch (error.type) {
    GalExceptionType.accessDenied => 'Allow photo access to save this to your gallery.',
    GalExceptionType.notEnoughSpace => 'Not enough storage to save this file.',
    GalExceptionType.notSupportedFormat => 'This file type cannot be saved to the gallery.',
    _ => 'Could not save this file to your gallery.',
  };
}
