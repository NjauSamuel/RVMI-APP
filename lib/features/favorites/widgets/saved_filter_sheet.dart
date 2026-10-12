import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../models/saved_filter.dart';

/// Filter choices are the tags, events, and months present in that saved list.
Future<SavedFilter?> showSavedFilterSheet(
  BuildContext context, {
  required SavedFacets facets,
  required SavedFilter initial,
  required bool photos,
}) {
  return showModalBottomSheet<SavedFilter>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SavedFilterSheet(facets: facets, initial: initial, photos: photos),
  );
}

class SavedFilterSheet extends StatefulWidget {
  const SavedFilterSheet({
    super.key,
    required this.facets,
    required this.initial,
    required this.photos,
  });

  final SavedFacets facets;
  final SavedFilter initial;
  final bool photos;

  @override
  State<SavedFilterSheet> createState() => _SavedFilterSheetState();
}

class _SavedFilterSheetState extends State<SavedFilterSheet> {
  late int? _tagId;
  late int? _eventId;
  late String? _type;
  late String? _savedMonth;
  late String? _contentMonth;

  @override
  void initState() {
    super.initState();
    final facets = widget.facets;
    final initial = widget.initial;
    _tagId = facets.tags.any((tag) => tag.id == initial.tagId) ? initial.tagId : null;
    _eventId = facets.events.any((event) => event.id == initial.eventId) ? initial.eventId : null;
    _type = facets.types.contains(initial.type) ? initial.type : null;
    _savedMonth = facets.savedMonths.contains(initial.savedMonth) ? initial.savedMonth : null;
    _contentMonth = facets.contentMonths.contains(initial.contentMonth) ? initial.contentMonth : null;
  }

  @override
  Widget build(BuildContext context) {
    final facets = widget.facets;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
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
                  if (facets.isEmpty)
                    const Text('Nothing in this list to filter by yet.')
                  else ...[
                    if (facets.tags.isNotEmpty) ...[
                      const _SectionLabel('Tag'),
                      _choice<int>(
                        label: 'Tag',
                        value: _tagId,
                        anyLabel: 'Any tag in saved',
                        options: [
                          for (final tag in facets.tags) (value: tag.id, label: tag.name),
                        ],
                        onChanged: (value) => setState(() => _tagId = value),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (widget.photos && facets.events.isNotEmpty) ...[
                      const _SectionLabel('Event'),
                      _choice<int>(
                        label: 'Event',
                        value: _eventId,
                        anyLabel: 'Any saved event',
                        options: [
                          for (final event in facets.events) (value: event.id, label: event.title),
                        ],
                        onChanged: (value) => setState(() => _eventId = value),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (facets.savedMonths.isNotEmpty) ...[
                      const _SectionLabel('Saved'),
                      _choice<String>(
                        label: 'Saved',
                        value: _savedMonth,
                        anyLabel: 'Any time saved',
                        options: [
                          for (final month in facets.savedMonths) (value: month, label: _monthLabel(month)),
                        ],
                        onChanged: (value) => setState(() => _savedMonth = value),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (facets.contentMonths.isNotEmpty) ...[
                      _SectionLabel(widget.photos ? 'Added' : 'Event date'),
                      _choice<String>(
                        label: widget.photos ? 'Added' : 'Event date',
                        value: _contentMonth,
                        anyLabel: widget.photos ? 'Any time added' : 'Any event date',
                        options: [
                          for (final month in facets.contentMonths) (value: month, label: _monthLabel(month)),
                        ],
                        onChanged: (value) => setState(() => _contentMonth = value),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (widget.photos && facets.types.length > 1) ...[
                      const _SectionLabel('Media'),
                      SegmentedButton<String?>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: null, label: Text('Both')),
                          ButtonSegment(value: 'image', label: Text('Photos')),
                          ButtonSegment(value: 'video', label: Text('Videos')),
                        ],
                        selected: {_type},
                        onSelectionChanged: (value) => setState(() => _type = value.first),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(const SavedFilter()),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        SavedFilter(
                          tagId: _tagId,
                          eventId: _eventId,
                          type: _type,
                          savedMonth: _savedMonth,
                          contentMonth: _contentMonth,
                        ),
                      ),
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

  Widget _choice<T>({
    required String label,
    required T? value,
    required String anyLabel,
    required List<({T value, String label})> options,
    required ValueChanged<T?> onChanged,
  }) {
    final selected = options.any((option) => option.value == value) ? value : null;
    return DropdownButtonFormField<T?>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<T?>(value: null, child: Text(anyLabel)),
        for (final option in options)
          DropdownMenuItem<T?>(value: option.value, child: Text(option.label)),
      ],
      onChanged: onChanged,
    );
  }

  String _monthLabel(String month) {
    final parts = month.split('-');
    final year = int.tryParse(parts[0]);
    final monthNumber = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (year == null || monthNumber == null) return month;
    return DateFormat.yMMM().format(DateTime(year, monthNumber));
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
