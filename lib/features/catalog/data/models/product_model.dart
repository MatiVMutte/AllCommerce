import 'package:all_commerce/core/constants/categories.dart';

class ProductModel {
  const ProductModel({
    required this.id,
    required this.tenantId,
    required this.title,
    this.description,
    required this.category,
    this.tags = const <String>[],
    required this.price,
    this.compareAtPrice,
    this.sku,
    this.imageUrl,
    this.stock = 0,
    this.trackStock = false,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String title;
  final String? description;

  /// Category id as stored in the database.
  final String category;
  final List<String> tags;
  final double price;
  final double? compareAtPrice;
  final String? sku;
  final String? imageUrl;
  final int stock;
  final bool trackStock;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductCategory get categoryEnum => ProductCategory.fromId(category);

  /// Display label: Spanish name for known enum ids, the typed text for
  /// store-defined categories ("Bebidas", "Limpieza"...).
  String get categoryLabel => ProductCategory.labelOf(category);

  bool get isOnSale =>
      compareAtPrice != null && compareAtPrice! > price && price > 0;

  bool get isOutOfStock => trackStock && stock <= 0;

  bool get isLowStock => trackStock && stock > 0 && stock <= 3;

  int get discountPercent {
    if (!isOnSale) return 0;
    return (((compareAtPrice! - price) / compareAtPrice!) * 100).round().clamp(
      1,
      99,
    );
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final Object? rawCompare = json['compare_at_price'];
    final double? parsedCompare = rawCompare == null
        ? null
        : num.tryParse(rawCompare.toString())?.toDouble();
    return ProductModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      tags: (json['tags'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic t) => t as String)
          .toList(),
      price: num.parse(json['price'].toString()).toDouble(),
      compareAtPrice: parsedCompare,
      sku: json['sku'] as String?,
      imageUrl: json['image_url'] as String?,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      trackStock: json['track_stock'] as bool? ?? false,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'tenant_id': tenantId,
      'title': title,
      'description': description,
      'category': category,
      'tags': tags,
      'price': price,
      'compare_at_price': compareAtPrice,
      'sku': sku,
      'image_url': imageUrl,
      'stock': stock,
      'track_stock': trackStock,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? tenantId,
    String? title,
    String? description,
    String? category,
    List<String>? tags,
    double? price,
    double? compareAtPrice,
    bool clearCompareAtPrice = false,
    String? sku,
    String? imageUrl,
    int? stock,
    bool? trackStock,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      price: price ?? this.price,
      compareAtPrice: clearCompareAtPrice
          ? null
          : (compareAtPrice ?? this.compareAtPrice),
      sku: sku ?? this.sku,
      imageUrl: imageUrl ?? this.imageUrl,
      stock: stock ?? this.stock,
      trackStock: trackStock ?? this.trackStock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
