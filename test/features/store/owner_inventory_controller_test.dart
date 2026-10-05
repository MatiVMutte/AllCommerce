import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/product_upload/data/repositories/product_repository.dart';
import 'package:all_commerce/features/product_upload/presentation/view_models/product_upload_controller.dart';
import 'package:all_commerce/features/store/presentation/view_models/owner_products_providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProductRepository extends Mock implements ProductRepository {}

class _FakeOwnerProducts extends OwnerProductsNotifier {
  _FakeOwnerProducts(super.tenantId, this.items);

  final List<ProductModel> items;

  @override
  Future<List<ProductModel>> build() async => items;
}

void main() {
  late MockProductRepository products;
  late ProviderContainer container;

  final ProductModel product = ProductModel(
    id: 'p1',
    tenantId: 't1',
    title: 'Vaso térmico',
    category: 'home',
    tags: <String>['cocina'],
    price: 100,
    sku: 'V-1',
    isActive: true,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );

  OwnerInventoryState readState() =>
      container.read(ownerInventoryControllerProvider);
  OwnerInventoryController controller() =>
      container.read(ownerInventoryControllerProvider.notifier);

  setUp(() {
    products = MockProductRepository();
    container = ProviderContainer(
      overrides: [productRepositoryProvider.overrideWithValue(products)],
    );
    addTearDown(container.dispose);
  });

  test('toggleActive calls setActive with inverted value', () async {
    when(() => products.setActive(any(), any(), any()))
        .thenAnswer((_) async {});

    final bool ok = await controller().toggleActive(product);

    expect(ok, isTrue);
    verify(() => products.setActive('p1', 't1', false)).called(1);
    expect(readState().busyProductId, isNull);
  });

  test('delete calls repo and clears busy state', () async {
    when(() => products.delete(any(), any())).thenAnswer((_) async {});

    final bool ok = await controller().delete(product);

    expect(ok, isTrue);
    verify(() => products.delete('p1', 't1')).called(1);
    expect(readState().busyProductId, isNull);
  });

  test('delete error sets state.error', () async {
    when(() => products.delete(any(), any())).thenThrow(Exception('boom'));

    final bool ok = await controller().delete(product);

    expect(ok, isFalse);
    expect(readState().error, isNotNull);
    expect(readState().busyProductId, isNull);
  });

  group('optimistic updates', () {
    Future<void> seed() async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          productRepositoryProvider.overrideWithValue(products),
          ownerProductsProvider('t1')
              .overrideWith(() => _FakeOwnerProducts('t1', [product])),
        ],
      );
      await container.read(ownerProductsProvider('t1').future);
    }

    List<ProductModel> list() =>
        container.read(ownerProductsProvider('t1')).value!;

    test('toggleActive flips optimistically, then confirms', () async {
      await seed();
      final Completer<void> pending = Completer<void>();
      when(() => products.setActive(any(), any(), any()))
          .thenAnswer((_) => pending.future);

      final Future<bool> future = controller().toggleActive(product);
      expect(list().single.isActive, isFalse);

      pending.complete();
      expect(await future, isTrue);
    });

    test('toggleActive reverts on failure', () async {
      await seed();
      when(() => products.setActive(any(), any(), any()))
          .thenThrow(Exception('boom'));

      final bool ok = await controller().toggleActive(product);

      expect(ok, isFalse);
      expect(list().single.isActive, isTrue);
      expect(readState().error, isNotNull);
    });

    test('delete removes optimistically, then confirms', () async {
      await seed();
      final Completer<void> pending = Completer<void>();
      when(() => products.delete(any(), any()))
          .thenAnswer((_) => pending.future);

      final Future<bool> future = controller().delete(product);
      expect(list(), isEmpty);

      pending.complete();
      expect(await future, isTrue);
    });

    test('delete restores the list on failure', () async {
      await seed();
      when(() => products.delete(any(), any())).thenThrow(Exception('boom'));

      final bool ok = await controller().delete(product);

      expect(ok, isFalse);
      expect(list().map((ProductModel p) => p.id), <String>['p1']);
    });
  });

  group('filterOwnerProducts', () {
    final List<ProductModel> list = <ProductModel>[
      product,
      product.copyWith(
        id: 'p2',
        title: 'Remera',
        category: 'clothing',
        sku: 'R-9',
        tags: const <String>['remera'],
        isActive: false,
      ),
    ];

    test('matches title, sku and tags without accents', () {
      expect(
        filterOwnerProducts(
          list,
          query: 'termico',
        ).map((ProductModel p) => p.id),
        <String>['p1'],
      );
      expect(
        filterOwnerProducts(list, query: 'r-9').map((ProductModel p) => p.id),
        <String>['p2'],
      );
      expect(
        filterOwnerProducts(
          list,
          query: 'cocina',
        ).map((ProductModel p) => p.id),
        <String>['p1'],
      );
    });

    test('active/paused filter', () {
      expect(
        filterOwnerProducts(
          list,
          filter: OwnerFilter.active,
        ).map((ProductModel p) => p.id),
        <String>['p1'],
      );
      expect(
        filterOwnerProducts(
          list,
          filter: OwnerFilter.paused,
        ).map((ProductModel p) => p.id),
        <String>['p2'],
      );
      expect(filterOwnerProducts(list).length, 2);
    });
  });
}
