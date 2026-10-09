import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../models/inventory_asset.dart';
import '../providers/inventory_repository.dart';

class AssetFormScreen extends ConsumerStatefulWidget {
  const AssetFormScreen({super.key, this.assetId});

  final int? assetId;

  @override
  ConsumerState<AssetFormScreen> createState() => _AssetFormScreenState();
}

class _AssetFormScreenState extends ConsumerState<AssetFormScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _categoryId;
  String? _assetImageKey;
  String? _assetImagePreviewPath;
  String? _existingAssetImageUrl;
  final List<_ReceiptDraft> _receipts = [];
  DateTime? _purchaseDate;
  DateTime? _warrantyExpiry;
  String _status = 'active';
  bool _loading = true;
  bool _saving = false;
  bool _uploadingReceipts = false;

  bool get _isEditing => widget.assetId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isEditing) {
      final asset = await ref.read(inventoryRepositoryProvider).show(widget.assetId!);
      _nameController.text = asset.name;
      _descriptionController.text = asset.description ?? '';
      _categoryId = asset.categoryId;
      _existingAssetImageUrl = asset.assetImageUrl;
      _receipts
        ..clear()
        ..addAll(asset.receipts.map(_ReceiptDraft.existing));
      _status = asset.status;
      _purchaseDate = asset.purchaseDate != null ? DateTime.tryParse(asset.purchaseDate!) : null;
      _warrantyExpiry = asset.warrantyExpiry != null ? DateTime.tryParse(asset.warrantyExpiry!) : null;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickAssetImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    final key = await ref.read(inventoryRepositoryProvider).uploadFile(file, kind: 'asset_image');
    setState(() {
      _assetImageKey = key;
      _assetImagePreviewPath = picked.path;
    });
  }

  Future<void> _addCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NewCategoryDialog(),
    );
    if (name == null || name.isEmpty || !mounted) return;

    try {
      final created = await ref.read(inventoryRepositoryProvider).createCategory(name);
      ref.invalidate(inventoryCategoriesProvider);
      await ref.read(inventoryCategoriesProvider.future);
      if (mounted) setState(() => _categoryId = created.id);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _pickReceipts() async {
    if (_receipts.length >= 12) return;
    final pickedAll = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    final room = 12 - _receipts.length;
    final picked = pickedAll.where((file) => file.path != null).take(room).toList();
    if (picked.isEmpty) return;

    setState(() => _uploadingReceipts = true);
    try {
      for (final platformFile in picked) {
        final path = platformFile.path!;
        final isPdf = path.toLowerCase().endsWith('.pdf');
        final key = await ref.read(inventoryRepositoryProvider).uploadFile(File(path), kind: 'receipt');
        if (!mounted) return;
        setState(() {
          _receipts.add(
            _ReceiptDraft.uploaded(
              fileKey: key,
              mime: isPdf ? 'pdf' : 'image',
              previewPath: isPdf ? null : path,
              fileName: platformFile.name,
            ),
          );
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _uploadingReceipts = false);
    }
  }

  Future<void> _pickDate({required bool isPurchase}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isPurchase) _purchaseDate = picked; else _warrantyExpiry = picked;
    });
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final data = {
      'name': _nameController.text.trim(),
      'category_id': _categoryId,
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      if (_assetImageKey != null) 'asset_image_key': _assetImageKey,
      'receipts': _receipts.map((receipt) => receipt.toJson()).toList(),
      'purchase_date': _purchaseDate?.toIso8601String().split('T').first,
      'warranty_expiry': _warrantyExpiry?.toIso8601String().split('T').first,
      'status': _status,
    };

    try {
      if (_isEditing) {
        await ref.read(inventoryRepositoryProvider).update(widget.assetId!, data);
      } else {
        await ref.read(inventoryRepositoryProvider).create(data);
      }
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final categories = ref.watch(inventoryCategoriesProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hintColor = dark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit asset' : 'New asset')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pickAssetImage,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: dark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: dark ? AppColors.borderDark : AppColors.border),
              ),
              child: _assetImagePreviewPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(File(_assetImagePreviewPath!), fit: BoxFit.cover, width: double.infinity),
                    )
                  : _existingAssetImageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(_existingAssetImageUrl!, fit: BoxFit.cover, width: double.infinity),
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_a_photo_outlined, color: hintColor),
                              const SizedBox(height: 6),
                              Text('Add a photo', style: TextStyle(color: hintColor)),
                            ],
                          ),
                        ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Asset name'),
          ),
          const SizedBox(height: 12),
          _categoryField(categories),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isPurchase: true),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_purchaseDate == null
                      ? 'Purchase date'
                      : _purchaseDate!.toIso8601String().split('T').first),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isPurchase: false),
                  icon: const Icon(Icons.verified_outlined, size: 16),
                  label: Text(_warrantyExpiry == null
                      ? 'Warranty expiry'
                      : _warrantyExpiry!.toIso8601String().split('T').first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Receipts', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_receipts.isNotEmpty) ...[
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _receipts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _ReceiptTile(
                  draft: _receipts[index],
                  hintColor: hintColor,
                  onRemove: () => setState(() => _receipts.removeAt(index)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_receipts.length < 12)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _uploadingReceipts ? null : _pickReceipts,
                icon: _uploadingReceipts
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(
                  _uploadingReceipts
                      ? 'Adding receipts...'
                      : _receipts.isEmpty
                          ? 'Add receipts (images or PDF)'
                          : 'Add another receipt',
                ),
              ),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'needs_repair', child: Text('Needs repair')),
              DropdownMenuItem(value: 'retired', child: Text('Retired')),
              DropdownMenuItem(value: 'disposed', child: Text('Disposed')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'active'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_saving || _uploadingReceipts) ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand600,
              foregroundColor: Colors.white,
            ),
            child: Text(_saving ? 'Saving...' : 'Save asset'),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () async {
                await ref.read(inventoryRepositoryProvider).delete(widget.assetId!);
                if (mounted) context.pop();
              },
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete asset'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryField(AsyncValue<List<InventoryCategory>> categories) {
    return categories.when(
      data: (list) {
        if (list.isEmpty) {
          return OutlinedButton.icon(
            onPressed: _addCategory,
            icon: const Icon(Icons.add),
            label: const Text('Add a category'),
          );
        }

        final selected = list.any((category) => category.id == _categoryId) ? _categoryId : null;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('category-$selected'),
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in list)
                    DropdownMenuItem(value: category.id, child: Text(category.name)),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'New category',
              onPressed: _addCategory,
              icon: const Icon(Icons.add),
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => OutlinedButton.icon(
        onPressed: _addCategory,
        icon: const Icon(Icons.add),
        label: const Text('Add a category'),
      ),
    );
  }
}

