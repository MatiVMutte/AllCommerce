import 'package:flutter/foundation.dart';


/// A single draft product during a bulk AI upload session.
@immutable
class BulkProductDraft {
  const BulkProductDraft({
    required this.id,
    this.title = '',
    this.description,
    this.category = 'otros',
    this.tags = const <String>[],
    this.sku,
    this.price,
    this.compareAtPrice,
    this.stock = 0,
    required this.imageBytes,
    required this.fileName,
    this.analyzed = false,
    this.analyzing = false,
    this.publishing = false,
    this.error,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String? description;
  final String category;
  final List<String> tags;
  final String? sku;
  final double? price;
  final double? compareAtPrice;
  final int stock;
  final Uint8List imageBytes;
  final String fileName;
  final bool analyzed;
  final bool analyzing;
  final bool publishing;
  final String? error;
  final String? imageUrl;

  BulkProductDraft copyWith({
    String? title,
    String? description,
    String? category,
    List<String>? tags,
    String? sku,
    double? price,
    double? compareAtPrice,
    int? stock,
    Uint8List? imageBytes,
    String? fileName,
    bool? analyzed,
    bool? analyzing,
    bool? publishing,
    String? error,
    String? imageUrl,
  }) {
    return BulkProductDraft(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      stock: stock ?? this.stock,
      imageBytes: imageBytes ?? this.imageBytes,
      fileName: fileName ?? this.fileName,
      analyzed: analyzed ?? this.analyzed,
      analyzing: analyzing ?? this.analyzing,
      publishing: publishing ?? this.publishing,
      error: error ?? this.error,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  bool get isValid => title.trim().isNotEmpty && price != null && price! > 0;
}
