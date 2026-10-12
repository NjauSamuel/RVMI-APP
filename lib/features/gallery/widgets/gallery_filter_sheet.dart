import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../events/models/event.dart';
import '../../events/providers/events_repository.dart';
import '../../favorites/models/tag.dart';
import '../../favorites/providers/favorites_repository.dart';
import '../providers/gallery_feed_controller.dart';

Future<GalleryFeedFilter?> showGalleryFilterSheet(
  BuildContext context, {
  required GalleryFeedFilter initial,
}) {
  return showModalBottomSheet<GalleryFeedFilter>(
    context: context,
    isScrollControlled: true,
    builder: (context) => GalleryFilterSheet(initial: initial),
  );
}

enum _DatePreset { any, thisMonth, last3Months, thisYear, custom }

enum _MediaKind { both, photos, videos }

class GalleryFilterSheet extends ConsumerStatefulWidget {
  const GalleryFilterSheet({super.key, required this.initial});

  final GalleryFeedFilter initial;

  @override
  ConsumerState<GalleryFilterSheet> createState() => _GalleryFilterSheetState();
}

class _GalleryFilterSheetState extends ConsumerState<GalleryFilterSheet> {
  late _DatePreset _preset;
  late DateTime? _customFrom;
  late DateTime? _customTo;
  late _MediaKind _kind;
  late int? _tagId;
  late int? _eventId;
  late Future<List<Tag>> _tags;
  late Future<List<ChurchEvent>> _events;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _preset = initial.from == null && initial.to == null ? _DatePreset.any : _DatePreset.custom;
    _customFrom = DateTime.tryParse(initial.from ?? '')?.toLocal();
    _customTo = DateTime.tryParse(initial.to ?? '')?.toLocal();
    _kind = switch (initial.type) {
      'image' => _MediaKind.photos,
      'video' => _MediaKind.videos,
      _ => _MediaKind.both,
    };
    _tagId = initial.tagId;
    _eventId = initial.eventId;
    _tags = ref.read(favoritesRepositoryProvider).searchTags();
    _events = ref.read(eventsRepositoryProvider).listAll();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text('Filter', style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                children: [
                  const _SectionLabel('Date'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip('Any time', _DatePreset.any),
                      _chip('This month', _DatePreset.thisMonth),
                      _chip('Last 3 months', _DatePreset.last3Months),
                      _chip('This year', _DatePreset.thisYear),
                      _chip('Custom', _DatePreset.custom),
                    ],
                  ),
                  if (_preset == _DatePreset.custom) ...[
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start'),
                      trailing: Text(_formatDay(_customFrom)),
                      onTap: () => _pickDate(start: true),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End'),
                      trailing: Text(_formatDay(_customTo)),
                      onTap: () => _pickDate(start: false),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const _SectionLabel('Tag'),
                  FutureBuilder<List<Tag>>(
                    future: _tags,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text('Could not load tags.');
                      }
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: LinearProgressIndicator(),
                        );
                      }
                      final tags = snapshot.data!;
                      return DropdownButtonFormField<int?>(
                        initialValue: tags.any((tag) => tag.id == _tagId) ? _tagId : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Tag'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Any tag')),
                          for (final tag in tags)
                            DropdownMenuItem<int?>(value: tag.id, child: Text(tag.name)),
                        ],
                        onChanged: (value) => setState(() => _tagId = value),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const _SectionLabel('Event'),
                  FutureBuilder<List<ChurchEvent>>(
                    future: _events,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text('Could not load events.');
                      }
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: LinearProgressIndicator(),
                        );
                      }
                      final events = snapshot.data!;
                      return DropdownButtonFormField<int?>(
                        initialValue: events.any((event) => event.id == _eventId) ? _eventId : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Event'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Any event')),
                          for (final event in events)
                            DropdownMenuItem<int?>(value: event.id, child: Text(event.title)),
                        ],
                        onChanged: (value) => setState(() => _eventId = value),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const _SectionLabel('Media'),
                  SegmentedButton<_MediaKind>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: _MediaKind.both, label: Text('Both')),
                      ButtonSegment(value: _MediaKind.photos, label: Text('Photos')),
                      ButtonSegment(value: _MediaKind.videos, label: Text('Videos')),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (value) => setState(() => _kind = value.first),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(const GalleryFeedFilter()),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _apply,
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, _DatePreset preset) {
    return ChoiceChip(
      label: Text(label),
      selected: _preset == preset,
      onSelected: (_) => setState(() => _preset = preset),
    );
  }

  String _formatDay(DateTime? day) => day == null ? 'Choose' : DateFormat.yMMMd().format(day);

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _customFrom : _customTo) ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _customFrom = picked;
      } else {
        _customTo = picked;
      }
    });
  }

  void _apply() {
    if (_preset == _DatePreset.custom) {
      if (_customFrom == null || _customTo == null) {
        _sheetMessage('Choose a start and an end date.');
        return;
      }
      final fromDay = DateTime(_customFrom!.year, _customFrom!.month, _customFrom!.day);
      final toDay = DateTime(_customTo!.year, _customTo!.month, _customTo!.day);
      if (fromDay.isAfter(toDay)) {
        _sheetMessage('The start date has to be on or before the end date.');
        return;
      }
    }

    final range = _bounds();
    final type = switch (_kind) {
      _MediaKind.both => null,
      _MediaKind.photos => 'image',
      _MediaKind.videos => 'video',
    };

    Navigator.of(context).pop(
      GalleryFeedFilter(
        eventId: _eventId,
        tagId: _tagId,
        from: range.$1,
        to: range.$2,
        type: type,
      ),
    );
  }

  (String?, String?) _bounds() {
    final now = DateTime.now();
    String start(DateTime day) => DateTime(day.year, day.month, day.day).toUtc().toIso8601String();
    String end(DateTime day) => DateTime(day.year, day.month, day.day, 23, 59, 59).toUtc().toIso8601String();

    return switch (_preset) {
      _DatePreset.any => (null, null),
      _DatePreset.thisMonth => (start(DateTime(now.year, now.month, 1)), end(now)),
      _DatePreset.last3Months => (start(DateTime(now.year, now.month - 2, 1)), end(now)),
      _DatePreset.thisYear => (start(DateTime(now.year, 1, 1)), end(now)),
      _DatePreset.custom => (start(_customFrom!), end(_customTo!)),
    };
  }

  void _sheetMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: dark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
      ),
    );
  }
}
