import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thumbnails stay for a long time because each file is small.
/// Full photos are a short list: a new one pushes out the oldest,
/// and the total stays under [fullMaxBytes].
class MediaCaches {
  static const fullMaxObjects = 40;
  static const fullMaxBytes = 120 * 1024 * 1024;
  static const _orderKey = 'rvmi.full_photo_cache_order';
  static const _legacyKey = 'rvmi.cleared_legacy_image_cache';

  static final thumbs = CacheManager(
    Config(
      'rvmiThumbs',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
    ),
  );

  static final fullPhotos = CacheManager(
    Config(
      'rvmiFullPhotos',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: fullMaxObjects,
    ),
  );

  static String fullKey(int id) => 'media-$id-full';

  static String thumbKey(int id) => 'media-$id-thumb';

  /// The previous cache kept every full photo for 30 days with no size cap.
  static Future<void> clearLegacyOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_legacyKey) == true) return;
    await DefaultCacheManager().emptyCache();
    await prefs.setBool(_legacyKey, true);
  }

  /// Record that this full photo was just stored, then drop the oldest
  /// files until the count and byte caps both hold.
  static Future<void> rememberFullPhoto(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final order = List<String>.from(prefs.getStringList(_orderKey) ?? const []);
    final token = '$id';
    order.remove(token);
    order.add(token);

    final sizes = <String, int>{};
    var total = 0;
    for (final mediaId in order) {
      final length = await _fullPhotoBytes(int.parse(mediaId));
      sizes[mediaId] = length;
      total += length;
    }

    while (order.length > fullMaxObjects || (order.length > 1 && total > fullMaxBytes)) {
      final oldest = order.removeAt(0);
      total -= sizes[oldest] ?? 0;
      await fullPhotos.removeFile(fullKey(int.parse(oldest)));
    }

    await prefs.setStringList(_orderKey, order);
  }

  static Future<int> _fullPhotoBytes(int id) async {
    final info = await fullPhotos.getFileFromCache(fullKey(id));
    if (info == null) return 0;
    return info.file.length();
  }
}
