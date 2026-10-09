import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';

import '../../../core/network/providers.dart';

class PresignedUpload {
  const PresignedUpload({required this.mediaItemId, required this.uploadUrl});

  final int mediaItemId;
  final String uploadUrl;
}

class UploadRepository {
  UploadRepository(this.ref);

  final Ref ref;

  Future<List<PresignedUpload>> presign({
    required List<File> files,
    required List<String> types,
    int? eventId,
  }) async {
    final client = ref.read(apiClientProvider);

    final payload = <Map<String, dynamic>>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final contentType = lookupMimeType(file.path) ?? 'application/octet-stream';
      payload.add({
        'filename': file.uri.pathSegments.last,
        'content_type': contentType,
        'type': types[i],
        'size_bytes': await file.length(),
      });
    }

    final response = await client.post<Map<String, dynamic>>(
      '/uploads/presign',
      data: {'event_id': eventId, 'files': payload},
    );

    return (response.data!['data'] as List)
        .map((e) => PresignedUpload(
              mediaItemId: e['media_item_id'] as int,
              uploadUrl: e['upload_url'] as String,
            ))
        .toList();
  }

  Future<void> putFile(String uploadUrl, File file, String contentType) async {
    final client = ref.read(apiClientProvider);
    final bytes = await file.readAsBytes();
    await client.putToPresignedUrl(uploadUrl, bytes, contentType);
  }

  Future<void> complete(
    int mediaItemId, {
    int? width,
    int? height,
    int? durationSeconds,
    String? posterFrameBase64,
  }) async {
    final client = ref.read(apiClientProvider);
    await client.post<void>(
      '/uploads/$mediaItemId/complete',
      data: {
        'width': width,
        'height': height,
        'duration_seconds': durationSeconds,
        'poster_frame_base64': posterFrameBase64,
      },
    );
  }
}

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  return UploadRepository(ref);
});
