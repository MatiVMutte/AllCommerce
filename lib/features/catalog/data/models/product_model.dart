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
    this.wholesalePrice,
    this.wholesaleMinQty,
    this.sku,
    this.imageUrl,
    this.imageUrls = const <String>[],
    this.variants = const <String>[],
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

  /// Wholesale unit price when the buyer takes at least [wholesaleMinQty].
  final double? wholesalePrice;
  final int? wholesaleMinQty;
  final String? sku;

  /// Main photo (first of the gallery). Kept for backwards compatibility.
  final String? imageUrl;

  /// All photos, main first. Empty when the product has no image_urls yet.
  final List<String> imageUrls;

  /// Store-defined options ("S", "M", "L", "Rojo"...) the buyer picks one of.
  final List<String> variants;
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

  /// Photos to show in the detail gallery, main first.
  List<String> get gallery => imageUrls.isNotEmpty
      ? imageUrls
      : (imageUrl == null ? const <String>[] : <String>[imageUrl!]);

  bool get hasVariants => variants.isNotEmpty;

  bool get hasWholesale =>
      wholesalePrice != null && wholesaleMinQty != null && wholesaleMinQty! > 0;

  /// Unit price the server charges for [quantity] units: switches to the
  /// wholesale price when the quantity reaches the minimum, never above
  /// retail. Mirrors `place_order`.
  double unitPriceFor(int quantity) {
    if (hasWholesale && quantity >= wholesaleMinQty!) {
      return wholesalePrice! < price ? wholesalePrice! : price;
    }
    return price;
  }

  /// Units missing to unlock the wholesale price (0 when not applicable).
  int wholesaleMissing(int quantity) =>
      hasWholesale && quantity < wholesaleMinQty!
      ? wholesaleMinQty! - quantity
      : 0;

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
    final Object? rawWholesale = json['wholesale_price'];
    final double? parsedWholesale = rawWholesale == null
        ? null
        : num.tryParse(rawWholesale.toString())?.toDouble();
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
      wholesalePrice: parsedWholesale,
      wholesaleMinQty: (json['wholesale_min_qty'] as num?)?.toInt(),
      sku: json['sku'] as String?,
      imageUrl: json['image_url'] as String?,
      imageUrls: (json['image_urls'] as List<dynamic>? ?? <dynamic>[])
          .whereType<String>()
          .toList(),
      variants: (json['variants'] as List<dynamic>? ?? <dynamic>[])
          .whereType<String>()
          .toList(),
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
      'wholesale_price': wholesalePrice,
      'wholesale_min_qty': wholesaleMinQty,
      'sku': sku,
      'image_url': imageUrl,
      'image_urls': imageUrls,
      'variants': variants,
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
    double? wholesalePrice,
    int? wholesaleMinQty,
    bool clearWholesale = false,
    String? sku,
    String? imageUrl,
    List<String>? imageUrls,
    List<String>? variants,
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
      wholesalePrice: clearWholesale
          ? null
          : (wholesalePrice ?? this.wholesalePrice),
      wholesaleMinQty: clearWholesale
          ? null
          : (wholesaleMinQty ?? this.wholesaleMinQty),
      sku: sku ?? this.sku,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      variants: variants ?? this.variants,
      stock: stock ?? this.stock,
      trackStock: trackStock ?? this.trackStock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
