class InventoryCategory {
  const InventoryCategory({required this.id, required this.name});

  factory InventoryCategory.fromJson(Map<String, dynamic> json) =>
      InventoryCategory(id: json['id'] as int, name: json['name'] as String);

  final int id;
  final String name;
}

class InventoryReceipt {
  const InventoryReceipt({required this.id, required this.url, required this.mime});

  factory InventoryReceipt.fromJson(Map<String, dynamic> json) => InventoryReceipt(
    id: json['id'] as int,
    url: json['url'] as String,
    mime: json['mime'] as String? ?? 'image',
  );

  final int id;
  final String url;
  final String mime;
}

class InventoryAsset {
  const InventoryAsset({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.assetImageUrl,
    required this.receipts,
    required this.purchaseDate,
    required this.warrantyExpiry,
    required this.warrantyActive,
    required this.status,
  });

  factory InventoryAsset.fromJson(Map<String, dynamic> json) => InventoryAsset(
    id: json['id'] as int,
    name: json['name'] as String,
    categoryId: json['category_id'] as int?,
    categoryName: json['category'] as String?,
    description: json['description'] as String?,
    assetImageUrl: json['asset_image_url'] as String?,
    receipts: (json['receipts'] as List? ?? const [])
        .map((entry) => InventoryReceipt.fromJson(Map<String, dynamic>.from(entry as Map)))
        .toList(),
    purchaseDate: json['purchase_date'] as String?,
    warrantyExpiry: json['warranty_expiry'] as String?,
    warrantyActive: json['warranty_active'] as bool? ?? false,
    status: json['status'] as String? ?? 'active',
  );

  final int id;
  final String name;
  final int? categoryId;
  final String? categoryName;
  final String? description;
  final String? assetImageUrl;
  final List<InventoryReceipt> receipts;
  final String? purchaseDate;
  final String? warrantyExpiry;
  final bool warrantyActive;
  final String status;
}
