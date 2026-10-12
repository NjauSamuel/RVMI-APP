import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
import '../models/media_item.dart';

class GalleryPage {
  const GalleryPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  final List<MediaItem> items;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;
}

class GalleryRepository {
  GalleryRepository(this.ref);

  final Ref ref;

  Future<GalleryPage> fetch({
    int page = 1,
    int? eventId,
    int? tagId,
    String? from,
    String? to,
    String? type,
  }) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>(
      '/gallery',
      query: {
        'page': page,
        'event_id': ?eventId,
        'tag_id': ?tagId,
        'from': ?from,
        'to': ?to,
        'type': ?type,
      },
    );

    final data = response.data!;
    final items = (data['data'] as List)
        .map((e) => MediaItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return GalleryPage(
      items: items,
      currentPage: data['current_page'] as int,
      lastPage: data['last_page'] as int,
    );
  }

  Future<MediaItem> show(int id) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>('/gallery/$id');
    return MediaItem.fromJson(
      Map<String, dynamic>.from(response.data!['data'] as Map),
    );
  }

  Future<void> recordView(int id) async {
    final client = ref.read(apiClientProvider);
    await client.post<void>('/gallery/$id/view');
  }

  Future<void> delete(int id) async {
    final client = ref.read(apiClientProvider);
    await client.delete<void>('/gallery/$id');
  }

  Future<void> favorite(int id) async {
    final client = ref.read(apiClientProvider);
    await client.post<void>('/gallery/$id/favorite');
  }

  Future<void> unfavorite(int id) async {
    final client = ref.read(apiClientProvider);
    await client.delete<void>('/gallery/$id/favorite');
  }

  Future<GalleryPage> saved({int page = 1}) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>(
      '/me/saved-photos',
      query: {'page': page},
    );
    final data = response.data!;
    final items = (data['data'] as List)
        .map((e) => MediaItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return GalleryPage(
      items: items,
      currentPage: data['current_page'] as int,
      lastPage: data['last_page'] as int,
    );
  }
}

final galleryRepositoryProvider = Provider<GalleryRepository>((ref) {
  return GalleryRepository(ref);
});
