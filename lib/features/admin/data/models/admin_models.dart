import 'package:all_commerce/core/constants/plans.dart';

/// Platform-wide metrics returned by the `admin_metrics` RPC.
class AdminMetrics {
  const AdminMetrics({
    required this.tenantsTotal,
    required this.tenantsPaying,
    required this.tenantsTrial,
    required this.tenantsExpired,
    required this.mrrArs,
    required this.customersTotal,
    required this.ordersMonth,
    required this.ordersTotal,
    required this.aiMonth,
  });

  final int tenantsTotal;
  final int tenantsPaying;
  final int tenantsTrial;
  final int tenantsExpired;
  final num mrrArs;
  final int customersTotal;
  final int ordersMonth;
  final int ordersTotal;
  final int aiMonth;

  factory AdminMetrics.fromJson(Map<String, dynamic> json) {
    int num_(String k) => (json[k] as num?)?.toInt() ?? 0;
    return AdminMetrics(
      tenantsTotal: num_('tenants_total'),
      tenantsPaying: num_('tenants_paying'),
      tenantsTrial: num_('tenants_trial'),
      tenantsExpired: num_('tenants_expired'),
      mrrArs: json['mrr_ars'] as num? ?? 0,
      customersTotal: num_('customers_total'),
      ordersMonth: num_('orders_month'),
      ordersTotal: num_('orders_total'),
      aiMonth: num_('ai_month'),
    );
  }
}

/// One row of the `admin_tenants_overview` RPC.
class AdminTenantRow {
  const AdminTenantRow({
    required this.id,
    required this.name,
    required this.slug,
    required this.plan,
    required this.planExpiresAt,
    required this.isActive,
    required this.createdAt,
    this.ownerName,
    this.ownerEmail,
    this.ownerPhone,
    this.lastSignInAt,
    required this.productCount,
    required this.orderCount,
    this.lastOrderAt,
    required this.aiUsedMonth,
  });

  final String id;
  final String name;
  final String slug;
  final PlanType plan;
  final DateTime planExpiresAt;
  final bool isActive;
  final DateTime createdAt;
  final String? ownerName;
  final String? ownerEmail;
  final String? ownerPhone;
  final DateTime? lastSignInAt;
  final int productCount;
  final int orderCount;
  final DateTime? lastOrderAt;
  final int aiUsedMonth;

  factory AdminTenantRow.fromJson(Map<String, dynamic> json) {
    DateTime? dateOrNull(String k) {
      final String? v = json[k] as String?;
      return v == null ? null : DateTime.parse(v);
    }

    return AdminTenantRow(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      plan: PlanType.fromId(json['plan'] as String? ?? 'trial'),
      planExpiresAt:
          dateOrNull('plan_expires_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
      isActive: json['is_active'] as bool? ?? false,
      createdAt:
          dateOrNull('created_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
      ownerName: json['owner_name'] as String?,
      ownerEmail: json['owner_email'] as String?,
      ownerPhone: json['owner_phone'] as String?,
      lastSignInAt: dateOrNull('last_sign_in_at'),
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
      orderCount: (json['order_count'] as num?)?.toInt() ?? 0,
      lastOrderAt: dateOrNull('last_order_at'),
      aiUsedMonth: (json['ai_used_month'] as num?)?.toInt() ?? 0,
    );
  }
}
