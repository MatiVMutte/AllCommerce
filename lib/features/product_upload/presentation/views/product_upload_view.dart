import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/constants/categories.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:all_commerce/core/utils/app_motion.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/billing/data/repositories/ai_usage_repository.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/product_upload/data/models/ai_product_suggestion.dart';
import 'package:all_commerce/features/product_upload/data/services/ai_analyze_service.dart';
import 'package:all_commerce/features/product_upload/data/models/product_input.dart';
import 'package:all_commerce/features/product_upload/presentation/view_models/product_upload_controller.dart';
import 'package:all_commerce/features/store/presentation/view_models/owner_products_providers.dart';
import 'package:all_commerce/core/widgets/app_network_image.dart';
import 'package:all_commerce/features/product_upload/presentation/widgets/plan_blocked_card.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ProductUploadView extends ConsumerStatefulWidget {
  const ProductUploadView({
    this.existing,
    this.embedded = false,
    this.onClose,
    super.key,
  });

  /// When non-null the form edits this product instead of creating one.
  final ProductModel? existing;

  /// Renders without Scaffold/AppBar inside the master–detail pane.
  final bool embedded;

  /// Close callback for the embedded header.
  final VoidCallback? onClose;

  @override
  ConsumerState<ProductUploadView> createState() => _ProductUploadViewState();
}

