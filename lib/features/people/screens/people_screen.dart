import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../models/person.dart';
import '../providers/people_repository.dart';

/// Lets an admin register the specific people the church wants recognized
/// (e.g. the pastor's family, ministry leads) and store up to five reference
/// photos. Rekognition indexes those faces so later photos can be matched.
class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(peopleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _addPerson(context, ref)),
        ],
      ),
      body: people.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No people registered yet.'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final person = list[index];
              final dark = Theme.of(context).brightness == Brightness.dark;
              final trained = person.indexedInRekognition || person.referenceFaceCount > 0;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: dark ? AppColors.brand800 : AppColors.brand100,
                  child: Icon(
                    trained ? Icons.face_retouching_natural : Icons.face,
                    color: dark ? AppColors.brand300 : AppColors.brand600,
                  ),
                ),
                title: Text(person.name),
                subtitle: Text(person.referenceLabel),
                trailing: TextButton(
                  onPressed: () => _addReferencePhotos(context, ref, person),
                  child: Text(trained ? 'Retrain' : 'Add photos'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load people.')),
      ),
    );
  }

  Future<void> _addPerson(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add person'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Full name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Add')),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        await ref.read(peopleRepositoryProvider).create(controller.text.trim());
        ref.invalidate(peopleListProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      } finally {
        controller.dispose();
      }
      return;
    }
    controller.dispose();
  }

  Future<void> _addReferencePhotos(BuildContext context, WidgetRef ref, Person person) async {
    final messenger = ScaffoldMessenger.of(context);
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(limit: 5);
    if (picked.isEmpty) return;

    final files = picked.take(5).map((file) => File(file.path)).toList();
    messenger.showSnackBar(SnackBar(content: Text('Training ${person.name}...')));

    try {
      final trained = await ref.read(peopleRepositoryProvider).replaceReferencePhotos(person, files);
      ref.invalidate(peopleListProvider);
      final ready = trained.referenceFaceCount > 0
          ? '${trained.name} is ready with ${trained.referenceLabel}.'
          : 'Could not find a clear face in those photos.';
      messenger.showSnackBar(SnackBar(content: Text(ready)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
