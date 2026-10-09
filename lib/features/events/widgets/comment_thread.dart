import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/session_controller.dart';
import '../models/event.dart';
import '../providers/events_repository.dart';

/// The single, umbrella discussion thread for a whole event - deliberately
/// not attached to individual photos, so the app never feels like a
/// per-photo like/comment social feed.
class CommentThread extends ConsumerStatefulWidget {
  const CommentThread({super.key, required this.eventId});

  final int eventId;

  @override
  ConsumerState<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends ConsumerState<CommentThread> {
  final _controller = TextEditingController();
  List<EventComment> _comments = [];
  bool _loading = true;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final comments = await ref.read(eventsRepositoryProvider).comments(widget.eventId);
    if (mounted) setState(() { _comments = comments; _loading = false; });
  }

  Future<void> _post() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    setState(() => _posting = true);
    try {
      final comment = await ref.read(eventsRepositoryProvider).addComment(widget.eventId, body);
      setState(() {
        _comments = [comment, ..._comments];
        _controller.clear();
      });
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final canComment = session is SessionAuthenticated && session.session.can('comment');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            'Discussion',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No comments yet. Be the first to share how it went.',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
          )
        else
          ...List.generate(_comments.length, (index) {
            final comment = _comments[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brand800
                        : AppColors.brand100,
                    backgroundImage: comment.avatarUrl != null ? NetworkImage(comment.avatarUrl!) : null,
                    child: comment.avatarUrl == null
                        ? Text(
                            comment.userName.isNotEmpty ? comment.userName[0] : '?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : AppColors.brand800,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment.userName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(comment.body),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        if (canComment)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Share how it went...',
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _posting ? null : _post,
                  icon: const Icon(Icons.send, size: 18),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
