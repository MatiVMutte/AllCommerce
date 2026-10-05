import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/features/admin/data/models/admin_models.dart';

enum AdminTenantStatus { paying, trial, expired, inactive }

/// Classifies a tenant row for the admin list: inactive > expired > trial >
/// paying.
AdminTenantStatus adminTenantStatus(AdminTenantRow row, {DateTime? now}) {
  final DateTime n = now ?? DateTime.now();
  if (!row.isActive) return AdminTenantStatus.inactive;
  if (!row.planExpiresAt.isAfter(n)) return AdminTenantStatus.expired;
  if (row.plan == PlanType.trial) return AdminTenantStatus.trial;
  return AdminTenantStatus.paying;
}
