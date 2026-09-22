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
}
