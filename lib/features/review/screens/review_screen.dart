import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/media/media_cache.dart';
import '../../../core/layout/window_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../gallery/widgets/media_tile.dart';
import '../../gallery/widgets/photo_date_sheet.dart';
import '../../events/models/event.dart';
import '../../events/providers/events_repository.dart';
import '../../gallery/providers/gallery_feed_controller.dart';
import '../models/review_item.dart';
import '../providers/review_repository.dart';
import 'review_preview_screen.dart';

/// Nothing an uploader adds becomes visible to the rest of the church
/// until it passes through here. The queue is a picture grid. Select all,
/// event, private, and approve stay on the bar. Tags and a single
/// approve or reject open from the tile, not from the picture tap.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final Set<int> _selected = {};
  bool _busy = false;
  Timer? _posterPoll;
  List<ReviewItem> _shown = const [];

  @override
  void dispose() {
    _posterPoll?.cancel();
    super.dispose();
  }

  void _syncPosterPoll(List<ReviewItem> items) {
    final waiting = items.any(
      (item) => item.isPreparing || item.thumbnailUrl == null,
    );
    if (!waiting) {
      _posterPoll?.cancel();
      _posterPoll = null;
      return;
    }
    _posterPoll ??= Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      ref.invalidate(pendingReviewProvider);
    });
  }

  Future<void> _assignEvent(List<ReviewItem> selected) async {
    List<ChurchEvent> events;
    try {
      events = await ref.read(eventsListProvider.future);
    } catch (_) {
      _showMessage('Could not load events.');
      return;
    }
    if (!mounted || events.isEmpty) {
      _showMessage('There are no events to assign.');
      return;
    }

    final eventId = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          children: [
            for (final event in events)
              ListTile(
                title: Text(event.title),
                onTap: () => Navigator.pop(context, event.id),
              ),
          ],
        ),
      ),
    );
    if (eventId == null || !mounted) return;

    await _runBatch(() async {
      await ref
          .read(reviewRepositoryProvider)
          .updateEach(
            selected.map((item) => item.id).toList(),
            eventId: eventId,
          );
      if (!mounted) return;
      ref.invalidate(pendingReviewProvider);
      _showMessage('Event set on ${selected.length} item(s).');
    });
  }

  Future<void> _setPhotoDate(List<ReviewItem> selected) async {
    final choice = await showPhotoDateSheet(context);
    if (choice == null || !mounted) return;

    await _runBatch(() async {
      await ref
          .read(reviewRepositoryProvider)
          .updateEach(
            selected.map((item) => item.id).toList(),
            takenAt: choice.useUploadDate ? null : choice.day,
            setTakenAt: true,
          );
      if (!mounted) return;
      ref.invalidate(pendingReviewProvider);
      _showMessage(
        choice.useUploadDate
            ? 'Upload date restored on ${selected.length} item(s).'
            : 'Date set on ${selected.length} item(s).',
      );
    });
  }

  Future<void> _makeVideosPrivate(List<ReviewItem> selected) async {
    final videos = selected
        .where((item) => item.isVideo)
        .map((item) => item.id)
        .toList();
    await _runBatch(() async {
      await ref
          .read(reviewRepositoryProvider)
          .updateEach(videos, visibility: 'private');
      if (!mounted) return;
      ref.invalidate(pendingReviewProvider);
      _showMessage('${videos.length} video(s) set to private.');
    });
  }

  Future<void> _approveSelected(List<ReviewItem> selected) async {
    await _runBatch(() async {
      await ref
          .read(reviewRepositoryProvider)
          .bulkApprove(selected.map((item) => item.id).toList());
      if (!mounted) return;
      setState(() => _selected.clear());
      ref.invalidate(pendingReviewProvider);
      ref.invalidate(galleryFeedControllerProvider);
    });
  }

  Future<void> _runBatch(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      _showMessage('That update did not finish.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDetails(ReviewItem item) async {
    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReviewEditor(item: item),
    );
    if (!mounted || approved == null) return;
    setState(() => _selected.remove(item.id));
    ref.invalidate(pendingReviewProvider);
    if (approved) ref.invalidate(galleryFeedControllerProvider);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingReviewProvider);
    final latest = pending.asData?.value;
    if (latest != null) _shown = latest;
    final items = _shown;
    _syncPosterPoll(items);
    final selected = items
        .where((item) => _selected.contains(item.id))
        .toList();
    final allSelected = items.isNotEmpty && selected.length == items.length;
    final hasVideo = selected.any((item) => item.isVideo);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review & approve'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                TextButton(
                  onPressed: _busy || items.isEmpty
                      ? null
                      : () => setState(() {
                          if (allSelected) {
                            _selected.clear();
                          } else {
                            _selected
                              ..clear()
                              ..addAll(items.map((item) => item.id));
                          }
                        }),
                  child: Text(allSelected ? 'Clear' : 'Select all'),
                ),
                TextButton(
                  onPressed: _busy || selected.isEmpty
                      ? null
                      : () => _assignEvent(selected),
                  child: const Text('Event'),
                ),
                TextButton(
                  onPressed: _busy || selected.isEmpty
                      ? null
                      : () => _setPhotoDate(selected),
                  child: const Text('Date'),
                ),
                TextButton(
                  onPressed: _busy || !hasVideo
                      ? null
                      : () => _makeVideosPrivate(selected),
                  child: const Text('Private'),
                ),
                TextButton(
                  onPressed: _busy || selected.isEmpty
                      ? null
                      : () => _approveSelected(selected),
                  child: Text('Approve ${selected.length}'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: items.isEmpty && pending.isLoading
          ? const Center(child: CircularProgressIndicator())
          : pending.hasError && items.isEmpty
          ? const Center(child: Text('Could not load pending items.'))
          : items.isEmpty
          ? const Center(child: Text('Nothing waiting for review.'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width;
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: photoColumnCount(width),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ReviewTile(
                      item: item,
                      selected: _selected.contains(item.id),
                      onSelectChanged: (value) => setState(() {
                        if (value) {
                          _selected.add(item.id);
                        } else {
                          _selected.remove(item.id);
                        }
                      }),
                      onOpenDetails: () => _openDetails(item),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.item,
    required this.selected,
    required this.onSelectChanged,
    required this.onOpenDetails,
  });

  final ReviewItem item;
  final bool selected;
  final ValueChanged<bool> onSelectChanged;
  final VoidCallback onOpenDetails;

  String? get _previewUrl => item.thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final preview = _previewUrl;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.brand600 : Colors.transparent,
          width: 3,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: item.fullUrl == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReviewPreviewScreen(
                            url: item.fullUrl!,
                            isVideo: item.isVideo,
                          ),
                        ),
                      );
                    },
              child: preview == null
                  ? ColoredBox(
                      color: Colors.black12,
                      child: Icon(item.isVideo ? Icons.videocam : Icons.image),
                    )
                  : GridPreviewImage(mediaId: item.id, url: preview),
            ),
            if (item.isVideo)
              const IgnorePointer(
                child: Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            if (preview == null)
              const Align(
                alignment: Alignment.bottomCenter,
                child: ColoredBox(
                  color: Colors.black54,
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Preparing',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 6,
              left: 6,
              child: _TileButton(
                icon: selected ? Icons.check : Icons.circle_outlined,
                filled: selected,
                onTap: () => onSelectChanged(!selected),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: _TileButton(icon: Icons.tune, onTap: onOpenDetails),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileButton extends StatelessWidget {
  const _TileButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.brand600 : Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

/// Event, tags, visibility, reject, and approve for one item.
/// Returns true when the item was approved, false when it was rejected.
class _ReviewEditor extends ConsumerStatefulWidget {
  const _ReviewEditor({required this.item});

  final ReviewItem item;

  @override
  ConsumerState<_ReviewEditor> createState() => _ReviewEditorState();
}

class _ReviewEditorState extends ConsumerState<_ReviewEditor> {
  late Set<int> _tagIds;
  String _visibility = 'public';
  int? _eventId;
  DateTime? _photoDate;
  bool _dateTouched = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tagIds = {...widget.item.selectedTagIds};
    _visibility = widget.item.visibility;
    _eventId = widget.item.eventId;
    _photoDate = widget.item.takenAt;
  }

  Future<void> _chooseFrame() async {
    final url = widget.item.fullUrl;
    if (url == null) return;
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) =>
            ReviewPreviewScreen(url: url, isVideo: true, pickFrame: true),
      ),
    );
    if (bytes == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(reviewRepositoryProvider)
          .update(widget.item.id, posterFrameBase64: base64Encode(bytes));
      await CachedNetworkImage.evictFromCache(
        widget.item.fullUrl ?? '',
        cacheKey: MediaCaches.thumbKey(widget.item.id),
        cacheManager: MediaCaches.thumbs,
      );
      ref.invalidate(pendingReviewProvider);
      if (mounted) {
        _showMessage('Thumbnail updated.');
        Navigator.pop(context);
      }
    } catch (_) {
      _showMessage('Could not save that frame. The opening frame stays.');
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveEdits() async {
    await ref
        .read(reviewRepositoryProvider)
        .update(
          widget.item.id,
          eventId: _eventId,
          visibility: _visibility,
          tagIds: _tagIds.toList(),
          takenAt: _photoDate,
          setTakenAt: _dateTouched,
        );
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await _saveEdits();
      await ref.read(reviewRepositoryProvider).approve(widget.item.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      _showMessage('Could not approve this item.');
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      await ref.read(reviewRepositoryProvider).reject(widget.item.id);
      if (mounted) Navigator.pop(context, false);
    } catch (_) {
      _showMessage('Could not reject this item.');
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsListProvider);
    final item = widget.item;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Item #${item.id}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(item.isPreparing ? 'Preparing ${item.type}' : item.type),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    DateFormat.yMMMd().format(
                      (_photoDate ?? item.createdAt).toLocal(),
                    ),
                  ),
                  subtitle: Text(
                    _photoDate == null ? 'Upload date' : 'Chosen date',
                  ),
                  trailing: const Icon(Icons.event_outlined),
                  onTap: _busy
                      ? null
                      : () async {
                          final choice = await showPhotoDateSheet(
                            context,
                            current: _photoDate ?? item.createdAt,
                          );
                          if (choice == null || !mounted) return;
                          setState(() {
                            _dateTouched = true;
                            _photoDate = choice.useUploadDate
                                ? null
                                : choice.day;
                          });
                        },
                ),
                if (item.isVideo && item.fullUrl != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _chooseFrame,
                    icon: const Icon(Icons.movie_filter_outlined),
                    label: const Text('Choose frame'),
                  ),
                ],
                const SizedBox(height: 12),
                events.when(
                  data: (list) => DropdownButtonFormField<int>(
                    initialValue: _eventId,
                    decoration: const InputDecoration(labelText: 'Event'),
                    items: list
                        .map(
                          (event) => DropdownMenuItem(
                            value: event.id,
                            child: Text(event.title),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _eventId = value),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.suggestedTags.map((tag) {
                    final selected = _tagIds.contains(tag.id);
                    return FilterChip(
                      label: Text(tag.name),
                      selected: selected,
                      avatar: Icon(
                        tag.kind == 'person' ? Icons.face : Icons.landscape,
                        size: 16,
                      ),
                      onSelected: _busy
                          ? null
                          : (value) => setState(() {
                              if (value) {
                                _tagIds.add(tag.id);
                              } else {
                                _tagIds.remove(tag.id);
                              }
                            }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'public', label: Text('Public')),
                    ButtonSegment(value: 'private', label: Text('Private')),
                  ],
                  selected: {_visibility},
                  onSelectionChanged: _busy
                      ? null
                      : (selection) =>
                            setState(() => _visibility = selection.first),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _reject,
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _approve,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brand600,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(_busy ? '...' : 'Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
