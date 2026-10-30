import 'package:all_commerce/core/constants/plans.dart';

/// Platform-wide metrics returned by the `admin_metrics` RPC.
class AdminMetrics {
  const AdminMetrics({
    required this.tenantsTotal,
    required this.tenantsPaying,
    required this.tenantsTrial,
    required this.tenantsFree,
    required this.tenantsExpired,
    required this.tenantsUnclaimed,
    required this.mrrArs,
    required this.customersTotal,
    required this.ordersMonth,
    required this.ordersTotal,
    required this.aiMonth,
  });

  final int tenantsTotal;
  final int tenantsPaying;
  final int tenantsTrial;
  final int tenantsFree;
  final int tenantsExpired;
  final int tenantsUnclaimed;
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
      tenantsFree: num_('tenants_free'),
      tenantsExpired: num_('tenants_expired'),
      tenantsUnclaimed: num_('tenants_unclaimed'),
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
    this.zone,
    this.address,
    this.lat,
    this.lng,
    required this.plan,
    required this.planExpiresAt,
    required this.isActive,
    required this.isClaimed,
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
  final String? zone;
  final String? address;
  final double? lat;
  final double? lng;
  final PlanType plan;
  final DateTime planExpiresAt;
  final bool isActive;
  final bool isClaimed;
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
      zone: json['zone'] as String?,
      address: json['address'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      plan: PlanType.fromId(json['plan'] as String? ?? 'free'),
      planExpiresAt:
          dateOrNull('plan_expires_at') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isActive: json['is_active'] as bool? ?? false,
      isClaimed: json['is_claimed'] as bool? ?? true,
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
