import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

const photoLongEdge = 2048;
const photoPreviewEdge = 480;
const _maxVideoEdge = 1280;
const _maxVideoMbps = 2.5;

class MediaFrame {
  const MediaFrame({this.width, this.height, this.durationSeconds});

  final int? width;
  final int? height;
  final int? durationSeconds;
}

Future<void> cancelVideoPrepare() => VideoCompress.cancelCompression();

bool isRawPhoto(File file) {
  final path = file.path.toLowerCase();
  return path.endsWith('.cr3') || path.endsWith('.cr2');
}

/// Caps a JPEG or PNG so its long edge is 2048 pixels. A picture already
/// inside that box is returned unchanged.
Future<File> capPhotoLongEdge(File source) async {
  final size = await _readImageSize(source);
  if (size != null && size.$1 <= photoLongEdge && size.$2 <= photoLongEdge) {
    return source;
  }

  final dir = await getTemporaryDirectory();
  final target = '${dir.path}/rvmi_${DateTime.now().microsecondsSinceEpoch}.jpg';
  final compressed = await FlutterImageCompress.compressAndGetFile(
    source.path,
    target,
    quality: 92,
    minWidth: photoLongEdge,
    minHeight: photoLongEdge,
    format: CompressFormat.jpeg,
  );
  if (compressed == null) {
    throw StateError('Could not prepare this photo.');
  }
  return File(compressed.path);
}

/// Small JPEG for the grid. The long side is about 480 pixels so Home and
/// Review do not have to download the full photo.
Future<Uint8List?> photoPreviewJpeg(File file) async {
  try {
    final bytes = await FlutterImageCompress.compressWithFile(
      file.path,
      minWidth: photoPreviewEdge,
      minHeight: photoPreviewEdge,
      quality: 72,
      format: CompressFormat.jpeg,
    );
    if (bytes == null || bytes.isEmpty) return null;
    return bytes;
  } catch (_) {
    return null;
  }
}

Future<MediaFrame> readPhotoFrame(File file) async {
  final size = await _readImageSize(file);
  if (size == null) return const MediaFrame();
  return MediaFrame(width: size.$1, height: size.$2);
}

/// Display size of a video. Android reports the encoded size plus a rotation,
/// so a 9:16 clip stored sideways is turned upright here.
Future<MediaFrame> readVideoFrame(File file) async {
  try {
    final info = await VideoCompress.getMediaInfo(file.path);
    var width = info.width;
    var height = info.height;
    final orientation = info.orientation ?? 0;
    if ((orientation == 90 || orientation == 270) && width != null && height != null) {
      final swapped = width;
      width = height;
      height = swapped;
    }
    final durationMs = info.duration ?? 0;
    return MediaFrame(
      width: width,
      height: height,
      durationSeconds: durationMs > 0 ? (durationMs / 1000).round() : null,
    );
  } catch (_) {
    return const MediaFrame();
  }
}

/// True when the clip is already 720p or smaller and under about 2.5 Mbps.
Future<bool> videoIsAlreadyLight(File source) async {
  try {
    final info = await VideoCompress.getMediaInfo(source.path);
    final width = info.width ?? 0;
    final height = info.height ?? 0;
    final durationMs = info.duration ?? 0;
    final bytes = info.filesize ?? 0;
    if (width <= 0 || height <= 0 || durationMs <= 0 || bytes <= 0) return false;
    final longEdge = width > height ? width : height;
    final mbps = (bytes * 8) / (durationMs / 1000) / 1000000;
    return longEdge <= _maxVideoEdge && mbps <= _maxVideoMbps;
  } catch (_) {
    return false;
  }
}

Future<File> compressVideoTo720p(
  File source, {
  void Function(double progress)? onProgress,
}) async {
  Subscription? subscription;
  if (onProgress != null) {
    subscription = VideoCompress.compressProgress$.subscribe(onProgress);
  }
  try {
    final info = await VideoCompress.compressVideo(
      source.path,
      quality: VideoQuality.Res1280x720Quality,
      deleteOrigin: false,
      includeAudio: true,
    );
    final file = info?.file;
    if (file == null) {
      throw StateError('Could not prepare this video.');
    }
    return file;
  } finally {
    subscription?.unsubscribe();
  }
}

/// JPEG and PNG dimensions, read from the header so a large export is not decoded.
Future<(int, int)?> _readImageSize(File file) async {
  final raf = await file.open();
  try {
    final header = await raf.read(24);
    if (header.length >= 24 &&
        header[0] == 0x89 &&
        header[1] == 0x50 &&
        header[2] == 0x4E &&
        header[3] == 0x47) {
      final data = header.buffer.asByteData(header.offsetInBytes, header.length);
      return (data.getUint32(16), data.getUint32(20));
    }

    await raf.setPosition(0);
    final start = await raf.read(2);
    if (start.length < 2 || start[0] != 0xFF || start[1] != 0xD8) return null;

    for (var i = 0; i < 80; i++) {
      var marker = 0;
      while (marker != 0xFF) {
        final byte = await raf.read(1);
        if (byte.isEmpty) return null;
        marker = byte[0];
      }
      final typeByte = await raf.read(1);
      if (typeByte.isEmpty) return null;
      final type = typeByte[0];
      if (type == 0xFF || type == 0x00 || type == 0xD8 || type == 0xD9 || (type >= 0xD0 && type <= 0xD7)) {
        continue;
      }
      if (type == 0xDA) return null;
      final lengthBytes = await raf.read(2);
      if (lengthBytes.length < 2) return null;
      final length = (lengthBytes[0] << 8) | lengthBytes[1];
      if (type == 0xC0 || type == 0xC1 || type == 0xC2) {
        final sof = await raf.read(5);
        if (sof.length < 5) return null;
        final height = (sof[1] << 8) | sof[2];
        final width = (sof[3] << 8) | sof[4];
        return (width, height);
      }
      if (length < 2) return null;
      await raf.setPosition(await raf.position() + length - 2);
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    await raf.close();
  }
}
