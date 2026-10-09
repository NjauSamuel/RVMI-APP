import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          if (canManageEvents)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _createEventDialog(context, ref),
            ),
        ],
      ),
      body: events.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No events yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(eventsListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _EventCard(event: list[index]),
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
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final ChurchEvent event;

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
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
