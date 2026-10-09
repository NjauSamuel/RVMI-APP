class InventoryCategory {
  const InventoryCategory({required this.id, required this.name});

  factory InventoryCategory.fromJson(Map<String, dynamic> json) =>
      InventoryCategory(id: json['id'] as int, name: json['name'] as String);

  final int id;
  final String name;
}

class InventoryAsset {
  const InventoryAsset({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.assetImageUrl,
    required this.receiptUrl,
    required this.receiptMime,
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
    receiptUrl: json['receipt_url'] as String?,
    receiptMime: json['receipt_mime'] as String?,
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
  final String? receiptUrl;
  final String? receiptMime;
  final String? purchaseDate;
  final String? warrantyExpiry;
  final bool warrantyActive;
  final String status;
}
