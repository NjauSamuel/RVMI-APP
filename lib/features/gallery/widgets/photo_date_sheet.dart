import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A calendar day the user picked, or a request to fall back to upload time.
class PhotoDateChoice {
  const PhotoDateChoice.day(this.day) : useUploadDate = false;

  const PhotoDateChoice.uploadDate() : day = null, useUploadDate = true;

  final DateTime? day;
  final bool useUploadDate;

  /// `YYYY-MM-DD` for the calendar day the user saw, with no timezone shift.
  String? get apiDate {
    final value = day;
    if (value == null) return null;
    return DateFormat('yyyy-MM-dd').format(DateTime(value.year, value.month, value.day));
  }
}

/// Blank means the caller keeps today's upload-time behavior.
Future<PhotoDateChoice?> showPhotoDateSheet(
  BuildContext context, {
  DateTime? current,
}) {
  return showModalBottomSheet<PhotoDateChoice>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Choose date'),
              subtitle: current == null
                  ? null
                  : Text(DateFormat.yMMMd().format(current.toLocal())),
              onTap: () async {
                final now = DateTime.now();
                final initial = current?.toLocal() ?? now;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(1990),
                  lastDate: DateTime(now.year + 1),
                );
                if (picked == null || !context.mounted) return;
                Navigator.pop(context, PhotoDateChoice.day(picked));
              },
            ),
            ListTile(
              title: const Text('Use upload date'),
              onTap: () => Navigator.pop(context, const PhotoDateChoice.uploadDate()),
            ),
          ],
        ),
      );
    },
  );
}
