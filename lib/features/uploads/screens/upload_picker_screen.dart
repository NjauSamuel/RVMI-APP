import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/upload_repository.dart';

enum _PickedKind { image, video }

class _PickedFile {
  _PickedFile(this.file, this.kind);
  final File file;
  final _PickedKind kind;
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

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final files = await picker.pickMultipleMedia(limit: 50);
    setState(() {
      for (final f in files) {
        final isVideo = f.path.toLowerCase().endsWith('.mp4') ||
            f.path.toLowerCase().endsWith('.mov');
        _picked.add(_PickedFile(File(f.path), isVideo ? _PickedKind.video : _PickedKind.image));
      }
    });
  }

  Future<void> _upload() async {
    if (_picked.isEmpty) return;
    setState(() { _uploading = true; _uploadedCount = 0; });

    final repo = ref.read(uploadRepositoryProvider);

    try {
      final presigned = await repo.presign(
        files: _picked.map((p) => p.file).toList(),
        types: _picked.map((p) => p.kind == _PickedKind.video ? 'video' : 'image').toList(),
        eventId: widget.eventId,
      );

      for (var i = 0; i < presigned.length; i++) {
        final picked = _picked[i];
        final upload = presigned[i];
        final contentType = picked.kind == _PickedKind.video ? 'video/mp4' : 'image/jpeg';

        await repo.putFile(upload.uploadUrl, picked.file, contentType);

        // No client-side poster-frame generation (see pubspec.yaml note on
        // video_thumbnail) - the backend accepts a video with no thumbnail
        // and still moves it straight to pending_review.
        await repo.complete(upload.mediaItemId);

        if (mounted) setState(() => _uploadedCount++);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploaded. An approver will review and tag before it goes live.')),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _uploading ? null : _pickMedia,
                        child: const Text('Add more'),
                      ),
                    ),
                  if (_picked.isNotEmpty) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: (_picked.isEmpty || _uploading) ? null : _upload,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand600,
                        foregroundColor: Colors.white,
                      ),
                      child: _uploading
                          ? Text('Uploading $_uploadedCount/${_picked.length}...')
                          : Text('Upload ${_picked.length} item(s)'),
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
