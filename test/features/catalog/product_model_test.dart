import 'package:all_commerce/core/constants/categories.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _productJson({Object price = 8500}) {
  return <String, dynamic>{
    'id': 'p1',
    'tenant_id': 't1',
    'title': 'Vaso térmico',
    'description': 'Acero inoxidable',
    'category': 'home',
    'tags': <String>['cocina', 'mate'],
    'price': price,
    'sku': 'V-01',
    'image_url': null,
    'stock': 5,
    'is_active': true,
    'created_at': '2025-01-01T00:00:00Z',
    'updated_at': '2025-01-02T00:00:00Z',
  };
}

void main() {
  test('fromJson parses price given as String', () {
    final ProductModel product =
        ProductModel.fromJson(_productJson(price: '8500.00'));
    expect(product.price, 8500.0);
    expect(product.tags, <String>['cocina', 'mate']);
    expect(product.categoryEnum, ProductCategory.home);
  });

  test('fromJson parses price given as num', () {
    expect(ProductModel.fromJson(_productJson()).price, 8500.0);
  });

  test('toJson roundtrip', () {
    final ProductModel product = ProductModel.fromJson(_productJson());
    final ProductModel copy = ProductModel.fromJson(product.toJson());
    expect(copy.id, product.id);
    expect(copy.price, product.price);
    expect(copy.tags, product.tags);
  });

  test('unknown category falls back to other', () {
    final Map<String, dynamic> json = _productJson();
    json['category'] = 'xxx';
    expect(
      ProductModel.fromJson(json).categoryEnum,
      ProductCategory.other,
    );
  });
}
