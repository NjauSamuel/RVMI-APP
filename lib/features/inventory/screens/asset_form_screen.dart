import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
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
  String? _receiptKey;
  String? _receiptMime;
  String? _receiptFileName;
  String? _existingReceiptUrl;
  DateTime? _purchaseDate;
  DateTime? _warrantyExpiry;
  String _status = 'active';
  bool _loading = true;
  bool _saving = false;

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
      _existingReceiptUrl = asset.receiptUrl;
      _receiptMime = asset.receiptMime;
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

  Future<void> _pickReceipt() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final path = files.isNotEmpty ? files.first.path : null;
    if (path == null) return;
    final file = File(path);
    final isPdf = path.toLowerCase().endsWith('.pdf');
    final key = await ref.read(inventoryRepositoryProvider).uploadFile(file, kind: 'receipt');
    setState(() {
      _receiptKey = key;
      _receiptMime = isPdf ? 'pdf' : 'image';
      _receiptFileName = file.uri.pathSegments.last;
    });
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
      if (_receiptKey != null) 'receipt_file_key': _receiptKey,
      if (_receiptMime != null) 'receipt_mime': _receiptMime,
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
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
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
                      : const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_a_photo_outlined),
                              SizedBox(height: 6),
                              Text('Add a photo'),
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
          categories.when(
            data: (list) => DropdownButtonFormField<int>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: list.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => const SizedBox.shrink(),
          ),
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
          OutlinedButton.icon(
            onPressed: _pickReceipt,
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(_receiptFileName ??
                (_existingReceiptUrl != null ? 'Receipt on file - tap to replace' : 'Attach receipt (image or PDF)')),
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
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: AppColors.brand600),
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
}