class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog();

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New category'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Category name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand600,
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _ReceiptDraft {
  _ReceiptDraft.existing(InventoryReceipt receipt)
      : id = receipt.id,
        url = receipt.url,
        mime = receipt.mime,
        fileKey = null,
        previewPath = null,
        fileName = null;

  _ReceiptDraft.uploaded({
    required this.fileKey,
    required this.mime,
    required this.previewPath,
    required this.fileName,
  }) : id = null,
       url = null;

  final int? id;
  final String? url;
  final String? fileKey;
  final String mime;
  final String? previewPath;
  final String? fileName;

  Map<String, dynamic> toJson() => id != null ? {'id': id} : {'file_key': fileKey, 'mime': mime};
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({required this.draft, required this.hintColor, required this.onRemove});

  final _ReceiptDraft draft;
  final Color hintColor;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isPdf = draft.mime == 'pdf';

    Widget preview;
    if (!isPdf && draft.previewPath != null) {
      preview = Image.file(File(draft.previewPath!), fit: BoxFit.cover);
    } else if (!isPdf && draft.url != null) {
      preview = Image.network(draft.url!, fit: BoxFit.cover);
    } else {
      preview = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf_outlined, color: hintColor),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              draft.fileName ?? 'PDF',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: hintColor, fontSize: 10),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: dark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dark ? AppColors.borderDark : AppColors.border),
              ),
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: preview),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

