import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/storage/shared_preferences_provider.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/features/cart/data/models/cart_state.dart';
import 'package:all_commerce/features/cart/presentation/view_models/cart_controller.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

TenantModel _tenant({String id = 't1', String slug = 'local-uno'}) {
  return TenantModel(
    id: id,
    slug: slug,
    name: 'Local $id',
    whatsapp: '5491112345678',
    primaryColor: '#0052FF',
    plan: PlanType.trial,
    trialStartedAt: DateTime(2024),
    planExpiresAt: DateTime.now().add(const Duration(days: 30)),
    isActive: true,
    isClaimed: true,
    createdAt: DateTime(2024),
  );
}

ProductModel _product(String id, {double price = 100}) {
  return ProductModel(
    id: id,
    tenantId: 't1',
    title: 'Producto $id',
    category: 'otros',
    price: price,
    isActive: true,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

void main() {
  late SharedPreferences prefs;

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  test('add accumulates quantity for the same product', () {
    final ProviderContainer container = makeContainer();
    addTearDown(container.dispose);
    final CartController cart = container.read(cartProvider.notifier);
    final TenantModel tenant = _tenant();

    expect(cart.add(_product('p1'), tenant), AddResult.added);
    expect(cart.add(_product('p1'), tenant, quantity: 2), AddResult.added);

    final CartState state = container.read(cartProvider);
    expect(state.items, hasLength(1));
    expect(state.items.single.quantity, 3);
    expect(state.tenantId, 't1');
    expect(state.tenantSlug, 'local-uno');
  });

  test('add from another tenant returns differentStore and does not '
      'modify', () {
    final ProviderContainer container = makeContainer();
    addTearDown(container.dispose);
    final CartController cart = container.read(cartProvider.notifier);

    cart.add(_product('p1'), _tenant());
    final CartState before = container.read(cartProvider);

    expect(
      cart.add(_product('p2'), _tenant(id: 't2', slug: 'otro')),
      AddResult.differentStore,
    );
    final CartState after = container.read(cartProvider);
    expect(after.tenantId, before.tenantId);
    expect(after.items, hasLength(1));
    expect(after.items.single.productId, 'p1');
  });

  test('replaceWith empties and adds', () {
    final ProviderContainer container = makeContainer();
    addTearDown(container.dispose);
    final CartController cart = container.read(cartProvider.notifier);

    cart.add(_product('p1'), _tenant());
    cart.replaceWith(_product('p9'), _tenant(id: 't2', slug: 'otro'));

    final CartState state = container.read(cartProvider);
    expect(state.tenantId, 't2');
    expect(state.items.single.productId, 'p9');
  });

  test('setQuantity 0 removes the item', () {
    final ProviderContainer container = makeContainer();
    addTearDown(container.dispose);
    final CartController cart = container.read(cartProvider.notifier);

    cart.add(_product('p1'), _tenant());
    cart.setQuantity('p1|', 0);
    expect(container.read(cartProvider).isEmpty, isTrue);
  });

  test('same product with different variants lands as separate lines', () {
    final ProviderContainer container = makeContainer();
    addTearDown(container.dispose);
    final CartController cart = container.read(cartProvider.notifier);
    final TenantModel tenant = _tenant();

    cart.add(_product('p1'), tenant, variant: 'S');
    cart.add(_product('p1'), tenant, variant: 'M');
    cart.add(_product('p1'), tenant, variant: 'S', quantity: 2);

    final CartState state = container.read(cartProvider);
    expect(state.items, hasLength(2));
    expect(state.items.firstWhere((i) => i.variant == 'S').quantity, 3);
    expect(state.items.firstWhere((i) => i.variant == 'M').quantity, 1);
  });

  test('setQuantity/remove only touch the matching variant line', () {
    final ProviderContainer container = makeContainer();
    addTearDown(container.dispose);
    final CartController cart = container.read(cartProvider.notifier);
    final TenantModel tenant = _tenant();

    cart.add(_product('p1'), tenant, variant: 'S');
    cart.add(_product('p1'), tenant, variant: 'M');

    cart.setQuantity('p1|M', 5);
    CartState state = container.read(cartProvider);
    expect(state.items.firstWhere((i) => i.variant == 'S').quantity, 1);
    expect(state.items.firstWhere((i) => i.variant == 'M').quantity, 5);

    cart.remove('p1|S');
    state = container.read(cartProvider);
    expect(state.items, hasLength(1));
    expect(state.items.single.variant, 'M');
  });

  test('variant persists across containers sharing prefs', () async {
    final ProviderContainer container = makeContainer();
    container
        .read(cartProvider.notifier)
        .add(_product('p1'), _tenant(), variant: 'Rojo');
    container.dispose();

    await Future<void>.delayed(Duration.zero);

    final ProviderContainer container2 = makeContainer();
    addTearDown(container2.dispose);
    final CartState restored = container2.read(cartProvider);
    expect(restored.items.single.variant, 'Rojo');
  });

  test('cart persists across containers sharing prefs', () async {
    final ProviderContainer container = makeContainer();
    container.read(cartProvider.notifier).add(_product('p1'), _tenant());
    container.dispose();

    // Mock SharedPreferences writes synchronously; give the async
    // save a chance to land.
    await Future<void>.delayed(Duration.zero);

    final ProviderContainer container2 = makeContainer();
    addTearDown(container2.dispose);
    final CartState restored = container2.read(cartProvider);
    expect(restored.tenantId, 't1');
    expect(restored.items.single.productId, 'p1');
  });
}
