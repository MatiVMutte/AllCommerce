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
    this.sku,
    this.imageUrl,
    this.stock = 0,
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
  final String? sku;
  final String? imageUrl;
  final int stock;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductCategory get categoryEnum => ProductCategory.fromId(category);

  factory ProductModel.fromJson(Map<String, dynamic> json) {
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
      sku: json['sku'] as String?,
      imageUrl: json['image_url'] as String?,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
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
      'sku': sku,
      'image_url': imageUrl,
      'stock': stock,
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
    String? sku,
    String? imageUrl,
    int? stock,
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
      sku: sku ?? this.sku,
      imageUrl: imageUrl ?? this.imageUrl,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
