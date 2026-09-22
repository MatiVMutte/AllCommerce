class AiProductSuggestion {
  const AiProductSuggestion({
    required this.title,
    required this.description,
    required this.category,
    this.tags = const <String>[],
    this.suggestedPriceArs,
    this.sku,
  });

  final String title;
  final String description;

  /// Category id as returned by the AI (validated against ProductCategory).
  final String category;
  final List<String> tags;
  final double? suggestedPriceArs;
  final String? sku;

  factory AiProductSuggestion.fromJson(Map<String, dynamic> json) {
    return AiProductSuggestion(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      tags: (json['tags'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic t) => t as String)
          .toList(),
      suggestedPriceArs:
          (json['suggested_price_ars'] as num?)?.toDouble(),
      sku: json['sku'] as String?,
    );
  }
}
