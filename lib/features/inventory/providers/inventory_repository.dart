import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';

import '../../../core/network/providers.dart';
import '../models/inventory_asset.dart';

class InventoryRepository {
  InventoryRepository(this.ref);

  final Ref ref;

  Future<List<InventoryCategory>> categories() async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>('/inventory/categories');
    return (response.data!['data'] as List)
        .map((e) => InventoryCategory.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<InventoryCategory> createCategory(String name) async {
    final client = ref.read(apiClientProvider);
    final response = await client.post<Map<String, dynamic>>('/inventory/categories', data: {'name': name});
    return InventoryCategory.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  }

  Future<List<InventoryAsset>> assets({int? categoryId, String? search}) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>(
      '/inventory/assets',
      query: {if (categoryId != null) 'category_id': categoryId, if (search != null && search.isNotEmpty) 'search': search},
    );
    return (response.data!['data'] as List)
        .map((e) => InventoryAsset.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<InventoryAsset> show(int id) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>('/inventory/assets/$id');
    return InventoryAsset.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  }

  /// Uploads an asset photo or a receipt (image/PDF) straight to S3 and
  /// returns the S3 key to attach on create/update - this is exactly what
  /// solves the "lost the receipt for the piano" problem: the receipt
  /// lives with the asset record forever, not in someone's email.
  Future<String> uploadFile(File file, {required String kind}) async {
    final client = ref.read(apiClientProvider);
    final contentType = lookupMimeType(file.path) ?? 'application/octet-stream';

    final presign = await client.post<Map<String, dynamic>>(
      '/inventory/assets/presign',
      data: {
        'kind': kind,
        'filename': file.uri.pathSegments.last,
        'content_type': contentType,
      },
    );
    final data = presign.data!['data'] as Map;
    final s3Key = data['s3_key'] as String;
    final uploadUrl = data['upload_url'] as String;

    await client.putToPresignedUrl(uploadUrl, await file.readAsBytes(), contentType);
    return s3Key;
  }

  Future<InventoryAsset> create(Map<String, dynamic> data) async {
    final client = ref.read(apiClientProvider);
    final response = await client.post<Map<String, dynamic>>('/inventory/assets', data: data);
    return InventoryAsset.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  }

  Future<InventoryAsset> update(int id, Map<String, dynamic> data) async {
    final client = ref.read(apiClientProvider);
    final response = await client.patch<Map<String, dynamic>>('/inventory/assets/$id', data: data);
    return InventoryAsset.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  }

  Future<void> delete(int id) async {
    final client = ref.read(apiClientProvider);
    await client.delete<void>('/inventory/assets/$id');
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref);
});

final inventoryCategoriesProvider = FutureProvider.autoDispose<List<InventoryCategory>>((ref) {
  return ref.read(inventoryRepositoryProvider).categories();
});

final inventoryAssetsProvider = FutureProvider.autoDispose<List<InventoryAsset>>((ref) {
  return ref.read(inventoryRepositoryProvider).assets();
});
