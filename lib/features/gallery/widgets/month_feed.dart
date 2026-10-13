import 'package:flutter/material.dart';
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

const _gridPadding = 8.0;
const _tileSpacing = 4.0;

double masonryColumnWidth(double innerWidth, int columns) {
  if (columns <= 0) return innerWidth;
  final inner = innerWidth - _tileSpacing * (columns - 1);
  return inner / columns;
}

/// Height of a day's masonry so the outer list can keep a stable scroll
/// extent. Multiple [SliverMasonryGrid]s in one [CustomScrollView] jump
/// the offset back to the top once several photo days exist.
double dayMasonryHeight({
  required List<MediaItem> items,
  required int columns,
  required double columnWidth,
  double spacing = _tileSpacing,
}) {
  if (items.isEmpty || columns <= 0 || columnWidth <= 0) return 0;
  final heights = List<double>.filled(columns, 0);
  for (final item in items) {
    var col = 0;
    for (var i = 1; i < columns; i++) {
      if (heights[i] < heights[col]) col = i;
    }
    if (heights[col] > 0) heights[col] += spacing;
    final aspect = item.aspectRatio <= 0 ? 1.0 : item.aspectRatio;
    heights[col] += columnWidth / aspect;
  }
  var maxHeight = heights.first;
  for (final height in heights) {
    if (height > maxHeight) maxHeight = height;
  }
  return maxHeight;
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
  int _loadMoreAtCount = -1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant MonthGroupedFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadingMore && !widget.loadingMore) {
      if (widget.items.length == oldWidget.items.length) {
        _loadMoreAtCount = -1;
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients || widget.onNearEnd == null) return;
    if (widget.loadingMore) return;
    final max = _controller.position.maxScrollExtent;
    if (max <= 0) return;
    if (_controller.offset < max - 600) return;
    if (_loadMoreAtCount == widget.items.length) return;
    _loadMoreAtCount = widget.items.length;
    widget.onNearEnd!();
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
          width: width,
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

class _FeedRow {
  const _FeedRow.month(this.label) : day = null, startIndex = 0;

  const _FeedRow.day(this.day, this.startIndex) : label = null;

  final String? label;
  final UploadDaySection? day;
  final int startIndex;

  bool get isMonth => label != null;
}

class _FeedScroll extends StatelessWidget {
  const _FeedScroll({
    required this.controller,
    required this.width,
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
  final double width;
  final int columns;
  final List<UploadMonthSection> sections;
  final bool loadingMore;
  final bool selecting;
  final bool selectVideos;
  final Set<int> selectedIds;
  final void Function(MediaItem item, int index) onOpen;
  final void Function(MediaItem item)? onToggle;
  final void Function(MediaItem item)? onLongPress;

  List<_FeedRow> _rows() {
    final rows = <_FeedRow>[];
    var offset = 0;
    for (final section in sections) {
      rows.add(_FeedRow.month(section.label));
      for (final day in section.days) {
        rows.add(_FeedRow.day(day, offset));
        offset += day.items.length;
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    final extra = loadingMore ? 1 : 0;

    return CustomScrollView(
      controller: controller,
      cacheExtent: 1200,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= rows.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final row = rows[index];
              if (row.isMonth) {
                return _MonthLabel(key: ValueKey('month-${row.label}'), label: row.label!);
              }
              final day = row.day!;
              return _DayBlock(
                key: ValueKey('day-${day.day}'),
                day: day,
                startIndex: row.startIndex,
                width: width,
                columns: columns,
                selecting: selecting,
                selectVideos: selectVideos,
                selectedIds: selectedIds,
                onOpen: onOpen,
                onToggle: onToggle,
                onLongPress: onLongPress,
              );
            },
            childCount: rows.length + extra,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _MonthLabel extends StatelessWidget {
  const _MonthLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 18),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({
    super.key,
    required this.day,
    required this.startIndex,
    required this.width,
    required this.columns,
    required this.selecting,
    required this.selectVideos,
    required this.selectedIds,
    required this.onOpen,
    required this.onToggle,
    required this.onLongPress,
  });

  final UploadDaySection day;
  final int startIndex;
  final double width;
  final int columns;
  final bool selecting;
  final bool selectVideos;
  final Set<int> selectedIds;
  final void Function(MediaItem item, int index) onOpen;
  final void Function(MediaItem item)? onToggle;
  final void Function(MediaItem item)? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DayDivider(label: day.label),
        Padding(
          padding: const EdgeInsets.fromLTRB(_gridPadding, 0, _gridPadding, 4),
          child: _DayMasonry(
            items: day.items,
            startIndex: startIndex,
            width: width - _gridPadding * 2,
            columns: columns,
            selecting: selecting,
            selectVideos: selectVideos,
            selectedIds: selectedIds,
            onOpen: onOpen,
            onToggle: onToggle,
            onLongPress: onLongPress,
          ),
        ),
      ],
    );
  }
}

class _DayMasonry extends StatelessWidget {
  const _DayMasonry({
    required this.items,
    required this.startIndex,
    required this.width,
    required this.columns,
    required this.selecting,
    required this.selectVideos,
    required this.selectedIds,
    required this.onOpen,
    required this.onToggle,
    required this.onLongPress,
  });

  final List<MediaItem> items;
  final int startIndex;
  final double width;
  final int columns;
  final bool selecting;
  final bool selectVideos;
  final Set<int> selectedIds;
  final void Function(MediaItem item, int index) onOpen;
  final void Function(MediaItem item)? onToggle;
  final void Function(MediaItem item)? onLongPress;

  @override
  Widget build(BuildContext context) {
    final columnWidth = masonryColumnWidth(width, columns);
    final height = dayMasonryHeight(
      items: items,
      columns: columns,
      columnWidth: columnWidth,
    );
    if (height <= 0) return const SizedBox.shrink();

    final colHeights = List<double>.filled(columns, 0);
    final tiles = <Widget>[];
    for (var index = 0; index < items.length; index++) {
      var col = 0;
      for (var i = 1; i < columns; i++) {
        if (colHeights[i] < colHeights[col]) col = i;
      }
      if (colHeights[col] > 0) colHeights[col] += _tileSpacing;
      final item = items[index];
      final aspect = item.aspectRatio <= 0 ? 1.0 : item.aspectRatio;
      final tileHeight = columnWidth / aspect;
      final top = colHeights[col];
      colHeights[col] += tileHeight;
      final flatIndex = startIndex + index;
      tiles.add(
        Positioned(
          left: col * (columnWidth + _tileSpacing),
          top: top,
          width: columnWidth,
          height: tileHeight,
          child: MediaTile(
            key: ValueKey(item.id),
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
            onLongPress: onLongPress == null ? null : () => onLongPress!(item),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Stack(clipBehavior: Clip.hardEdge, children: tiles),
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
