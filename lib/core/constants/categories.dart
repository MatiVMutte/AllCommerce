enum ProductCategory {
  clothing('clothing', 'Indumentaria'),
  footwear('footwear', 'Calzado'),
  accessories('accessories', 'Accesorios'),
  electronics('electronics', 'Electrónica'),
  home('home', 'Hogar'),
  beauty('beauty', 'Belleza'),
  food('food', 'Alimentos'),
  toys('toys', 'Juguetería'),
  stationery('stationery', 'Librería'),
  other('other', 'Otros');

  const ProductCategory(this.id, this.label);

  /// Value stored in the database.
  final String id;

  /// Spanish display label.
  final String label;

  static ProductCategory fromId(String id) {
    for (final ProductCategory category in values) {
      if (category.id == id) return category;
    }
    return ProductCategory.other;
  }

  static List<String> get ids =>
      values.map((ProductCategory c) => c.id).toList();

  /// Spanish label for a stored category value. Free-form categories
  /// (added after the enum was relaxed) are returned capitalized.
  static String labelOf(String raw) {
    final String id = raw.trim().toLowerCase();
    for (final ProductCategory category in values) {
      if (category.id == id || category.label.toLowerCase() == id) {
        return category.label;
      }
    }
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return ProductCategory.other.label;
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  /// Value to persist for a user-typed category: enum id when the text
  /// matches a known category (keeps old data consistent), otherwise the
  /// trimmed free-form text.
  static String storedValue(String input) {
    final String trimmed = input.trim();
    final String lower = trimmed.toLowerCase();
    for (final ProductCategory category in values) {
      if (category.id == lower || category.label.toLowerCase() == lower) {
        return category.id;
      }
    }
    return trimmed;
  }
}
