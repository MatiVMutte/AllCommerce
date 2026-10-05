import 'package:all_commerce/core/router/parent_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store routes', () {
    expect(parentPathOf('/s/demo/p/abc'), '/s/demo');
    expect(parentPathOf('/s/demo/cart'), '/s/demo');
    expect(parentPathOf('/s/demo/order/o1'), '/s/demo');
    expect(parentPathOf('/s/demo'), '/');
  });

  test('owner routes', () {
    expect(parentPathOf('/owner/products/new'), '/owner/products');
    expect(parentPathOf('/owner/products/p1/edit'), '/owner/products');
    expect(parentPathOf('/owner/products'), '/owner');
    expect(parentPathOf('/owner/orders/o1'), '/owner/orders');
    expect(parentPathOf('/owner/orders'), '/owner');
    expect(parentPathOf('/owner'), isNull);
    expect(parentPathOf('/owner/plans'), '/owner');
  });

  test('admin routes', () {
    expect(parentPathOf('/admin/tenants/t1'), '/admin');
    expect(parentPathOf('/admin/plans'), '/admin');
    expect(parentPathOf('/admin'), '/owner');
  });

  test('auth routes', () {
    expect(parentPathOf('/my-orders'), '/');
    expect(parentPathOf('/profile'), '/');
    expect(parentPathOf('/login'), '/');
    expect(parentPathOf('/welcome'), '/');
    expect(parentPathOf('/register'), '/login');
    expect(parentPathOf('/forgot-password'), '/login');
  });

  test('roots return null', () {
    expect(parentPathOf('/'), isNull);
    expect(parentPathOf('/select-role'), isNull);
    expect(parentPathOf('/onboarding/business'), isNull);
    expect(parentPathOf('/onboarding/customer'), isNull);
  });

  test('ignores query string', () {
    expect(parentPathOf('/s/demo/cart?x=1'), '/s/demo');
  });
}
