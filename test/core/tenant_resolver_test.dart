import 'package:all_commerce/core/tenant/tenant_strategy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TenantResolver', () {
    test('fixed slug wins over route and selected', () {
      const TenantResolver resolver = TenantResolver(fixedSlug: 'Demo');
      expect(
        resolver.resolveSlug(routeSlug: 'ruta', selectedSlug: 'elegido'),
        'demo',
      );
    });

    test('route slug wins over selected', () {
      const TenantResolver resolver = TenantResolver(fixedSlug: '');
      expect(
        resolver.resolveSlug(routeSlug: 'Ruta', selectedSlug: 'elegido'),
        'ruta',
      );
    });

    test('selected slug used when no route', () {
      const TenantResolver resolver = TenantResolver(fixedSlug: '');
      expect(resolver.resolveSlug(selectedSlug: 'Elegido'), 'elegido');
    });

    test('returns null when all empty', () {
      const TenantResolver resolver = TenantResolver(fixedSlug: '');
      expect(resolver.resolveSlug(), isNull);
      expect(resolver.resolveSlug(routeSlug: '  ', selectedSlug: ''), isNull);
    });

    test('normalizes whitespace and case', () {
      const TenantResolver resolver = TenantResolver(fixedSlug: '');
      expect(resolver.resolveSlug(routeSlug: '  Demo '), 'demo');
    });

    test('isWhiteLabel reflects fixed slug', () {
      expect(const TenantResolver(fixedSlug: 'demo').isWhiteLabel, isTrue);
      expect(const TenantResolver(fixedSlug: '').isWhiteLabel, isFalse);
    });
  });
}
