import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/window_layout.dart';
import '../models/media_item.dart';
import 'media_tile.dart';

class UploadDaySection {
  UploadDaySection(this.label, this.day);

  final String label;
  final DateTime day;
  final List<MediaItem> items = [];
}

class UploadMonthSection {
  UploadMonthSection(this.label);

  final String label;
  final List<UploadDaySection> days = [];
}

/// Groups a newest-first feed by photo month, then by calendar day. A chosen
/// date wins; otherwise the day is when the file was uploaded. A month or
/// day that continues onto the next page keeps a single header.
List<UploadMonthSection> groupByUploadMonth(
  List<MediaItem> items, {
  DateTime? now,
}) {
  final sections = <UploadMonthSection>[];
  final monthFormat = DateFormat('MMMM y');
  final clock = now ?? DateTime.now();

  for (final item in items) {
    final at = item.displayAt.toLocal();
    final monthLabel = monthFormat.format(at);
    if (sections.isEmpty || sections.last.label != monthLabel) {
      sections.add(UploadMonthSection(monthLabel));
    }

    final day = DateTime(at.year, at.month, at.day);
    final days = sections.last.days;
    if (days.isEmpty || !_sameDay(days.last.day, day)) {
      days.add(UploadDaySection(dayDividerLabel(at, clock), day));
    }
    days.last.items.add(item);
  }

  return sections;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// `Today`, `Yesterday`, or a weekday plus ordinal such as `Sat, 10th Oct`.
String dayDividerLabel(DateTime at, DateTime now) {
  final local = at.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  final weekday = DateFormat('EEE').format(local);
  return '$weekday, ${_ordinal(local.day)} ${DateFormat('MMM').format(local)}';
}

String _ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}

/// Home feed: one outer scroll, a full-width month label, date dividers,
/// then that day's masonry tiles. [onNearEnd] pages the feed.
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
    this.selectVideos = false,
    this.loadingMore = false,
  });

  final List<MediaItem> items;
  final void Function(MediaItem item, int index) onOpen;
  final VoidCallback? onNearEnd;
  final void Function(MediaItem item)? onToggle;
  final void Function(MediaItem item)? onLongPress;
  final Set<int> selectedIds;
  final bool selecting;
  final bool selectVideos;
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return _FeedScroll(
          controller: _controller,
          columns: photoColumnCount(width),
          sections: groupByUploadMonth(widget.items),
          loadingMore: widget.loadingMore,
          selecting: widget.selecting,
          selectVideos: widget.selectVideos,
          selectedIds: widget.selectedIds,
          onOpen: widget.onOpen,
          onToggle: widget.onToggle,
          onLongPress: widget.onLongPress,
        );
      },
    );
  }
}

class _FeedScroll extends StatelessWidget {
  const _FeedScroll({
    required this.controller,
    required this.columns,
    required this.sections,
    required this.loadingMore,
    required this.selecting,
    required this.selectVideos,
    required this.selectedIds,
    required this.onOpen,
    required this.onToggle,
    required this.onLongPress,
  });

  final ScrollController controller;
  final int columns;
  final List<UploadMonthSection> sections;
  final bool loadingMore;
  final bool selecting;
  final bool selectVideos;
  final Set<int> selectedIds;
  final void Function(MediaItem item, int index) onOpen;
  final void Function(MediaItem item)? onToggle;
  final void Function(MediaItem item)? onLongPress;

  @override
  Widget build(BuildContext context) {
    final slivers = <Widget>[];
    var offset = 0;

    for (final section in sections) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 18),
            child: Text(
              section.label,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );

      for (final day in section.days) {
        final start = offset;
        slivers.add(SliverToBoxAdapter(child: _DayDivider(label: day.label)));
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: columns,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childCount: day.items.length,
              itemBuilder: (context, index) {
                final item = day.items[index];
                final flatIndex = start + index;
                final aspect = item.aspectRatio <= 0 ? 1.0 : item.aspectRatio;
                return AspectRatio(
                  aspectRatio: aspect,
                  child: MediaTile(
                    item: item,
                    selected: selectedIds.contains(item.id),
                    selectionMode: selecting,
                    selectable: !item.isVideo || selectVideos,
                    onTap: () {
                      if (selecting) {
                        onToggle?.call(item);
                        return;
                      }
                      onOpen(item, flatIndex);
                    },
                    onLongPress: onLongPress == null
                        ? null
                        : () => onLongPress!(item),
                  ),
                );
              },
            ),
          ),
        );
        offset += day.items.length;
      }
    }

    if (loadingMore) {
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
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: slivers,
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = theme.colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        children: [
          Expanded(child: Divider(height: 1, thickness: 1, color: line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(height: 1, thickness: 1, color: line)),
        ],
      ),
    );
  }
}
