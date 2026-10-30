/// Sellable units of a product. 'unidad' sells whole items (integer
/// quantities); the rest accept fractional amounts ("1,25 kg", "0,5 lt").
/// Must match the `products_unit_values` check constraint.
abstract final class ProductUnit {
  static const String unidad = 'unidad';

  static const List<String> ids = <String>[
    unidad,
    'kg',
    'g',
    'lt',
    'ml',
    'm',
    'docena',
  ];

  static bool isFractional(String id) => id != unidad;

  /// Short label appended to quantities ('un.', 'kg'...).
  static String labelOf(String id) => switch (id) {
    'kg' => 'kg',
    'g' => 'g',
    'lt' => 'lt',
    'ml' => 'ml',
    'm' => 'm',
    'docena' => 'doc.',
    _ => 'un.',
  };

  /// Long label for the product form dropdown.
  static String nameOf(String id) => switch (id) {
    'kg' => 'Kilogramo (kg)',
    'g' => 'Gramo (g)',
    'lt' => 'Litro (lt)',
    'ml' => 'Mililitro (ml)',
    'm' => 'Metro (m)',
    'docena' => 'Docena (doc.)',
    _ => 'Unidad (un.)',
  };
}
