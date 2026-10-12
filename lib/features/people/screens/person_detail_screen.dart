import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_cache.dart';
import '../models/person.dart';
import '../providers/people_repository.dart';

/// The photos used to train this person. Tapping a thumbnail opens the full shot.
class PersonDetailScreen extends ConsumerWidget {
  const PersonDetailScreen({super.key, required this.personId});

  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final references = ref.watch(personReferencesProvider(personId));

    return Scaffold(
      appBar: AppBar(
        title: Text(references.asData?.value.name ?? 'Person'),
      ),
      body: references.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load reference photos.')),
        data: (person) {
          if (person.photos.isEmpty) {
            return const Center(child: Text('No reference photos yet.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: person.photos.length,
            itemBuilder: (context, index) {
              final photo = person.photos[index];
              return GestureDetector(
                onTap: () => _openFull(context, photo),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: photo.url,
                    cacheManager: MediaCaches.thumbs,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const ColoredBox(color: Colors.black12),
                    errorWidget: (_, _, _) => const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openFull(BuildContext context, PersonReferencePhoto photo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: photo.fullUrl,
                cacheManager: MediaCaches.fullPhotos,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
