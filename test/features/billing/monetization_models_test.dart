import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/features/admin/data/models/admin_models.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/billing/data/models/plan_model.dart';
import 'package:all_commerce/features/billing/data/repositories/ai_usage_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserModel parses is_admin and defaults to false', () {
    final Map<String, dynamic> base = <String, dynamic>{
      'id': 'u1',
      'role': 'owner',
      'full_name': 'Ana',
      'created_at': '2025-01-01T00:00:00Z',
    };
    expect(UserModel.fromJson(base).isAdmin, isFalse);
    expect(
      UserModel.fromJson(<String, dynamic>{...base, 'is_admin': true}).isAdmin,
      isTrue,
    );
    final UserModel admin = UserModel.fromJson(<String, dynamic>{
      ...base,
      'is_admin': true,
    });
    expect(admin.toJson()['is_admin'], isTrue);
    expect(admin.copyWith(fullName: 'B').isAdmin, isTrue);
  });

  test('PlanModel parses nullable ai_analyses_per_month', () {
    final PlanModel p = PlanModel.fromJson(<String, dynamic>{
      'id': 'pro',
      'name': 'Pro',
      'max_products': 1000,
      'price_ars': 39900,
      'ai_analyses_per_month': null,
      'sort_order': 3,
      'highlights': <dynamic>['a', 'b'],
    });
    expect(p.id, PlanType.pro);
    expect(p.aiAnalysesPerMonth, isNull);
    expect(p.highlights, <String>['a', 'b']);
    expect(
      PlanModel.fromJson(<String, dynamic>{
        'id': 'inicial',
        'name': 'Inicial',
        'max_products': 30,
        'price_ars': 9900,
        'ai_analyses_per_month': 60,
        'sort_order': 1,
        'highlights': <dynamic>[],
      }).aiAnalysesPerMonth,
      60,
    );
  });

  test('AiUsage parses nullable limit and reached flag', () {
    expect(
      AiUsage.fromJson(<String, dynamic>{'used': 12, 'limit': 60}).limit,
      60,
    );
    final AiUsage unlimited = AiUsage.fromJson(<String, dynamic>{
      'used': 5,
      'limit': null,
    });
    expect(unlimited.limit, isNull);
    expect(unlimited.reached, isFalse);
    expect(
      AiUsage.fromJson(<String, dynamic>{'used': 60, 'limit': 60}).reached,
      isTrue,
    );
  });

  test('AdminMetrics parses', () {
    final AdminMetrics m = AdminMetrics.fromJson(<String, dynamic>{
      'tenants_total': 10,
      'tenants_paying': 4,
      'tenants_trial': 5,
      'tenants_expired': 1,
      'mrr_ars': 69700,
      'customers_total': 42,
      'orders_month': 9,
      'orders_total': 120,
      'ai_month': 77,
    });
    expect(m.tenantsPaying, 4);
    expect(m.mrrArs, 69700);
    expect(m.aiMonth, 77);
  });

  test('AdminTenantRow parses null last_order_at', () {
    final AdminTenantRow row = AdminTenantRow.fromJson(<String, dynamic>{
      'id': 't1',
      'name': 'Demo',
      'slug': 'demo',
      'plan': 'inicial',
      'plan_expires_at': '2030-01-01T00:00:00Z',
      'is_active': true,
      'created_at': '2025-01-01T00:00:00Z',
      'owner_name': 'Ana',
      'owner_email': 'a@b.com',
      'owner_phone': null,
      'last_sign_in_at': null,
      'product_count': 3,
      'order_count': 0,
      'last_order_at': null,
      'ai_used_month': 7,
    });
    expect(row.plan, PlanType.inicial);
    expect(row.lastOrderAt, isNull);
    expect(row.lastSignInAt, isNull);
    expect(row.aiUsedMonth, 7);
  });
}