class _ProductUploadViewState extends ConsumerState<ProductUploadView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _compareAtPrice = TextEditingController();
  final TextEditingController _wholesalePrice = TextEditingController();
  final TextEditingController _wholesaleMinQty = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  final TextEditingController _variants = TextEditingController();
  final TextEditingController _sku = TextEditingController();
  final TextEditingController _stock = TextEditingController(text: '0');
  bool _trackStock = false;
  final TextEditingController _category = TextEditingController();
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
      if (existing.compareAtPrice != null) {
        final double cap = existing.compareAtPrice!;
        _compareAtPrice.text = cap == cap.roundToDouble()
            ? cap.toStringAsFixed(0)
            : cap.toString();
      }
      if (existing.wholesalePrice != null) {
        final double wp = existing.wholesalePrice!;
        _wholesalePrice.text = wp == wp.roundToDouble()
            ? wp.toStringAsFixed(0)
            : wp.toString();
      }
      if (existing.wholesaleMinQty != null) {
        _wholesaleMinQty.text = existing.wholesaleMinQty.toString();
      }
      _tags.text = existing.tags.join(', ');
      _variants.text = existing.variants.join(', ');
      _sku.text = existing.sku ?? '';
      _stock.text = existing.stock.toString();
      _trackStock = existing.trackStock;
      _category.text = existing.categoryLabel;
      _categoryTouched = true;
    }
    // Manual edits clear the AI marker on the field.
    for (final TextEditingController c in <TextEditingController>[
      _title,
      _description,
      _price,
      _compareAtPrice,
      _tags,
      _sku,
    ]) {
      c.addListener(() => setState(() {}));
    }
    if (existing != null && existing.gallery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(productUploadControllerProvider.notifier)
              .initGallery(existing.gallery);
        }
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _compareAtPrice.dispose();
    _wholesalePrice.dispose();
    _wholesaleMinQty.dispose();
    _tags.dispose();
    _variants.dispose();
    _sku.dispose();
    _stock.dispose();
    _category.dispose();
    super.dispose();
  }

  /// Categories the store already uses, plus the generic enum labels —
  /// shown as quick chips under the free-form category field.
  List<String> _categorySuggestions(TenantModel tenant) {
    final List<ProductModel> products =
        ref.watch(ownerProductsProvider(tenant.id)).value ??
        const <ProductModel>[];
    final Set<String> labels = <String>{
      for (final ProductModel p in products) p.categoryLabel,
      for (final ProductCategory c in ProductCategory.values) c.label,
    };
    return labels.toList();
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
        _category.text = ProductCategory.labelOf(suggestion.category);
      });
    }
  }

  /// "IA" chip shown while the field still holds the AI-written value.
  Widget? _aiBadge(TextEditingController controller) {
    final String? filled = _aiFilled[controller];
    if (filled == null || filled.trim() != controller.text.trim()) {
      return null;
    }
    final Color primary = Theme.of(context).colorScheme.primary;
    final Widget badge = Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.auto_awesome, size: 14, color: primary),
          const SizedBox(width: 4),
          Text(
            'IA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
        ],
      ),
    );
    if (!AppMotion.enabled(context)) return badge;
    return ZoomIn(duration: const Duration(milliseconds: 300), child: badge);
  }

  Future<void> _save(TenantModel tenant) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final String sku = _sku.text.trim();
    final String compareRaw = _compareAtPrice.text.trim().replaceAll(',', '.');
    final double? compareAt = compareRaw.isEmpty
        ? null
        : double.tryParse(compareRaw);
    final String wholesaleRaw = _wholesalePrice.text.trim().replaceAll(
      ',',
      '.',
    );
    final double? wholesalePrice = wholesaleRaw.isEmpty
        ? null
        : double.tryParse(wholesaleRaw);
    final int? wholesaleMinQty = int.tryParse(_wholesaleMinQty.text.trim());
    final ProductInput input = ProductInput(
      title: _title.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      category: _category.text.trim().isEmpty
          ? ProductCategory.other.id
          : ProductCategory.storedValue(_category.text),
      tags: _tags.text
          .split(',')
          .map((String t) => t.trim().toLowerCase())
          .where((String t) => t.isNotEmpty)
          .toList(),
      price: double.parse(_price.text.trim().replaceAll(',', '.')),
      compareAtPrice: compareAt,
      wholesalePrice: wholesalePrice,
      wholesaleMinQty: wholesaleMinQty,
      variants: _variants.text
          .split(',')
          .map((String v) => v.trim())
          .where((String v) => v.isNotEmpty)
          .toList(),
      sku: sku.isEmpty ? null : sku,
      stock: _trackStock ? (int.tryParse(_stock.text.trim()) ?? 0) : 0,
      trackStock: _trackStock,
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
      AppHaptics.success();
      showAppSnackBar(
        context,
        existing == null ? AppStrings.productPublished : 'Producto actualizado',
        clearNavBar: false,
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
        final Object? err = next.error;
        showAppSnackBar(
          context,
          next.infoMessage!,
          clearNavBar: false,
          action: err is AiAnalyzeException && err.code == 'AI_LIMIT_REACHED'
              ? SnackBarAction(
                  label: 'Ver planes',
                  onPressed: () => context.push('/owner/plans'),
                )
              : null,
        );
      }
    });
    final AsyncValue<UserModel?> profileAsync = ref.watch(
      currentProfileProvider,
    );
    final ProductUploadState state = ref.watch(productUploadControllerProvider);
    final Widget body = profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stack) =>
          const Center(child: Text(AppStrings.genericError)),
      data: (UserModel? profile) {
        final String? tenantId = profile?.tenantId;
        if (tenantId == null) {
          return const Center(child: Text(AppStrings.storeNotFound));
        }
        final AsyncValue<TenantModel?> tenantAsync = ref.watch(
          tenantByIdProvider(tenantId),
        );
        return tenantAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stack) =>
              const Center(child: Text(AppStrings.genericError)),
          data: (TenantModel? tenant) {
            if (tenant == null) {
              return const Center(child: Text(AppStrings.storeNotFound));
            }
            if (!tenant.canPublish) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: PlanBlockedCard(code: 'PLAN_EXPIRED', tenant: tenant),
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
    );
    if (widget.embedded) {
      return Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.tokens.border)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.existing == null
                        ? 'Nuevo producto'
                        : 'Editar producto',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cerrar',
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),
          Expanded(child: SafeArea(top: false, child: body)),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(
          fallback: widget.existing == null ? '/owner' : '/owner/products',
        ),
        title: Text(
          widget.existing == null ? 'Nuevo producto' : 'Editar producto',
        ),
      ),
      body: body,
      bottomNavigationBar: null,
    );
  }

  Widget _buildForm(
    BuildContext context,
    TenantModel tenant,
    ProductUploadState state,
  ) {
    final bool analyzing = state.analyzing;
    return Column(
      children: <Widget>[
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _Section('FOTO'),
                      const SizedBox(height: 8),
                      _ImageSection(
                        state: state,
                        onPick: (ImageSource source) {
                          final AiUsage? usage = ref
                              .read(aiUsageProvider)
                              .value;
                          if (usage != null && usage.reached) {
                            _showAiLimit(context);
                            return;
                          }
                          ref
                              .read(productUploadControllerProvider.notifier)
                              .pickAndAnalyze(source);
                        },
                        onPickExtra: (ImageSource source) => ref
                            .read(productUploadControllerProvider.notifier)
                            .pickExtra(source),
                        onRemoveExtra: (int i) => ref
                            .read(productUploadControllerProvider.notifier)
                            .removeExtra(i),
                        onRemoveKept: (String url) => ref
                            .read(productUploadControllerProvider.notifier)
                            .removeKept(url),
                      ),
                      if (state.photoCount > 0 ||
                          state.keptImageUrls.isNotEmpty)
                        _GalleryStrip(
                          state: state,
                          onPickExtra: (ImageSource source) => ref
                              .read(productUploadControllerProvider.notifier)
                              .pickExtra(source),
                          onRemoveExtra: (int i) => ref
                              .read(productUploadControllerProvider.notifier)
                              .removeExtra(i),
                          onRemoveKept: (String url) => ref
                              .read(productUploadControllerProvider.notifier)
                              .removeKept(url),
                        ),
                      const _AiUsageLine(),
                      const SizedBox(height: 20),
                      const _Section('DATOS'),
                      const SizedBox(height: 8),
                      if (analyzing)
                        const _FieldsSkeleton()
                      else ...<Widget>[
                        TextFormField(
                          controller: _title,
                          decoration: InputDecoration(
                            labelText: AppStrings.productTitle,
                            suffixIcon: _aiBadge(_title),
                          ),
                          validator: (String? value) {
                            final int len = (value ?? '').trim().length;
                            if (len < 2 || len > 80) {
                              return 'Ingresá un título '
                                  '(2 a 80 caracteres)';
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
                      ],
                      const SizedBox(height: 20),
                      const _Section('PRECIO Y STOCK'),
                      const SizedBox(height: 8),
                      if (analyzing)
                        const _FieldsSkeleton()
                      else ...<Widget>[
                        TextFormField(
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: AppStrings.productPrice,
                            suffixIcon: _aiBadge(_price),
                          ),
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
                          controller: _compareAtPrice,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: AppStrings.productCompareAtPrice,
                            helperText: 'Si es mayor al precio actual, se muestra tachado con el % de descuento',
                          ),
                          validator: (String? value) {
                            final String raw = (value ?? '').trim().replaceAll(
                              ',',
                              '.',
                            );
                            if (raw.isEmpty) return null;
                            final double? parsed = double.tryParse(raw);
                            if (parsed == null || parsed <= 0) {
                              return 'Ingresá un precio anterior válido';
                            }
                            final double? currentPrice = double.tryParse(
                              _price.text.trim().replaceAll(',', '.'),
                            );
                            if (currentPrice != null &&
                                parsed <= currentPrice) {
                              return 'El precio anterior debe ser mayor al precio actual';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Precio mayorista (opcional)',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Si el cliente lleva la cantidad mínima o más, '
                          'se cobra el precio mayorista por unidad.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _wholesalePrice,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Precio mayorista',
                                  prefixText: '\$ ',
                                ),
                                validator: (String? value) {
                                  final String raw = (value ?? '')
                                      .trim()
                                      .replaceAll(',', '.');
                                  final bool hasQty = _wholesaleMinQty.text
                                      .trim()
                                      .isNotEmpty;
                                  if (raw.isEmpty) {
                                    return hasQty
                                        ? 'Ingresá el precio mayorista'
                                        : null;
                                  }
                                  final double? parsed = double.tryParse(raw);
                                  if (parsed == null || parsed <= 0) {
                                    return 'Precio inválido';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _wholesaleMinQty,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Desde (u.)',
                                  hintText: 'Ej: 3',
                                ),
                                validator: (String? value) {
                                  final String raw = (value ?? '').trim();
                                  final bool hasPrice = _wholesalePrice.text
                                      .trim()
                                      .isNotEmpty;
                                  if (raw.isEmpty) {
                                    return hasPrice ? 'Falta el mínimo' : null;
                                  }
                                  final int? parsed = int.tryParse(raw);
                                  if (parsed == null || parsed < 2) {
                                    return 'Mínimo 2';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _trackStock,
                          onChanged: (bool value) {
                            setState(() {
                              _trackStock = value;
                              if (value &&
                                  (int.tryParse(_stock.text.trim()) ?? 0) <=
                                      0) {
                                _stock.text = '1';
                              }
                            });
                          },
                          title: const Text('Controlar stock disponible'),
                          subtitle: const Text(
                            'Descuenta automáticamente con cada pedido y avisa cuando quedan pocas unidades',
                          ),
                        ),
                        if (_trackStock) ...<Widget>[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _stock,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: AppStrings.productStock,
                            ),
                            validator: (String? value) {
                              final int? parsed = int.tryParse(
                                (value ?? '').trim(),
                              );
                              if (parsed == null || parsed < 0) {
                                return 'Ingresá un número entero mayor o igual a 0';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                      const SizedBox(height: 20),
                      const _Section('CATEGORÍA Y ETIQUETAS'),
                      const SizedBox(height: 8),
                      if (analyzing)
                        const _FieldsSkeleton()
                      else ...<Widget>[
                        TextFormField(
                          controller: _category,
                          onChanged: (_) =>
                              setState(() => _categoryTouched = true),
                          decoration: const InputDecoration(
                            labelText: AppStrings.productCategory,
                            hintText: 'Ej: Bebidas, Limpieza, Kiosco',
                            helperText: 'Escribila o elegí una existente abajo',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            for (final String suggestion
                                in _categorySuggestions(tenant))
                              ActionChip(
                                label: Text(suggestion),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setState(() {
                                  _category.text = suggestion;
                                  _categoryTouched = true;
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _tags,
                          decoration: InputDecoration(
                            labelText: AppStrings.productTags,
                            helperText: 'Separá con comas',
                            suffixIcon: _aiBadge(_tags),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _sku,
                          decoration: InputDecoration(
                            labelText: AppStrings.productSku,
                            suffixIcon: _aiBadge(_sku),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _variants,
                          decoration: const InputDecoration(
                            labelText: 'Variantes (opcional)',
                            hintText: 'S, M, L, XL o Rojo, Negro',
                            helperText: 'Separá con comas — el cliente elige una al comprar',
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: context.tokens.surface,
              border: Border(top: BorderSide(color: context.tokens.border)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.saving || analyzing
                    ? null
                    : () => _save(tenant),
                child: state.saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.existing == null
                            ? 'Publicar producto'
                            : 'Guardar cambios',
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAiLimit(BuildContext context) {
    showAppSnackBar(
      context,
      'Llegaste al límite de análisis con IA de tu plan este '
      'mes. Podés cargar el producto a mano o mejorar tu plan.',
      clearNavBar: false,
      action: SnackBarAction(
        label: 'Ver planes',
        onPressed: () => context.push('/owner/plans'),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: context.tokens.textTertiary,
      ),
    );
  }
}

/// "IA: 12 de 60 análisis este mes" under the photo zone (warning when
/// the monthly limit is reached).
class _AiUsageLine extends ConsumerWidget {
  const _AiUsageLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AiUsage> usageAsync = ref.watch(aiUsageProvider);
    final AiUsage? usage = usageAsync.value;
    if (usage == null) return const SizedBox.shrink();
    final Color color = usage.reached
        ? context.tokens.warning
        : context.tokens.textTertiary;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        usage.limit == null
            ? 'IA: ${usage.used} análisis este mes (ilimitados)'
            : 'IA: ${usage.used} de ${usage.limit} análisis este mes',
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
  }
}

/// Shimmer placeholders for the form fields while AI is analyzing.
class _FieldsSkeleton extends StatelessWidget {
  const _FieldsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        AppSkeleton(height: 52, radius: 14),
        SizedBox(height: 16),
        AppSkeleton(height: 52, radius: 14),
      ],
    );
  }
}

class _ImageSection extends StatelessWidget {
  const _ImageSection({
    required this.state,
    required this.onPick,
    required this.onPickExtra,
    required this.onRemoveExtra,
    required this.onRemoveKept,
  });

  final ProductUploadState state;
  final void Function(ImageSource source) onPick;
  final void Function(ImageSource source) onPickExtra;
  final void Function(int index) onRemoveExtra;
  final void Function(String url) onRemoveKept;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Uint8List? bytes = state.imageBytes;
    final String? coverUrl = bytes == null && state.keptImageUrls.isNotEmpty
        ? state.keptImageUrls.first
        : null;
    final bool hasImage = bytes != null || coverUrl != null;

    if (!hasImage) {
      return Column(
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onPick(ImageSource.gallery),
            child: Container(
              decoration: BoxDecoration(
                color: tokens.surfaceMuted,
                border: Border.all(color: tokens.border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.photo_camera_outlined,
                        size: 40,
                        color: tokens.textTertiary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tocá para elegir una foto',
                        style: TextStyle(color: tokens.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!kIsWeb) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text(AppStrings.takePhoto),
                onPressed: () => onPick(ImageSource.camera),
              ),
            ),
          ],
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (bytes != null)
              Image.memory(bytes, fit: BoxFit.cover)
            else
              AppNetworkImage(
                imageUrl: coverUrl!,
                placeholder: Container(color: tokens.surfaceMuted),
                errorBuilder: (_) => Container(
                  color: tokens.surfaceMuted,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 48,
                    color: tokens.textTertiary,
                  ),
                ),
              ),
            if (state.analyzing)
              FadeIn(
                duration: const Duration(milliseconds: 180),
                child: Container(
                  color: tokens.overlay.withValues(alpha: 0.45),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        AppMotion.loopsEnabled(context)
                            ? Pulse(
                                infinite: true,
                                duration: const Duration(milliseconds: 1200),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              )
                            : const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 28,
                              ),
                        const SizedBox(height: 10),
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 8),
                        const Text(
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
              top: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: tokens.overlay.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => onPick(ImageSource.gallery),
                  child: const Text('Cambiar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thumbnails of every photo in the final gallery order (kept then new
/// extras), each with a remove button, plus a "+" tile up to the cap.
class _GalleryStrip extends StatelessWidget {
  const _GalleryStrip({
    required this.state,
    required this.onPickExtra,
    required this.onRemoveExtra,
    required this.onRemoveKept,
  });

  final ProductUploadState state;
  final void Function(ImageSource source) onPickExtra;
  final void Function(int index) onRemoveExtra;
  final void Function(String url) onRemoveKept;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    // Skip the first kept URL from the strip when it IS the cover shown
    // above (no freshly picked main photo).
    final int keptOffset = state.imageBytes == null ? 1 : 0;
    final List<Widget> tiles = <Widget>[
      for (int i = keptOffset; i < state.keptImageUrls.length; i++)
        _Thumb(
          child: AppNetworkImage(
            imageUrl: state.keptImageUrls[i],
            errorBuilder: (_) => Container(
              color: context.tokens.surfaceMuted,
              child: const Icon(Icons.broken_image_outlined, size: 20),
            ),
          ),
          onRemove: () => onRemoveKept(state.keptImageUrls[i]),
        ),
      for (int i = 0; i < state.extraImageBytes.length; i++)
        _Thumb(
          child: Image.memory(state.extraImageBytes[i], fit: BoxFit.cover),
          onRemove: () => onRemoveExtra(i),
        ),
      if (state.photoCount < ProductUploadState.maxPhotos)
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onPickExtra(ImageSource.gallery),
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: tokens.surfaceMuted,
              border: Border.all(color: tokens.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.add_photo_alternate_outlined,
              color: tokens.textSecondary,
            ),
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 10),
        SizedBox(
          height: 76,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              for (final Widget t in tiles)
                Padding(padding: const EdgeInsets.only(right: 8), child: t),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Podés agregar hasta ${ProductUploadState.maxPhotos} fotos',
          style: TextStyle(fontSize: 12, color: tokens.textTertiary),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ClipRRect(borderRadius: BorderRadius.circular(14), child: child),
          Positioned(
            right: 2,
            top: 2,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
