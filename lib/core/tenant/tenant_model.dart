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
    required this.whatsapp,
    this.logoUrl,
    required this.primaryColor,
    required this.plan,
    required this.trialStartedAt,
    required this.planExpiresAt,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String slug;
  final String name;
  final String? description;
  final String? address;
  final String whatsapp;
  final String? logoUrl;

  /// Hex color string, e.g. '#0052FF'.
  final String primaryColor;
  final PlanType plan;
  final DateTime trialStartedAt;
  final DateTime planExpiresAt;
  final bool isActive;
  final DateTime createdAt;

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      whatsapp: json['whatsapp'] as String,
      logoUrl: json['logo_url'] as String?,
      primaryColor: json['primary_color'] as String,
      plan: PlanType.fromId(json['plan'] as String),
      trialStartedAt: DateTime.parse(json['trial_started_at'] as String),
      planExpiresAt: DateTime.parse(json['plan_expires_at'] as String),
      isActive: json['is_active'] as bool,
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
      'whatsapp': whatsapp,
      'logo_url': logoUrl,
      'primary_color': primaryColor,
      'plan': plan.id,
      'trial_started_at': trialStartedAt.toIso8601String(),
      'plan_expires_at': planExpiresAt.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get canPublish => isActive && planExpiresAt.isAfter(DateTime.now());

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
    String? whatsapp,
    String? logoUrl,
    String? primaryColor,
    PlanType? plan,
    DateTime? trialStartedAt,
    DateTime? planExpiresAt,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return TenantModel(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      whatsapp: whatsapp ?? this.whatsapp,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      plan: plan ?? this.plan,
      trialStartedAt: trialStartedAt ?? this.trialStartedAt,
      planExpiresAt: planExpiresAt ?? this.planExpiresAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
