import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
import '../models/tag.dart';

class FavoritesRepository {
  FavoritesRepository(this.ref);

  final Ref ref;

  Future<List<Tag>> suggested() async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>('/me/suggested');
    return (response.data!['data'] as List)
        .map((e) => Tag.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Tag>> myFavorites() async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>('/me/favorites');
    return (response.data!['data'] as List)
        .map((e) => Tag.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Tag>> searchTags({String? kind, String? search}) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>(
      '/tags',
      query: {
        if (kind != null) 'kind': kind,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return (response.data!['data'] as List)
        .map((e) => Tag.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> favorite(int tagId) async {
    final client = ref.read(apiClientProvider);
    await client.post<void>('/tags/$tagId/favorite');
  }

  Future<void> unfavorite(int tagId) async {
    final client = ref.read(apiClientProvider);
    await client.delete<void>('/tags/$tagId/favorite');
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(ref);
});

final suggestedTagsProvider = FutureProvider<List<Tag>>((ref) {
  return ref.read(favoritesRepositoryProvider).suggested();
});

final myFavoriteTagsProvider = FutureProvider<List<Tag>>((ref) {
  return ref.read(favoritesRepositoryProvider).myFavorites();
});
