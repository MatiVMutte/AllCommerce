import 'package:all_commerce/features/admin/data/models/admin_models.dart';
import 'package:all_commerce/features/admin/presentation/view_models/admin_tenant_status.dart';
import 'package:all_commerce/core/constants/plans.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime(2025, 6, 15);

  AdminTenantRow row({
    PlanType plan = PlanType.inicial,
    DateTime? expiresAt,
    bool isActive = true,
  }) {
    return AdminTenantRow(
      id: 't1',
      name: 'Demo',
      slug: 'demo',
      plan: plan,
      planExpiresAt: expiresAt ?? DateTime(2025, 7, 15),
      isActive: isActive,
      createdAt: DateTime(2025),
      productCount: 0,
      orderCount: 0,
      aiUsedMonth: 0,
    );
  }

  test('classification', () {
    expect(
      adminTenantStatus(row(), now: now),
      AdminTenantStatus.paying,
    );
    expect(
      adminTenantStatus(row(plan: PlanType.trial), now: now),
      AdminTenantStatus.trial,
    );
    expect(
      adminTenantStatus(
        row(expiresAt: DateTime(2025, 6, 1)),
        now: now,
      ),
      AdminTenantStatus.expired,
    );
    expect(
      adminTenantStatus(row(isActive: false), now: now),
      AdminTenantStatus.inactive,
    );
    // Inactive wins over expired.
    expect(
      adminTenantStatus(
        row(isActive: false, expiresAt: DateTime(2025, 1, 1)),
        now: now,
      ),
      AdminTenantStatus.inactive,
    );
  });
}
