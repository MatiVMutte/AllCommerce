import 'package:all_commerce/core/constants/app_colors.dart';
import 'package:all_commerce/core/constants/categories.dart';
import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _tenantJson({
  DateTime? planExpiresAt,
  bool isActive = true,
}) {
  return <String, dynamic>{
    'id': 't1',
    'slug': 'demo',
    'name': 'Demo Store',
    'description': 'Tienda demo',
    'address': 'Calle 1',
    'whatsapp': '5491100000000',
    'logo_url': null,
    'primary_color': '#165BE3',
    'plan': 'crecimiento',
    'trial_started_at': '2025-01-01T00:00:00Z',
    'plan_expires_at':
        (planExpiresAt ?? DateTime.now().add(const Duration(days: 10)))
            .toIso8601String(),
    'is_active': isActive,
    'created_at': '2025-01-01T00:00:00Z',
  };
}

void main() {
  group('TenantModel', () {
    test('fromJson parses all fields', () {
      final Map<String, dynamic> json = _tenantJson();
      json['is_open'] = false;
      json['opening_hours'] = 'Lun a Vie 9 a 18 hs';
      final TenantModel tenant = TenantModel.fromJson(json);
      expect(tenant.slug, 'demo');
      expect(tenant.name, 'Demo Store');
      expect(tenant.plan, PlanType.crecimiento);
      expect(tenant.primaryColorValue, const Color(0xFF165BE3));
      expect(tenant.isActive, isTrue);
      expect(tenant.isOpen, isFalse);
      expect(tenant.openingHours, 'Lun a Vie 9 a 18 hs');
    });

    test('invalid color falls back to AppColors.primary', () {
      final Map<String, dynamic> json = _tenantJson();
      json['primary_color'] = 'not-a-color';
      expect(TenantModel.fromJson(json).primaryColorValue, AppColors.primary);
    });

    test('discounts and visibility parse and compute', () {
      final Map<String, dynamic> json = _tenantJson();
      json['is_public'] = false;
      json['cash_discount_pct'] = 10;
      json['transfer_discount_pct'] = 5;
      json['bulk_discount_pct'] = 15;
      json['bulk_discount_min'] = 100000;
      final TenantModel tenant = TenantModel.fromJson(json);

      expect(tenant.isPublic, isFalse);
      expect(tenant.paymentDiscountPct('cash'), 10);
      expect(tenant.paymentDiscountPct('transfer'), 5);
      expect(tenant.paymentDiscountPct('mercado_pago'), 0);
      expect(tenant.paymentDiscountFor(1000, 'cash'), 100);
      expect(tenant.bulkDiscountFor(99999), 0);
      expect(tenant.bulkDiscountFor(100000), 15000);

      // Defaults: public, no discounts.
      final TenantModel base = TenantModel.fromJson(_tenantJson());
      expect(base.isPublic, isTrue);
      expect(base.cashDiscountPct, 0);
      expect(base.bulkDiscountFor(999999999), 0);
    });

    test('canPublish false when plan expired or inactive', () {
      final TenantModel expired = TenantModel.fromJson(
        _tenantJson(
          planExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
      expect(expired.canPublish, isFalse);
      expect(expired.daysLeft, 0);

      final TenantModel inactive = TenantModel.fromJson(
        _tenantJson(isActive: false),
      );
      expect(inactive.canPublish, isFalse);

      expect(TenantModel.fromJson(_tenantJson()).canPublish, isTrue);
    });
  });

  test('ProductCategory.fromId falls back to other', () {
    expect(ProductCategory.fromId('xxx'), ProductCategory.other);
    expect(ProductCategory.fromId('footwear'), ProductCategory.footwear);
  });

  test('PlanType.fromId resolves pro with 1000 products', () {
    expect(PlanType.fromId('pro').maxProducts, 1000);
    expect(PlanType.fromId('nope'), PlanType.free);
  });
}
