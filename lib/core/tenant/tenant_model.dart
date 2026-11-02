import 'package:all_commerce/core/constants/app_colors.dart';
import 'package:all_commerce/core/constants/plans.dart';
import 'package:flutter/material.dart';

class TenantModel {
  const TenantModel({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.address,
    this.zone,
    this.lat,
    this.lng,
    required this.whatsapp,
    this.logoUrl,
    this.coverUrl,
    required this.primaryColor,
    this.transferAlias,
    this.mercadoPagoLink,
    this.acceptsCard = false,
    this.acceptsCash = true,
    this.isOpen = true,
    this.openingHours,
    this.isPublic = true,
    this.cashDiscountPct = 0,
    this.transferDiscountPct = 0,
    this.mpDiscountPct = 0,
    this.bulkDiscountPct = 0,
    this.bulkDiscountMin = 0,
    required this.plan,
    required this.trialStartedAt,
    required this.planExpiresAt,
    required this.isActive,
    required this.isClaimed,
    required this.createdAt,
  });

  final String id;
  final String slug;
  final String name;
  final String? description;
  final String? address;
  final String? zone;
  final double? lat;
  final double? lng;
  final String whatsapp;
  final String? logoUrl;

  /// Optional wide banner shown on the catalog header and store card.
  final String? coverUrl;

  /// Hex color string, e.g. '#0052FF'.
  final String primaryColor;
  final String? transferAlias;
  final String? mercadoPagoLink;

  /// Whether the store takes credit/debit cards (directory filter).
  final bool acceptsCard;
  final bool acceptsCash;
  final bool isOpen;
  final String? openingHours;

  /// Whether the store is listed in the public directory. Direct links and
  /// QR codes keep working either way.
  final bool isPublic;

  /// Optional % discount the store gives for each payment method.
  final double cashDiscountPct;
  final double transferDiscountPct;
  final double mpDiscountPct;

  /// % discount applied when the subtotal reaches [bulkDiscountMin].
  final double bulkDiscountPct;
  final double bulkDiscountMin;

  /// Discount % for a given payment method id ('cash'|'transfer'|'mercado_pago').
  double paymentDiscountPct(String paymentMethodId) {
    switch (paymentMethodId) {
      case 'cash':
        return cashDiscountPct;
      case 'transfer':
        return transferDiscountPct;
      default:
        return mpDiscountPct;
    }
  }

  /// Volume discount amount for a given subtotal (0 when not reached).
  double bulkDiscountFor(double subtotal) =>
      bulkDiscountPct > 0 && subtotal >= bulkDiscountMin
      ? subtotal * bulkDiscountPct.clamp(0, 100) / 100
      : 0;

  /// Payment-method discount amount for a given subtotal.
  double paymentDiscountFor(double subtotal, String paymentMethodId) {
    final double pct = paymentDiscountPct(paymentMethodId);
    return pct > 0 ? subtotal * pct.clamp(0, 100) / 100 : 0;
  }

  final PlanType plan;
  final DateTime trialStartedAt;
  final DateTime planExpiresAt;
  final bool isActive;
  final bool isClaimed;
  final DateTime createdAt;

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      zone: json['zone'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      whatsapp: json['whatsapp'] as String,
      logoUrl: json['logo_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      primaryColor: json['primary_color'] as String,
      transferAlias: json['transfer_alias'] as String?,
      mercadoPagoLink: json['mercado_pago_link'] as String?,
      acceptsCard: json['accepts_card'] as bool? ?? false,
      acceptsCash: json['accepts_cash'] as bool? ?? true,
      isOpen: json['is_open'] as bool? ?? true,
      openingHours: json['opening_hours'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      cashDiscountPct: (json['cash_discount_pct'] as num?)?.toDouble() ?? 0,
      transferDiscountPct:
          (json['transfer_discount_pct'] as num?)?.toDouble() ?? 0,
      mpDiscountPct: (json['mp_discount_pct'] as num?)?.toDouble() ?? 0,
      bulkDiscountPct: (json['bulk_discount_pct'] as num?)?.toDouble() ?? 0,
      bulkDiscountMin: (json['bulk_discount_min'] as num?)?.toDouble() ?? 0,
      plan: PlanType.fromId(json['plan'] as String),
      trialStartedAt: json['trial_started_at'] == null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.parse(json['trial_started_at'] as String),
      planExpiresAt: DateTime.parse(json['plan_expires_at'] as String),
      isActive: json['is_active'] as bool,
      isClaimed: json['is_claimed'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'slug': slug,
      'name': name,
      'description': description,
      'address': address,
      'zone': zone,
      'lat': lat,
      'lng': lng,
      'whatsapp': whatsapp,
      'logo_url': logoUrl,
      'cover_url': coverUrl,
      'primary_color': primaryColor,
      'transfer_alias': transferAlias,
      'mercado_pago_link': mercadoPagoLink,
      'accepts_card': acceptsCard,
      'accepts_cash': acceptsCash,
      'is_open': isOpen,
      'opening_hours': openingHours,
      'is_public': isPublic,
      'cash_discount_pct': cashDiscountPct,
      'transfer_discount_pct': transferDiscountPct,
      'mp_discount_pct': mpDiscountPct,
      'bulk_discount_pct': bulkDiscountPct,
      'bulk_discount_min': bulkDiscountMin,
      'plan': plan.id,
      'trial_started_at': trialStartedAt.toIso8601String(),
      'plan_expires_at': planExpiresAt.toIso8601String(),
      'is_active': isActive,
      'is_claimed': isClaimed,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Free-plan tenants can publish forever; paid tenants need an active subscription.
  bool get canPublish =>
      isActive &&
      (plan == PlanType.free || planExpiresAt.isAfter(DateTime.now()));

  /// Whether the local has been claimed by its owner. Pre-registered leads are not.
  bool get isUnclaimedLead => isActive && !isClaimed;

  int get daysLeft {
    final int days = planExpiresAt.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  Color get primaryColorValue {
    final String hex = primaryColor.replaceFirst('#', '');
    final int? value = int.tryParse(hex, radix: 16);
    if (value == null || hex.length != 6) return AppColors.primary;
    return Color(0xFF000000 | value);
  }

  TenantModel copyWith({
    String? id,
    String? slug,
    String? name,
    String? description,
    String? address,
    String? zone,
    double? lat,
    double? lng,
    String? whatsapp,
    String? logoUrl,
    String? primaryColor,
    String? transferAlias,
    String? mercadoPagoLink,
    bool? acceptsCard,
    bool? acceptsCash,
    bool? isOpen,
    String? openingHours,
    PlanType? plan,
    DateTime? trialStartedAt,
    DateTime? planExpiresAt,
    bool? isActive,
    bool? isClaimed,
    DateTime? createdAt,
  }) {
    return TenantModel(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      zone: zone ?? this.zone,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      whatsapp: whatsapp ?? this.whatsapp,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      transferAlias: transferAlias ?? this.transferAlias,
      mercadoPagoLink: mercadoPagoLink ?? this.mercadoPagoLink,
      acceptsCard: acceptsCard ?? this.acceptsCard,
      acceptsCash: acceptsCash ?? this.acceptsCash,
      isOpen: isOpen ?? this.isOpen,
      openingHours: openingHours ?? this.openingHours,
      plan: plan ?? this.plan,
      trialStartedAt: trialStartedAt ?? this.trialStartedAt,
      planExpiresAt: planExpiresAt ?? this.planExpiresAt,
      isActive: isActive ?? this.isActive,
      isClaimed: isClaimed ?? this.isClaimed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
