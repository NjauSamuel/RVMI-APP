import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../favorites/models/saved_filter.dart';
import '../../favorites/widgets/saved_filter_sheet.dart';
import '../models/event.dart';
import '../providers/events_repository.dart';
import 'events_screen.dart';

/// Saved events only. Photo saves stay on Home.
class SavedEventsScreen extends ConsumerStatefulWidget {
  const SavedEventsScreen({super.key});

  @override
  ConsumerState<SavedEventsScreen> createState() => _SavedEventsScreenState();
}

class _SavedEventsScreenState extends ConsumerState<SavedEventsScreen> {
  var _filter = const SavedFilter();
  late Future<List<ChurchEvent>> _events;

  @override
  void initState() {
    super.initState();
    _events = _fetch();
  }

  Future<List<ChurchEvent>> _fetch() {
    return ref.read(eventsRepositoryProvider).saved(filter: _filter);
  }

  Future<void> _reload() async {
    final next = _fetch();
    setState(() => _events = next);
    await next;
  }

  Future<void> _openFilters() async {
    final messenger = ScaffoldMessenger.of(context);
    SavedFacets facets;
    try {
      facets = await ref.read(eventsRepositoryProvider).savedFilters();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not load filters.')));
      return;
    }
    if (!mounted) return;
    final next = await showSavedFilterSheet(context, facets: facets, initial: _filter, photos: false);
    if (next == null || !mounted) return;
    setState(() {
      _filter = next;
      _events = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved events'),
        actions: [
          IconButton(
            tooltip: 'Filter',
            icon: Icon(
              _filter.active ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _filter.active ? AppColors.brand500 : null,
            ),
            onPressed: _openFilters,
          ),
        ],
      ),
      body: FutureBuilder<List<ChurchEvent>>(
        future: _events,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load saved events.'));
          }
          final list = snapshot.data ?? const <ChurchEvent>[];
          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      _filter.active ? 'Nothing saved matches this filter.' : 'No saved events yet.',
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final event = list[index];
                return Card(
                  child: ListTile(
                    title: Text(event.title),
                    subtitle: Text(
                      '${event.mediaCount} item(s)${event.eventDate != null ? ' · ${event.eventDate}' : ''}',
                    ),
                    trailing: SaveEventButton(event: event, onChanged: () { _reload(); }),
                    onTap: () => context.push('/events/${event.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
