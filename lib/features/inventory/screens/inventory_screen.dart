import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../models/inventory_asset.dart';
import '../providers/inventory_repository.dart';

/// Church asset tracking - the piano, sound gear, projectors, anything
/// bought with a receipt that would otherwise get lost in someone's inbox.
/// Completely hidden from normal Members; only roles with
/// `manage-inventory` ever see this tab.
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(inventoryAssetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/inventory/new').then((_) => ref.invalidate(inventoryAssetsProvider)),
        child: const Icon(Icons.add),
      ),
      body: assets.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No assets tracked yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(inventoryAssetsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _AssetCard(asset: list[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load inventory.')),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset});

  final InventoryAsset asset;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/inventory/${asset.id}/edit'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: asset.assetImageUrl != null
                      ? Image.network(asset.assetImageUrl!, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.brand100,
                          child: const Icon(Icons.inventory_2_outlined),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (asset.categoryName != null)
                      Text(asset.categoryName!, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _StatusChip(status: asset.status),
                        if (asset.warrantyExpiry != null) const SizedBox(width: 6),
                        if (asset.warrantyExpiry != null)
                          Chip(
                            label: Text(asset.warrantyActive ? 'Under warranty' : 'Warranty expired'),
                            labelStyle: const TextStyle(fontSize: 11),
                            visualDensity: VisualDensity.compact,
                            backgroundColor:
                                asset.warrantyActive ? AppColors.brand50 : AppColors.surfaceAlt,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (asset.receiptUrl != null)
                const Icon(Icons.receipt_long, color: AppColors.brand600, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status),
      labelStyle: const TextStyle(fontSize: 11),
      visualDensity: VisualDensity.compact,
    );
  }
}
