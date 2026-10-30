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
    final ProductModel product = ProductModel.fromJson(
      _productJson(price: '8500.00'),
    );
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
    expect(ProductModel.fromJson(json).categoryEnum, ProductCategory.other);
  });

  test('compare_at_price enables sale flag and discount percentage', () {
    final Map<String, dynamic> json = _productJson(price: 7500);
    json['compare_at_price'] = '10000';
    final ProductModel product = ProductModel.fromJson(json);
    expect(product.compareAtPrice, 10000.0);
    expect(product.isOnSale, isTrue);
    expect(product.discountPercent, 25);

    final ProductModel notOnSale = product.copyWith(clearCompareAtPrice: true);
    expect(notOnSale.isOnSale, isFalse);
    expect(notOnSale.discountPercent, 0);
  });

  test('track_stock controls isOutOfStock and isLowStock', () {
    final Map<String, dynamic> untrackedJson = _productJson();
    untrackedJson['stock'] = 0;
    untrackedJson['track_stock'] = false;
    final ProductModel untracked = ProductModel.fromJson(untrackedJson);
    expect(untracked.isOutOfStock, isFalse);
    expect(untracked.isLowStock, isFalse);

    final ProductModel trackedOut = untracked.copyWith(trackStock: true);
    expect(trackedOut.isOutOfStock, isTrue);
    expect(trackedOut.isLowStock, isFalse);

    final ProductModel trackedLow = trackedOut.copyWith(stock: 2);
    expect(trackedLow.isOutOfStock, isFalse);
    expect(trackedLow.isLowStock, isTrue);

    final ProductModel trackedPlenty = trackedOut.copyWith(stock: 10);
    expect(trackedPlenty.isOutOfStock, isFalse);
    expect(trackedPlenty.isLowStock, isFalse);
  });
}
