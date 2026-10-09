import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../events/providers/events_repository.dart';
import '../models/review_item.dart';
import '../providers/review_repository.dart';

/// Nothing an uploader adds becomes visible to the rest of the church
/// until it passes through here: confirm/adjust the auto-generated tags
/// (scene + recognized people), pick the event it belongs to, and set
/// public/private visibility, then approve.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingReviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review & approve'),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: () async {
                await ref.read(reviewRepositoryProvider).bulkApprove(_selected.toList());
                setState(() => _selected.clear());
                ref.invalidate(pendingReviewProvider);
              },
              child: Text('Approve ${_selected.length}', style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: pending.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Nothing waiting for review. 🎉'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = items[index];
              return _ReviewCard(
                item: item,
                selected: _selected.contains(item.id),
                onSelectChanged: (v) => setState(() {
                  if (v) _selected.add(item.id); else _selected.remove(item.id);
                }),
                onApproved: () => ref.invalidate(pendingReviewProvider),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load pending items.')),
      ),
    );
  }
}

class _ReviewCard extends ConsumerStatefulWidget {
  const _ReviewCard({
    required this.item,
    required this.selected,
    required this.onSelectChanged,
    required this.onApproved,
  });

  final ReviewItem item;
  final bool selected;
  final ValueChanged<bool> onSelectChanged;
  final VoidCallback onApproved;

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  late Set<int> _tagIds;
  String _visibility = 'public';
  int? _eventId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tagIds = {...widget.item.selectedTagIds};
    _visibility = widget.item.visibility;
    _eventId = widget.item.eventId;
  }

  Future<void> _saveEdits() async {
    await ref.read(reviewRepositoryProvider).update(
      widget.item.id,
      eventId: _eventId,
      visibility: _visibility,
      tagIds: _tagIds.toList(),
    );
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await _saveEdits();
      await ref.read(reviewRepositoryProvider).approve(widget.item.id);
      widget.onApproved();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      await ref.read(reviewRepositoryProvider).reject(widget.item.id);
      widget.onApproved();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsListProvider);
    final item = widget.item;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(value: widget.selected, onChanged: (v) => widget.onSelectChanged(v ?? false)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.stagingPreviewUrl != null
                      ? Image.network(item.stagingPreviewUrl!, width: 72, height: 72, fit: BoxFit.cover)
                      : Container(width: 72, height: 72, color: Colors.black12,
                          child: Icon(item.type == 'video' ? Icons.videocam : Icons.image)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Item #${item.id}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(item.type, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            events.when(
              data: (list) => DropdownButtonFormField<int>(
                initialValue: _eventId,
                decoration: const InputDecoration(labelText: 'Event'),
                items: list
                    .map((e) => DropdownMenuItem(value: e.id, child: Text(e.title)))
                    .toList(),
                onChanged: (v) => setState(() => _eventId = v),
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
                  onSelected: (v) => setState(() {
                    if (v) _tagIds.add(tag.id); else _tagIds.remove(tag.id);
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
              onSelectionChanged: (s) => setState(() => _visibility = s.first),
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
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand600),
                    child: _busy ? const Text('...') : const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
