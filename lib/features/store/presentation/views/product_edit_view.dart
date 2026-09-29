import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/product_upload/presentation/views/product_upload_view.dart';
import 'package:all_commerce/features/store/presentation/view_models/owner_products_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Resolves the product (deep-link safe) then renders the upload form
/// in edit mode.
class ProductEditView extends ConsumerWidget {
  const ProductEditView({required this.product, required this.productId, super.key});

  /// Product passed via `state.extra`; may be null on deep links.
  final ProductModel? product;
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProductModel? direct = product;
    if (direct != null) return ProductUploadView(existing: direct);
    final AsyncValue<ProductModel?> async =
        ref.watch(ownerProductProvider(productId));
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stack) => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallback: '/owner/products'),
          title: const Text('Editar producto'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(AppStrings.genericError),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(ownerProductProvider(productId)),
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      ),
      data: (ProductModel? resolved) {
        if (resolved == null) {
          return Scaffold(
            appBar: AppBar(
              leading:
                  const AppBackButton(fallback: '/owner/products'),
              title: const Text('Editar producto'),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(AppStrings.productNotFound),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/owner/products'),
                    child: const Text('Volver a mis productos'),
                  ),
                ],
              ),
            ),
          );
        }
        return ProductUploadView(existing: resolved);
      },
    );
  }
}
