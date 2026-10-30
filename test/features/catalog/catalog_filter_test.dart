import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:flutter_test/flutter_test.dart';

ProductModel _product({
  required String id,
  required String title,
  String? description,
  String category = 'home',
  List<String> tags = const <String>[],
  double price = 100,
  double? compareAtPrice,
}) {
  return ProductModel(
    id: id,
    tenantId: 't1',
    title: title,
    description: description,
    category: category,
    tags: tags,
    price: price,
    compareAtPrice: compareAtPrice,
    isActive: true,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );
}

void main() {
  final List<ProductModel> products = <ProductModel>[
    _product(
      id: '1',
      title: 'Vaso térmico',
      category: 'home',
      price: 80,
      compareAtPrice: 100,
    ),
    _product(id: '2', title: 'Remera lisa', category: 'clothing'),
    _product(
      id: '3',
      title: 'Mate imperial',
      tags: <String>['termo', 'cocina'],
    ),
  ];

  group('applyCatalogFilter', () {
    test('empty filter returns all', () {
      expect(applyCatalogFilter(products, const CatalogFilter()).length, 3);
    });

    test('query matches title case-insensitively', () {
      final List<ProductModel> result = applyCatalogFilter(
        products,
        const CatalogFilter(query: 'vaso'),
      );
      expect(result.map((ProductModel p) => p.id), <String>['1']);
    });

    test('query matches without accents', () {
      final List<ProductModel> result = applyCatalogFilter(
        products,
        const CatalogFilter(query: 'termico'),
      );
      expect(result.map((ProductModel p) => p.id), <String>['1']);
    });

    test('query matches tags', () {
      final List<ProductModel> result = applyCatalogFilter(
        products,
        const CatalogFilter(query: 'termo'),
      );
      expect(result.map((ProductModel p) => p.id), <String>['3']);
    });

    test('category filter', () {
      final List<ProductModel> result = applyCatalogFilter(
        products,
        const CatalogFilter(category: 'clothing'),
      );
      expect(result.map((ProductModel p) => p.id), <String>['2']);
    });

    test('category + query combined', () {
      final List<ProductModel> result = applyCatalogFilter(
        products,
        const CatalogFilter(query: 'termico', category: 'clothing'),
      );
      expect(result, isEmpty);
    });

    test('onlyOnSale filters to discounted products', () {
      final List<ProductModel> result = applyCatalogFilter(
        products,
        const CatalogFilter(onlyOnSale: true),
      );
      expect(result.map((ProductModel p) => p.id), <String>['1']);
    });
  });

  group('filterTenants', () {
    final List<TenantModel> tenants = <TenantModel>[
      TenantModel(
        id: 't1',
        slug: 'demo',
        name: 'Bazar Céntrico',
        description: 'Todo para el hogar',
        whatsapp: '5491122334455',
        primaryColor: '#0052FF',
        plan: PlanType.trial,
        trialStartedAt: DateTime(2025),
        planExpiresAt: DateTime.now().add(const Duration(days: 5)),
        isActive: true,
        isClaimed: true,
        createdAt: DateTime(2025),
      ),
    ];

    test('matches name without accents', () {
      expect(filterTenants(tenants, 'centrico'), hasLength(1));
      expect(filterTenants(tenants, 'zapatos'), isEmpty);
      expect(filterTenants(tenants, ''), hasLength(1));
    });
  });
}
