import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/media_cache.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/session_controller.dart';
import '../models/event.dart';
import '../providers/events_repository.dart';

/// Events are the umbrella tags a whole cluster of Sunday's photos lives
/// under ("Graduation", "Youth Camp") - this is where the single,
/// per-event comment thread lives, instead of per-photo comments.
class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsListProvider);
    final session = ref.watch(sessionControllerProvider);
    final canManageEvents =
        session is SessionAuthenticated && session.session.canManageEvents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            tooltip: 'Saved events',
            icon: const Icon(Icons.bookmark_border),
            onPressed: () => context.push('/saved-events'),
          ),
          if (canManageEvents)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _createEventDialog(context, ref),
            ),
          if (canManageEvents)
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'deleted') _showDeletedEvents(context);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'deleted', child: Text('Deleted events')),
              ],
            ),
        ],
      ),
      body: events.when(
        data: (list) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(eventsListProvider),
            child: list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No events yet.')),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final event = list[index];
                      return _EventCard(
                        event: event,
                        onDelete: canManageEvents ? () => _deleteEvent(context, ref, event) : null,
                      );
                    },
                  ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load events.')),
      ),
    );
  }

  Future<void> _createEventDialog(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    String visibility = 'public';

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New event'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'public', label: Text('Public')),
                  ButtonSegment(value: 'private', label: Text('Private')),
                ],
                selected: {visibility},
                onSelectionChanged: (s) => setState(() => visibility = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (created == true && titleController.text.trim().isNotEmpty) {
      await ref.read(eventsRepositoryProvider).create(
        title: titleController.text.trim(),
        visibility: visibility,
      );
      ref.invalidate(eventsListProvider);
    }
  }

  void _showDeletedEvents(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _DeletedEventsSheet(),
    );
  }

  Future<void> _deleteEvent(BuildContext context, WidgetRef ref, ChurchEvent event) async {
    if (!await confirmDeleteEvent(context, event) || !context.mounted) return;
    await ref.read(eventsRepositoryProvider).delete(event.id);
    ref.invalidate(eventsListProvider);
    ref.invalidate(deletedEventsProvider);
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, this.onDelete});

  final ChurchEvent event;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/events/${event.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (event.coverBlurhash != null)
                        BlurHash(hash: event.coverBlurhash!)
                      else
                        Container(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brand800
                              : AppColors.brand100,
                        ),
                      if (event.coverThumbnailUrl != null)
                        CachedNetworkImage(
                          imageUrl: event.coverThumbnailUrl!,
                          cacheManager: MediaCaches.thumbs,
                          cacheKey: 'event-cover-${event.id}',
                          fit: BoxFit.cover,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (event.isPrivate)
                          Icon(
                            Icons.lock,
                            size: 16,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${event.mediaCount} item(s)${event.eventDate != null ? ' · ${event.eventDate}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              SaveEventButton(event: event),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmDeleteEvent(BuildContext context, ChurchEvent event) async {
  final count = event.mediaCount;
  final photos = count == 1 ? '1 photo stays linked' : '$count photos stay linked';
  final deleted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete ${event.title}?'),
      content: Text(
        'It can be restored. $photos and will show under this event again if you restore it.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ),
  );
  return deleted == true;
}

class _DeletedEventsSheet extends ConsumerWidget {
  const _DeletedEventsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deleted = ref.watch(deletedEventsProvider);
    return SafeArea(
      child: deleted.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Text('Could not load deleted events.'),
        ),
        data: (events) {
          if (events.isEmpty) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Text('No deleted events.'),
            );
          }
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            children: [
              for (final event in events)
                ListTile(
                  title: Text(event.title),
                  subtitle: Text('${event.mediaCount} item(s)'),
                  trailing: TextButton(
                    onPressed: () async {
                      await ref.read(eventsRepositoryProvider).restore(event.id);
                      ref.invalidate(eventsListProvider);
                      ref.invalidate(deletedEventsProvider);
                    },
                    child: const Text('Restore'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class SaveEventButton extends ConsumerStatefulWidget {
  const SaveEventButton({super.key, required this.event, this.onChanged});

  final ChurchEvent event;
  final VoidCallback? onChanged;

  @override
  ConsumerState<SaveEventButton> createState() => _SaveEventButtonState();
}

class _SaveEventButtonState extends ConsumerState<SaveEventButton> {
  late bool _saved;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.event.isFavorite;
  }

  @override
  void didUpdateWidget(SaveEventButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id || oldWidget.event.isFavorite != widget.event.isFavorite) {
      _saved = widget.event.isFavorite;
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final next = !_saved;
    setState(() {
      _saved = next;
      _busy = true;
    });
    try {
      final repo = ref.read(eventsRepositoryProvider);
      if (next) {
        await repo.favorite(widget.event.id);
      } else {
        await repo.unfavorite(widget.event.id);
      }
      ref.invalidate(eventsListProvider);
      ref.invalidate(savedEventsProvider);
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) setState(() => _saved = !next);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _saved ? 'Remove from saved events' : 'Save event',
      icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
      onPressed: _busy ? null : _toggle,
    );
  }
}
