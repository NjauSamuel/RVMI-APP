import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../models/person.dart';

class TagSelectedResult {
  const TagSelectedResult({required this.tagged, required this.unmatched});

  final int tagged;
  final int unmatched;
}

class PeopleRepository {
  PeopleRepository(this.ref);

  final Ref ref;

  Future<List<Person>> list() async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>('/people');
    return (response.data!['data'] as List)
        .map((e) => Person.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Person> create(String name) async {
    final client = ref.read(apiClientProvider);
    final response = await client.post<Map<String, dynamic>>('/people', data: {'name': name});
    return Person.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  }

  /// Stores 1 to 5 gallery photos as this new person's reference faces.
  /// The name is supplied by the caller. Rekognition is not asked who they are.
  Future<Person> trainFromGallery({
    required String name,
    required List<int> mediaItemIds,
  }) async {
    final client = ref.read(apiClientProvider);
    final response = await client.post<Map<String, dynamic>>(
      '/people/train-from-gallery',
      data: {'name': name, 'media_item_ids': mediaItemIds},
      receiveTimeout: const Duration(seconds: 90),
    );
    return Person.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  }

  /// Face-searches only these photos and attaches every trained person found.
  /// Sent in small batches so a long selection stays inside the request timeout.
  Future<TagSelectedResult> tagSelected(List<int> mediaItemIds) async {
    final client = ref.read(apiClientProvider);
    var tagged = 0;
    var unmatched = 0;
    const size = 5;

    for (var i = 0; i < mediaItemIds.length; i += size) {
      final end = i + size > mediaItemIds.length ? mediaItemIds.length : i + size;
      final response = await client.post<Map<String, dynamic>>(
        '/people/tag-selected',
        data: {'media_item_ids': mediaItemIds.sublist(i, end)},
        receiveTimeout: const Duration(seconds: 90),
      );
      final data = response.data!;
      tagged += (data['tagged'] as num?)?.toInt() ?? 0;
      unmatched += (data['unmatched'] as num?)?.toInt() ?? 0;
    }

    return TagSelectedResult(tagged: tagged, unmatched: unmatched);
  }

  /// Uploads 1 to 5 reference photos and replaces this person's indexed faces.
  Future<Person> replaceReferencePhotos(Person person, List<File> files) async {
    if (files.isEmpty || files.length > 5) {
      throw ApiException(statusCode: 422, message: 'Choose 1 to 5 photos.');
    }

    final client = ref.read(apiClientProvider);
    final keys = <String>[];
    for (final file in files) {
      keys.add(await _uploadReference(client, person, file));
    }

    final train = await client.post<Map<String, dynamic>>(
      '/people/${person.id}/train',
      data: {'s3_keys': keys},
      receiveTimeout: const Duration(seconds: 90),
    );
    return Person.fromJson(Map<String, dynamic>.from(train.data!['data'] as Map));
  }

  Future<String> _uploadReference(ApiClient client, Person person, File file) async {
    final contentType = lookupMimeType(file.path) ?? 'image/jpeg';
    final presign = await client.post<Map<String, dynamic>>(
      '/people/${person.id}/presign-reference-photo',
      data: {'filename': file.uri.pathSegments.last, 'content_type': contentType},
    );
    final data = presign.data!['data'] as Map;
    final s3Key = data['s3_key'] as String;
    final uploadUrl = data['upload_url'] as String;
    await client.putToPresignedUrl(uploadUrl, await file.readAsBytes(), contentType);
    return s3Key;
  }
}

final peopleRepositoryProvider = Provider<PeopleRepository>((ref) {
  return PeopleRepository(ref);
});

final peopleListProvider = FutureProvider.autoDispose<List<Person>>((ref) {
  return ref.read(peopleRepositoryProvider).list();
});
