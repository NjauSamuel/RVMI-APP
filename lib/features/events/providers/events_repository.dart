import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
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
}

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepository(ref);
});

final eventsListProvider = FutureProvider<List<ChurchEvent>>((ref) {
  return ref.read(eventsRepositoryProvider).list();
});
