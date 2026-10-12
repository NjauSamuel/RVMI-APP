import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/session_controller.dart';
import '../../favorites/widgets/for_you_rail.dart';
import '../../people/providers/people_repository.dart';
import '../../review/providers/review_repository.dart';
import '../models/media_item.dart';
import '../providers/gallery_feed_controller.dart';
import '../widgets/gallery_filter_sheet.dart';
import '../widgets/month_feed.dart';
import '../widgets/photo_date_sheet.dart';
import 'media_viewer_screen.dart';

/// The home timeline: everything the member is allowed to see, newest
/// first, grouped by photo month.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  GalleryFeedFilter _filter = const GalleryFeedFilter();
  final Set<int> _selected = {};
  bool _selecting = false;
  bool _busy = false;
  final _headerHide = ValueNotifier<double>(0);
  final _headerKey = GlobalKey();

  @override
  void dispose() {
    _headerHide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(galleryFeedControllerProvider(_filter));
    final session = ref.watch(sessionControllerProvider);
    final canUpload = session is SessionAuthenticated && session.session.canUpload;
    final canManagePeople = session is SessionAuthenticated && session.session.canManagePeople;
    final canApprove = session is SessionAuthenticated && session.session.canApprove;
    final canSelect = canManagePeople || canApprove;
    final anyoneTrained = canManagePeople &&
        ref.watch(peopleListProvider).maybeWhen(
          data: (people) => people.any(
            (person) => person.indexedInRekognition || person.referenceFaceCount > 0,
          ),
          orElse: () => false,
        );

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_selecting) return;
        _clearSelection();
      },
      child: Scaffold(
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: ValueListenableBuilder<double>(
                valueListenable: _headerHide,
                builder: (context, hide, child) {
                  final extent = _headerExtent();
                  final factor = _selecting || extent <= 0 ? 1.0 : (1 - hide / extent).clamp(0.0, 1.0);
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: factor,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  key: _headerKey,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _headerBar(
                      canUpload: canUpload,
                      anyoneTrained: anyoneTrained,
                      canApprove: canApprove,
                      canManagePeople: canManagePeople,
                    ),
                    const ForYouRail(),
                  ],
                ),
              ),
            ),
            if (_selecting && canManagePeople && _selected.length > 5)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brand800
                        : AppColors.brand100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(
                      'Name this person uses 1 to 5 photos. Tag can use every selected photo.',
                    ),
                  ),
                ),
              ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onFeedScroll,
                child: RefreshIndicator(
                  onRefresh: () => ref.read(galleryFeedControllerProvider(_filter).notifier).refresh(),
                  child: feed.loading && feed.items.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : feed.items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: MediaQuery.sizeOf(context).height * 0.6,
                                  child: Center(
                                    child: Text(
                                      feed.error ??
                                          (_filter.hasConstraints
                                              ? 'Nothing matches this filter.'
                                              : 'No photos or videos yet.'),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : MonthGroupedFeed(
                              key: ValueKey(_filter),
                              items: feed.items,
                              loadingMore: feed.loadingMore,
                              selecting: _selecting,
                              selectVideos: canApprove,
                              selectedIds: _selected,
                              onNearEnd: () =>
                                  ref.read(galleryFeedControllerProvider(_filter).notifier).loadMore(),
                              onOpen: (item, index) => openMediaViewer(
                                context,
                                items: feed.items,
                                index: index,
                              ),
                              onToggle: canSelect ? _toggle : null,
                              onLongPress: canSelect ? _startSelection : null,
                            ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _headerExtent() {
    final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return 0;
    return box.size.height;
  }

  /// The logo and chips move with the finger. A short drag hides only as
  /// far as the finger moved. Naming photos keeps them fully open.
  bool _onFeedScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (_selecting) {
      if (_headerHide.value != 0) _headerHide.value = 0;
      return false;
    }
    if (notification is! ScrollUpdateNotification) return false;
    final delta = notification.scrollDelta ?? 0;
    if (notification.metrics.pixels <= 0 && delta <= 0) {
      if (_headerHide.value != 0) _headerHide.value = 0;
      return false;
    }
    if (delta == 0) return false;
    final extent = _headerExtent();
    if (extent <= 0) return false;
    final next = (_headerHide.value + delta).clamp(0.0, extent);
    if (next != _headerHide.value) _headerHide.value = next;
    return false;
  }

  Widget _headerBar({
    required bool canUpload,
    required bool anyoneTrained,
    required bool canApprove,
    required bool canManagePeople,
  }) {
    final theme = Theme.of(context);
    final bar = theme.appBarTheme;
    final title = _selecting
        ? Text('${_selected.length} selected')
        : const Row(
            children: [
              Image(image: AssetImage('assets/branding/rvmi_logo.png'), width: 26, height: 26),
              SizedBox(width: 10),
              Text('RVMI Media'),
            ],
          );
    final actions = _selecting
        ? <Widget>[
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
              if (canApprove)
                TextButton(
                  onPressed: _selected.isEmpty ? null : _setPhotoDate,
                  child: const Text('Date'),
                ),
              if (canManagePeople)
                TextButton(
                  onPressed: _nameThisPerson,
                  child: const Text('Name'),
                ),
              if (canManagePeople && anyoneTrained)
                TextButton(
                  onPressed: _tagSelected,
                  child: const Text('Tag'),
                ),
            ],
          ]
        : <Widget>[
            IconButton(
              tooltip: 'Saved',
              icon: const Icon(Icons.bookmark_border),
              onPressed: () => context.push('/saved'),
            ),
            IconButton(
              tooltip: 'Filter',
              icon: Icon(
                _filter.hasConstraints ? Icons.filter_alt : Icons.filter_alt_outlined,
                color: _filter.hasConstraints ? AppColors.brand500 : null,
              ),
              onPressed: _openFilters,
            ),
            if (canUpload)
              IconButton(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                onPressed: () => context.push('/upload'),
              ),
          ];

    return Material(
      color: bar.backgroundColor,
      child: IconTheme.merge(
        data: IconThemeData(color: bar.foregroundColor),
        child: SizedBox(
          height: kToolbarHeight,
          child: NavigationToolbar(
            leading: _selecting
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _busy ? null : _clearSelection,
                  )
                : null,
            middle: DefaultTextStyle.merge(
              style: bar.titleTextStyle,
              child: title,
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: actions),
            centerMiddle: false,
          ),
        ),
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  bool get _canApprove {
    final session = ref.read(sessionControllerProvider);
    return session is SessionAuthenticated && session.session.canApprove;
  }

  void _startSelection(MediaItem item) {
    if (_busy) return;
    if (item.isVideo && !_canApprove) return;
    setState(() {
      _selecting = true;
      _headerHide.value = 0;
      _selected.add(item.id);
    });
  }

  void _toggle(MediaItem item) {
    if (_busy) return;
    if (item.isVideo && !_canApprove) return;
    setState(() {
      if (_selected.contains(item.id)) {
        _selected.remove(item.id);
      } else {
        _selected.add(item.id);
      }
      _selecting = _selected.isNotEmpty;
    });
  }

  List<int> _selectedPhotoIds() {
    final feed = ref.read(galleryFeedControllerProvider(_filter));
    return [
      for (final item in feed.items)
        if (_selected.contains(item.id) && !item.isVideo) item.id,
    ];
  }

  Future<void> _setPhotoDate() async {
    if (_busy || _selected.isEmpty) return;
    final choice = await showPhotoDateSheet(context);
    if (choice == null || !mounted) return;

    final ids = _selected.toList();
    setState(() => _busy = true);
    try {
      await ref.read(reviewRepositoryProvider).updateEach(
        ids,
        takenAt: choice.useUploadDate ? null : choice.day,
        setTakenAt: true,
      );
      ref.invalidate(galleryFeedControllerProvider);
      if (!mounted) return;
      _message(
        choice.useUploadDate
            ? 'Upload date restored on ${ids.length} item(s).'
            : 'Date set on ${ids.length} item(s).',
      );
      _clearSelection();
    } catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFilters() async {
    final next = await showGalleryFilterSheet(context, initial: _filter);
    if (!mounted || next == null) return;
    setState(() {
      _filter = next;
      _selecting = false;
      _selected.clear();
      _headerHide.value = 0;
    });
  }

  Future<void> _nameThisPerson() async {
    if (_busy) return;
    final photoIds = _selectedPhotoIds();
    if (photoIds.isEmpty || photoIds.length > 5) {
      _message('Choose 1 to 5 photos of the same person.');
      return;
    }

    final name = await _askName();
    if (name == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final person = await ref.read(peopleRepositoryProvider).trainFromGallery(
        name: name,
        mediaItemIds: photoIds,
      );
      ref.invalidate(peopleListProvider);
      try {
        await ref.read(galleryFeedControllerProvider(_filter).notifier).refresh();
      } catch (_) {}
      if (!mounted) return;
      _message(
        person.referenceFaceCount > 0
            ? '${person.name} is ready with ${person.referenceLabel}.'
            : 'Could not find a clear face. Use photos where ${person.name} is the main face.',
      );
      _clearSelection();
    } catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _tagSelected() async {
    if (_busy || _selected.isEmpty) return;
    final photoIds = _selectedPhotoIds();
    if (photoIds.isEmpty) {
      _message('Choose approved photos to tag.');
      return;
    }
    final count = photoIds.length;
    setState(() => _busy = true);
    _message('Tagging $count ${count == 1 ? 'photo' : 'photos'}...');

    try {
      final result = await ref.read(peopleRepositoryProvider).tagSelected(photoIds);
      try {
        await ref.read(galleryFeedControllerProvider(_filter).notifier).refresh();
      } catch (_) {}
      if (!mounted) return;
      _message(_tagMessage(result));
      _clearSelection();
    } catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _tagMessage(TagSelectedResult result) {
    if (result.tagged == 0) {
      return 'No trained face in those photos.';
    }
    final tagged = 'Tagged ${result.tagged} ${result.tagged == 1 ? 'photo' : 'photos'}.';
    if (result.unmatched == 0) return tagged;
    final missed = result.unmatched == 1 ? '1 had no trained face.' : '${result.unmatched} had no trained face.';
    return '$tagged $missed';
  }

  Future<String?> _askName() {
    return showDialog<String>(
      context: context,
      builder: (context) => const _NamePersonDialog(),
    ).then((name) {
      if (name == null || name.isEmpty) return null;
      return name;
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _NamePersonDialog extends StatefulWidget {
  const _NamePersonDialog();

  @override
  State<_NamePersonDialog> createState() => _NamePersonDialogState();
}

class _NamePersonDialogState extends State<_NamePersonDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this person'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Full name'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
