import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../models/person.dart';
import '../providers/people_repository.dart';

/// Lets an admin register the specific people the church wants recognized
/// (e.g. the pastor's family, ministry leads) and feed in a reference
/// photo. Rekognition indexes the face so future uploads auto-suggest that
/// person's tag during review.
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
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: dark ? AppColors.brand800 : AppColors.brand100,
                  child: Icon(
                    person.indexedInRekognition ? Icons.face_retouching_natural : Icons.face,
                    color: dark ? AppColors.brand300 : AppColors.brand600,
                  ),
                ),
                title: Text(person.name),
                subtitle: Text(person.indexedInRekognition
                    ? 'Trained for auto-recognition'
                    : 'No reference photo yet'),
                trailing: TextButton(
                  onPressed: () => _addReferencePhoto(context, ref, person),
                  child: Text(person.indexedInRekognition ? 'Retrain' : 'Add photo'),
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
      await ref.read(peopleRepositoryProvider).create(controller.text.trim());
      ref.invalidate(peopleListProvider);
    }
  }

  Future<void> _addReferencePhoto(BuildContext context, WidgetRef ref, Person person) async {
    final messenger = ScaffoldMessenger.of(context);
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    messenger.showSnackBar(SnackBar(content: Text('Training ${person.name}...')));

    final indexed = await ref
        .read(peopleRepositoryProvider)
        .addReferencePhoto(person, File(picked.path));

    ref.invalidate(peopleListProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(indexed ? '${person.name} is ready for auto-recognition.' : 'Could not train from that photo.')),
    );
  }
}
