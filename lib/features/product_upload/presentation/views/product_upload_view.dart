import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/constants/categories.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/product_upload/data/models/ai_product_suggestion.dart';
import 'package:all_commerce/features/product_upload/data/models/product_input.dart';
import 'package:all_commerce/features/product_upload/presentation/view_models/product_upload_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:all_commerce/features/product_upload/presentation/widgets/plan_blocked_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ProductUploadView extends ConsumerStatefulWidget {
  const ProductUploadView({this.existing, super.key});

  /// When non-null the form edits this product instead of creating one.
  final ProductModel? existing;

  @override
  ConsumerState<ProductUploadView> createState() =>
      _ProductUploadViewState();
}

class _ProductUploadViewState extends ConsumerState<ProductUploadView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  final TextEditingController _sku = TextEditingController();
  final TextEditingController _stock = TextEditingController(text: '0');
  ProductCategory _category = ProductCategory.other;
  bool _categoryTouched = false;

  @override
  void initState() {
    super.initState();
    final ProductModel? existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title;
      _description.text = existing.description ?? '';
      _price.text = existing.price == existing.price.roundToDouble()
          ? existing.price.toStringAsFixed(0)
          : existing.price.toString();
      _tags.text = existing.tags.join(', ');
      _sku.text = existing.sku ?? '';
      _stock.text = existing.stock.toString();
      _category = existing.categoryEnum;
      _categoryTouched = true;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _tags.dispose();
    _sku.dispose();
    _stock.dispose();
    super.dispose();
  }

  /// Values written by the last AI suggestion, used to tell AI-filled fields
  /// (safe to overwrite on a new photo) from user-edited ones (kept).
  final Map<TextEditingController, String> _aiFilled =
      <TextEditingController, String>{};

  void _fill(TextEditingController controller, String? value) {
    if (value == null || value.isEmpty) return;
    final String current = controller.text.trim();
    final bool untouched =
        current.isEmpty || current == _aiFilled[controller]?.trim();
    if (!untouched) return;
    controller.text = value;
    _aiFilled[controller] = value;
  }

  void _applySuggestion(AiProductSuggestion suggestion) {
    _fill(_title, suggestion.title);
    _fill(_description, suggestion.description);
    _fill(_price, suggestion.suggestedPriceArs?.toStringAsFixed(0));
    _fill(_tags, suggestion.tags.join(', '));
    _fill(_sku, suggestion.sku);
    if (!_categoryTouched) {
      setState(() {
        _category = ProductCategory.fromId(suggestion.category);
      });
    }
  }

  Future<void> _save(TenantModel tenant) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final String sku = _sku.text.trim();
    final ProductInput input = ProductInput(
      title: _title.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      category: _category.id,
      tags: _tags.text
          .split(',')
          .map((String t) => t.trim().toLowerCase())
          .where((String t) => t.isNotEmpty)
          .toList(),
      price: double.parse(_price.text.trim().replaceAll(',', '.')),
      sku: sku.isEmpty ? null : sku,
      stock: int.tryParse(_stock.text.trim()) ?? 0,
    );
    final ProductModel? existing = widget.existing;
    final ProductModel? product = existing == null
        ? await ref
            .read(productUploadControllerProvider.notifier)
            .save(input, tenant.id)
        : await ref
            .read(productUploadControllerProvider.notifier)
            .update(existing, input);
    if (!mounted) return;
    if (product != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? AppStrings.productPublished
                : 'Producto actualizado',
          ),
        ),
      );
      context.go('/owner/products');
      return;
    }
    final ProductUploadState state = ref.read(productUploadControllerProvider);
    if (state.blockedCode == null && state.error != null) {
      showErrorSnackBar(context, state.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(productUploadControllerProvider, (
      ProductUploadState? previous,
      ProductUploadState next,
    ) {
      final AiProductSuggestion? suggestion = next.suggestion;
      if (suggestion != null && suggestion != previous?.suggestion) {
        _applySuggestion(suggestion);
      }
      if (next.infoMessage != null &&
          next.infoMessage != previous?.infoMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.infoMessage!)),
        );
      }
    });
    final AsyncValue<UserModel?> profileAsync =
        ref.watch(currentProfileProvider);
    final ProductUploadState state =
        ref.watch(productUploadControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(
          fallback: widget.existing == null
              ? '/owner'
              : '/owner/products',
        ),
        title: Text(
          widget.existing == null
              ? AppStrings.uploadProduct
              : 'Editar producto',
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            const Center(child: Text(AppStrings.genericError)),
        data: (UserModel? profile) {
          final String? tenantId = profile?.tenantId;
          if (tenantId == null) {
            return const Center(child: Text(AppStrings.storeNotFound));
          }
          final AsyncValue<TenantModel?> tenantAsync =
              ref.watch(tenantByIdProvider(tenantId));
          return tenantAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stack) =>
                const Center(child: Text(AppStrings.genericError)),
            data: (TenantModel? tenant) {
              if (tenant == null) {
                return const Center(
                  child: Text(AppStrings.storeNotFound),
                );
              }
              if (!tenant.canPublish) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: PlanBlockedCard(
                      code: 'PLAN_EXPIRED',
                      tenant: tenant,
                    ),
                  ),
                );
              }
              final String? blocked = state.blockedCode;
              if (blocked != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: PlanBlockedCard(code: blocked, tenant: tenant),
                  ),
                );
              }
              return _buildForm(context, tenant, state);
            },
          );
        },
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    TenantModel tenant,
    ProductUploadState state,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _ImageSection(
                  state: state,
                  existingImageUrl: widget.existing?.imageUrl,
                  onPick: (ImageSource source) => ref
                      .read(productUploadControllerProvider.notifier)
                      .pickAndAnalyze(source),
                ),
                if (state.suggestion != null) ...<Widget>[
                  const SizedBox(height: 12),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.auto_awesome, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(AppStrings.aiSuggestionBanner),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  decoration:
                      const InputDecoration(labelText: AppStrings.productTitle),
                  validator: (String? value) {
                    final int len = (value ?? '').trim().length;
                    if (len < 2 || len > 80) {
                      return 'Ingresá un título (2 a 80 caracteres)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: AppStrings.productDescription,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ProductCategory>(
                  key: ValueKey<ProductCategory>(_category),
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: AppStrings.productCategory,
                  ),
                  items: ProductCategory.values
                      .map(
                        (ProductCategory c) => DropdownMenuItem<
                            ProductCategory>(
                          value: c,
                          child: Text(c.label),
                        ),
                      )
                      .toList(),
                  onChanged: (ProductCategory? value) {
                    if (value == null) return;
                    setState(() {
                      _category = value;
                      _categoryTouched = true;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: AppStrings.productPrice),
                  validator: (String? value) {
                    final double? parsed = double.tryParse(
                      (value ?? '').trim().replaceAll(',', '.'),
                    );
                    if (parsed == null || parsed <= 0) {
                      return 'Ingresá un precio válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tags,
                  decoration: const InputDecoration(
                    labelText: AppStrings.productTags,
                    helperText: 'Separá con comas',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sku,
                  decoration:
                      const InputDecoration(labelText: AppStrings.productSku),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _stock,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: AppStrings.productStock),
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) return null;
                    if (int.tryParse(value!.trim()) == null) {
                      return 'Ingresá un número entero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed:
                      state.saving ? null : () => _save(tenant),
                  child: state.saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.existing == null
                              ? AppStrings.publishProduct
                              : 'Guardar cambios',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageSection extends StatelessWidget {
  const _ImageSection({
    required this.state,
    required this.onPick,
    this.existingImageUrl,
  });

  final ProductUploadState state;
  final void Function(ImageSource source) onPick;
  final String? existingImageUrl;

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = state.imageBytes;
    if (bytes == null && existingImageUrl != null) {
      return Stack(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1,
              child: CachedNetworkImage(
                imageUrl: existingImageUrl!,
                fit: BoxFit.cover,
                errorWidget: (BuildContext context, String url, _) =>
                    const Icon(Icons.image_not_supported_outlined, size: 48),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: FilledButton.tonal(
              onPressed: () => onPick(ImageSource.gallery),
              child: const Text(AppStrings.changePhoto),
            ),
          ),
        ],
      );
    }
    if (bytes == null) {
      return Column(
        children: <Widget>[
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(Icons.add_photo_alternate_outlined, size: 48),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              if (!kIsWeb)
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text(AppStrings.takePhoto),
                    onPressed: () => onPick(ImageSource.camera),
                  ),
                ),
              if (!kIsWeb) const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text(AppStrings.chooseFromGallery),
                  onPressed: () => onPick(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return Stack(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        ),
        if (state.analyzing)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      AppStrings.analyzingWithAi,
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          right: 8,
          bottom: 8,
          child: FilledButton.tonal(
            onPressed: () => onPick(ImageSource.gallery),
            child: const Text(AppStrings.changePhoto),
          ),
        ),
      ],
    );
  }
}
