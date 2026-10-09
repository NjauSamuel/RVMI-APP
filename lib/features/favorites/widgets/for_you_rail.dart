import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/favorites_repository.dart';

/// "For You" rail: favorited tags first, then whatever this member has
/// viewed most/most-recently - tapping a chip opens that tag's timeline.
/// Hidden entirely when there's nothing to suggest yet.
class ForYouRail extends ConsumerWidget {
  const ForYouRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggested = ref.watch(suggestedTagsProvider);

    return suggested.when(
      data: (tags) {
        if (tags.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: tags.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final tag = tags[index];
              return ActionChip(
                avatar: tag.isPerson
                    ? const CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.brand200,
                        child: Icon(Icons.person, size: 12, color: AppColors.brand700),
                      )
                    : null,
                label: Text(tag.name),
                onPressed: () => context.push(
                  '/tags/${tag.id}?name=${Uri.encodeComponent(tag.name)}',
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 44),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
