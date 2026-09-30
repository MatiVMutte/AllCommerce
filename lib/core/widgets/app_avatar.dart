import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Store avatar: logo image or initial over the store's brand color.
class AppAvatar extends StatelessWidget {
  const AppAvatar({required this.tenant, this.size = 48, super.key});

  final TenantModel tenant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Text(
      tenant.name.characters.first.toUpperCase(),
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.45,
        fontWeight: FontWeight.w700,
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tenant.primaryColorValue,
        borderRadius: BorderRadius.circular(size * 0.33),
      ),
      clipBehavior: Clip.antiAlias,
      child: tenant.logoUrl == null
          ? Center(child: fallback)
          : CachedNetworkImage(
              imageUrl: tenant.logoUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Center(child: fallback),
            ),
    );
  }
}
