import 'dart:convert';
import 'dart:io';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/upload_repository.dart';
import '../upload_prepare.dart';

enum _PickedKind { image, video }

class _PickedFile {
  _PickedFile(this.file, this.kind, {this.frame = const MediaFrame(), this.posterBase64});
  final File file;
  final _PickedKind kind;
  final MediaFrame frame;
  final String? posterBase64;
}

/// Picks photos/videos and uploads them directly to S3 via presigned PUT
/// URLs - the app never proxies the bytes through itself. Once every file
/// is uploaded, the items sit in `pending_processing`/`pending_review`
/// until an approver reviews them (see the Review screen) - uploading
/// never "finishes the job" on its own.
class UploadPickerScreen extends ConsumerStatefulWidget {
  const UploadPickerScreen({super.key, this.eventId});

  final int? eventId;

  @override
  ConsumerState<UploadPickerScreen> createState() => _UploadPickerScreenState();
}

class _UploadPickerScreenState extends ConsumerState<UploadPickerScreen> {
  final List<_PickedFile> _picked = [];
  bool _uploading = false;
  int _uploadedCount = 0;
  String? _status;

  @override
  void dispose() {
    cancelVideoPrepare();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final files = await picker.pickMultipleMedia(limit: 50);
    var skippedRaw = false;
    setState(() {
      for (final f in files) {
        final file = File(f.path);
        if (isRawPhoto(file)) {
          skippedRaw = true;
          continue;
        }
        final isVideo = f.path.toLowerCase().endsWith('.mp4') ||
            f.path.toLowerCase().endsWith('.mov');
        _picked.add(_PickedFile(file, isVideo ? _PickedKind.video : _PickedKind.image));
      }
    });
    if (skippedRaw && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export a JPEG from your editor. Raw camera files stay on the device.'),
        ),
      );
    }
  }

  Future<void> _upload() async {
    if (_picked.isEmpty) return;
    setState(() {
      _uploading = true;
      _uploadedCount = 0;
      _status = null;
    });

    final repo = ref.read(uploadRepositoryProvider);
    final prepared = <_PickedFile>[];
    var preparing = true;

    try {
      final videoCount = _picked.where((item) => item.kind == _PickedKind.video).length;
      var videoIndex = 0;
      var photoIndex = 0;
      final photoCount = _picked.length - videoCount;

      for (final picked in _picked) {
        if (picked.kind == _PickedKind.image) {
          photoIndex++;
          if (mounted) {
            setState(() => _status = 'Preparing photo $photoIndex/$photoCount...');
          }
          final file = await capPhotoLongEdge(picked.file);
          final preview = await photoPreviewJpeg(file);
          prepared.add(_PickedFile(
            file,
            _PickedKind.image,
            frame: await readPhotoFrame(file),
            posterBase64: preview == null ? null : base64Encode(preview),
          ));
        } else {
          videoIndex++;
          late final File file;
          if (await videoIsAlreadyLight(picked.file)) {
            file = picked.file;
          } else {
            if (mounted) {
              setState(() => _status = 'Preparing video $videoIndex/$videoCount...');
            }
            file = await compressVideoTo720p(
              picked.file,
              onProgress: (progress) {
                if (!mounted) return;
                final percent = progress.round().clamp(0, 100);
                setState(() => _status = 'Preparing video $videoIndex/$videoCount... $percent%');
              },
            );
          }
          prepared.add(_PickedFile(file, _PickedKind.video, frame: await readVideoFrame(file)));
        }
      }

      if (mounted) setState(() => _status = null);
      preparing = false;

      final presigned = await repo.presign(
        files: prepared.map((p) => p.file).toList(),
        types: prepared.map((p) => p.kind == _PickedKind.video ? 'video' : 'image').toList(),
        eventId: widget.eventId,
      );

      for (var i = 0; i < presigned.length; i++) {
        final picked = prepared[i];
        final upload = presigned[i];
        final contentType = picked.kind == _PickedKind.video ? 'video/mp4' : 'image/jpeg';

        await repo.putFile(upload.uploadUrl, picked.file, contentType);

        final poster = picked.posterBase64 ??
            (picked.kind == _PickedKind.video
                ? await _posterFrameBase64(picked.file, picked.frame)
                : null);
        await repo.complete(
          upload.mediaItemId,
          width: picked.frame.width,
          height: picked.frame.height,
          durationSeconds: picked.frame.durationSeconds,
          posterFrameBase64: poster,
        );

        if (mounted) setState(() => _uploadedCount++);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploaded. An approver will review and tag before it goes live.')),
        );
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              preparing ? 'Could not prepare a file for upload.' : 'Upload did not finish.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _status = null;
        });
      }
    }
  }

  /// One JPEG frame for the review card, matching the video's aspect.
  /// Failure just leaves the video icon.
  Future<String?> _posterFrameBase64(File video, MediaFrame frame) async {
    try {
      final fitted = _posterSize(frame);
      final bytes = await FcNativeVideoThumbnail().saveThumbnailToBytes(
        srcFile: video.path,
        width: fitted.$1,
        height: fitted.$2,
        format: 'jpeg',
        quality: 72,
      );
      if (bytes == null || bytes.isEmpty) return null;
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Long side around 720px, keeping 9:16 or landscape instead of a square crop.
  (int, int) _posterSize(MediaFrame frame) {
    final width = frame.width ?? 9;
    final height = frame.height ?? 16;
    if (width <= 0 || height <= 0) return (405, 720);
    final longEdge = width > height ? width : height;
    final scale = longEdge > 720 ? 720 / longEdge : 1.0;
    final fittedWidth = (width * scale).round().clamp(2, 720).toInt();
    final fittedHeight = (height * scale).round().clamp(2, 720).toInt();
    return (
      fittedWidth.isEven ? fittedWidth : fittedWidth + 1,
      fittedHeight.isEven ? fittedHeight : fittedHeight + 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add media')),
      body: Column(
        children: [
          Expanded(
            child: _picked.isEmpty
                ? Center(
                    child: OutlinedButton.icon(
                      onPressed: _pickMedia,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Choose photos & videos'),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: _picked.length,
                    itemBuilder: (context, index) {
                      final picked = _picked[index];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: picked.kind == _PickedKind.image
                                ? Image.file(picked.file, fit: BoxFit.cover)
                                : Container(
                                    color: Colors.black87,
                                    child: const Icon(Icons.videocam, color: Colors.white),
                                  ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => setState(() => _picked.removeAt(index)),
                              child: const CircleAvatar(
                                radius: 11,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_picked.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickMedia,
                      icon: const Icon(Icons.add),
                      label: const Text('Add more'),
                    ),
                  if (_picked.isNotEmpty) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: (_picked.isEmpty || _uploading) ? null : _upload,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand600,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _status ??
                            (_uploading
                                ? 'Uploading $_uploadedCount/${_picked.length}...'
                                : 'Upload ${_picked.length} item(s)'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
