import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';

import '../../../core/network/providers.dart';
import '../models/person.dart';

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

  /// Uploads a reference ("training") photo directly to S3, then asks the
  /// backend to index it into the Rekognition Face Collection under this
  /// person's id, so future photos containing their face get auto-tagged.
  Future<bool> addReferencePhoto(Person person, File file) async {
    final client = ref.read(apiClientProvider);
    final contentType = lookupMimeType(file.path) ?? 'image/jpeg';

    final presign = await client.post<Map<String, dynamic>>(
      '/people/${person.id}/presign-reference-photo',
      data: {'filename': file.uri.pathSegments.last, 'content_type': contentType},
    );
    final data = presign.data!['data'] as Map;
    final s3Key = data['s3_key'] as String;
    final uploadUrl = data['upload_url'] as String;

    await client.putToPresignedUrl(uploadUrl, await file.readAsBytes(), contentType);

    final train = await client.post<Map<String, dynamic>>(
      '/people/${person.id}/train',
      data: {'s3_key': s3Key},
    );
    return train.data!['indexed'] as bool? ?? false;
  }
}

final peopleRepositoryProvider = Provider<PeopleRepository>((ref) {
  return PeopleRepository(ref);
});

final peopleListProvider = FutureProvider.autoDispose<List<Person>>((ref) {
  return ref.read(peopleRepositoryProvider).list();
});
