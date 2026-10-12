import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
import '../../favorites/models/saved_filter.dart';
import '../models/event.dart';

class EventsRepository {
  EventsRepository(this.ref);

  final Ref ref;

  Future<List<ChurchEvent>> list({int page = 1}) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>(
      '/events',
      query: {'page': page},
    );
    return (response.data!['data'] as List)
        .map((e) => ChurchEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Walks a few pages so the home filter can offer more than the first 20.
  Future<List<ChurchEvent>> listAll({int maxPages = 5}) async {
    final client = ref.read(apiClientProvider);
    final all = <ChurchEvent>[];
    var page = 1;
    var lastPage = 1;

    while (page <= lastPage && page <= maxPages) {
      final response = await client.get<Map<String, dynamic>>(
        '/events',
        query: {'page': page},
      );
      final data = response.data!;
      all.addAll(
        (data['data'] as List).map(
          (e) => ChurchEvent.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
      lastPage = data['last_page'] as int? ?? page;
      page++;
    }

    return all;
  }

  Future<ChurchEvent> show(int id) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>('/events/$id');
    return ChurchEvent.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  }

  Future<ChurchEvent> create({
    required String title,
    String? description,
    String? eventDate,
    required String visibility,
  }) async {
    final client = ref.read(apiClientProvider);
    final response = await client.post<Map<String, dynamic>>(
      '/events',
      data: {
        'title': title,
        'description': description,
        'event_date': eventDate,
        'visibility': visibility,
      },
    );
    return ChurchEvent.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  }

  Future<List<EventComment>> comments(int eventId) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>('/events/$eventId/comments');
    return (response.data!['data'] as List)
        .map((e) => EventComment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<EventComment> addComment(int eventId, String body) async {
    final client = ref.read(apiClientProvider);
    final response = await client.post<Map<String, dynamic>>(
      '/events/$eventId/comments',
      data: {'body': body},
    );
    return EventComment.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  }

  Future<void> delete(int id) async {
    final client = ref.read(apiClientProvider);
    await client.delete<void>('/events/$id');
  }

  Future<List<ChurchEvent>> listDeleted() async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>('/events/deleted');
    return (response.data!['data'] as List)
        .map((e) => ChurchEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> restore(int id) async {
    final client = ref.read(apiClientProvider);
    await client.post<void>('/events/$id/restore');
  }

  Future<void> favorite(int id) async {
    final client = ref.read(apiClientProvider);
    await client.post<void>('/events/$id/favorite');
  }

  Future<void> unfavorite(int id) async {
    final client = ref.read(apiClientProvider);
    await client.delete<void>('/events/$id/favorite');
  }

  Future<List<ChurchEvent>> saved({SavedFilter filter = const SavedFilter()}) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>(
      '/me/saved-events',
      query: filter.toQuery(),
    );
    return (response.data!['data'] as List)
        .map((e) => ChurchEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<SavedFacets> savedFilters() async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>('/me/saved-events/filters');
    return SavedFacets.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  }
}

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepository(ref);
});

final eventsListProvider = FutureProvider<List<ChurchEvent>>((ref) {
  return ref.read(eventsRepositoryProvider).list();
});

final deletedEventsProvider = FutureProvider<List<ChurchEvent>>((ref) {
  return ref.read(eventsRepositoryProvider).listDeleted();
});

final savedEventsProvider = FutureProvider<List<ChurchEvent>>((ref) {
  return ref.read(eventsRepositoryProvider).saved();
});
