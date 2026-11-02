import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_theme.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/widgets/app_network_image.dart';
import 'package:all_commerce/core/widgets/quantity_stepper.dart';
import 'package:all_commerce/features/cart/presentation/widgets/add_to_cart.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom sheet to add a product that needs a choice first (variant and/or
/// fractional quantity) straight from the catalog grid, without opening the
/// product page.
Future<void> showQuickAddSheet(
  BuildContext context,
  ProductModel product,
  TenantModel tenant,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => TenantTheme(
      brandColor: tenant.primaryColorValue,
      child: _QuickAddSheet(product: product, tenant: tenant),
    ),
  );
}

class _QuickAddSheet extends ConsumerStatefulWidget {
  const _QuickAddSheet({required this.product, required this.tenant});

  final ProductModel product;
  final TenantModel tenant;

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet> {
  String? _variant;
  late double _qty = _step;

  double get _step => widget.product.isFractional ? 0.25 : 1;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ProductModel p = widget.product;
    final bool needsVariant = p.hasVariants && _variant == null;
    final double unitPrice = p.unitPriceFor(_qty);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: p.imageUrl == null
                        ? ColoredBox(
                            color: tokens.surfaceMuted,
                            child: Icon(
                              Icons.image_outlined,
                              color: tokens.textTertiary,
                            ),
                          )
                        : AppNetworkImage(
                            imageUrl: p.imageUrl!,
                            placeholder: ColoredBox(color: tokens.surfaceMuted),
                            errorBuilder: (_) =>
                                ColoredBox(color: tokens.surfaceMuted),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.isFractional
                            ? '${Formatters.price(p.price)} / '
                                  '${Formatters.qtyLabel(1, p.unit)}'
                            : Formatters.price(p.price),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (p.hasVariants) ...<Widget>[
              const SizedBox(height: 24),
              Text(
                'Elegí una opción',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final String v in p.variants)
                    ChoiceChip(
                      label: Text(v),
                      selected: _variant == v,
                      onSelected: (_) => setState(() => _variant = v),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Cantidad',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                QuantityStepper(
                  quantity: _qty,
                  step: _step,
                  unit: p.unit,
                  maxQuantity: p.trackStock ? p.stock : null,
                  onChanged: (double q) {
                    if (q < _step) return;
                    setState(() => _qty = q);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: needsVariant
                  ? null
                  : () async {
                      final NavigatorState nav = Navigator.of(context);
                      await addToCartWithConfirm(
                        context,
                        ref,
                        p,
                        widget.tenant,
                        quantity: _qty,
                        variant: _variant,
                      );
                      if (nav.mounted) nav.pop();
                    },
              child: Text(
                needsVariant
                    ? 'Elegí una opción'
                    : 'Agregar · ${Formatters.price(unitPrice * _qty)}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
