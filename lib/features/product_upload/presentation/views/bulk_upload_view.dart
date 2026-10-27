

import 'package:all_commerce/core/constants/categories.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:all_commerce/features/product_upload/data/models/bulk_product_draft.dart';
import 'package:all_commerce/features/product_upload/presentation/view_models/bulk_upload_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BulkUploadView extends ConsumerStatefulWidget {
  const BulkUploadView({super.key});

  @override
  ConsumerState<BulkUploadView> createState() => _BulkUploadViewState();
}

class _BulkUploadViewState extends ConsumerState<BulkUploadView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bulkUploadControllerProvider.notifier).clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final BulkUploadState state = ref.watch(bulkUploadControllerProvider);
    final bool hasDrafts = state.drafts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/owner/products'),
        title: const Text('Carga masiva'),
        actions: <Widget>[
          if (hasDrafts)
            IconButton(
              tooltip: 'Borrar todo',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClear(context),
            ),
        ],
      ),
      body: SafeArea(
        child: hasDrafts
            ? _DraftsList(state: state)
            : _EmptyPicker(
                onPick: () => _pickImages(),
              ),
      ),
      bottomNavigationBar: !hasDrafts
          ? null
          : _BottomBar(
              state: state,
              onPublish: _publish,
            ),
    );
  }

  Future<void> _pickImages() async {
    try {
      await ref.read(bulkUploadControllerProvider.notifier).pickAndAnalyze();
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'No se pudieron procesar las fotos');
    }
  }

  Future<void> _publish() async {
    final int published = await ref.read(bulkUploadControllerProvider.notifier).publishAll();
    if (published > 0) {
      if (!mounted) return;
      showAppSnackBar(context, 'Se publicaron $published productos');
      if (!mounted) return;
      context.go('/owner/products');
    } else {
      if (!mounted) return;
      showAppSnackBar(context, 'No se pudo publicar ningún producto');
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final bool? clear = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('¿Borrar todos los borradores?'),
        content: const Text('Se perderán las fotos y lo que la IA escribió.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (clear == true) {
      ref.read(bulkUploadControllerProvider.notifier).clear();
    }
  }
}

class _EmptyPicker extends StatelessWidget {
  const _EmptyPicker({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.layers_outlined, size: 64, color: tokens.textTertiary),
            const SizedBox(height: 20),
            Text(
              'Subí hasta $kBulkUploadLimit fotos',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'La IA va a armar un producto por foto. Después revisás, '
              'editás si querés y publicás todo junto.',
              style: TextStyle(color: tokens.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Elegir fotos'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftsList extends StatelessWidget {
  const _DraftsList({required this.state});

  final BulkUploadState state;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, FloatingNavBar.height + 80),
      itemCount: state.drafts.length,
      itemBuilder: (BuildContext context, int index) {
        return _DraftCard(
          index: index,
          draft: state.drafts[index],
          analyzing: state.analyzing,
          publishing: state.publishing,
        );
      },
    );
  }
}

class _DraftCard extends ConsumerStatefulWidget {
  const _DraftCard({
    required this.index,
    required this.draft,
    required this.analyzing,
    required this.publishing,
  });

  final int index;
  final BulkProductDraft draft;
  final bool analyzing;
  final bool publishing;

  @override
  ConsumerState<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends ConsumerState<_DraftCard> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _compareAtPrice;
  late final TextEditingController _sku;
  late final TextEditingController _stock;
  late final TextEditingController _tags;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.draft.title);
    _description = TextEditingController(text: widget.draft.description ?? '');
    _price = TextEditingController(
      text: widget.draft.price?.toStringAsFixed(0) ?? '',
    );
    _compareAtPrice = TextEditingController(
      text: widget.draft.compareAtPrice?.toStringAsFixed(0) ?? '',
    );
    _sku = TextEditingController(text: widget.draft.sku ?? '');
    _stock = TextEditingController(text: widget.draft.stock.toString());
    _tags = TextEditingController(text: widget.draft.tags.join(', '));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _compareAtPrice.dispose();
    _sku.dispose();
    _stock.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _DraftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final BulkProductDraft draft = widget.draft;
    _title.text = draft.title;
    _description.text = draft.description ?? '';
    _price.text = draft.price?.toStringAsFixed(0) ?? '';
    _compareAtPrice.text = draft.compareAtPrice?.toStringAsFixed(0) ?? '';
    _sku.text = draft.sku ?? '';
    _stock.text = draft.stock.toString();
    _tags.text = draft.tags.join(', ');
  }

  void _commit() {
    final double? price = double.tryParse(_price.text.replaceAll('.', '').replaceAll(',', '.'));
    final double? compareAtPrice = double.tryParse(
      _compareAtPrice.text.replaceAll('.', '').replaceAll(',', '.'),
    );
    final int? stock = int.tryParse(_stock.text);
    final controller = ref.read(bulkUploadControllerProvider.notifier);
    controller.updateDraft(
      widget.index,
      widget.draft.copyWith(
        title: _title.text,
        description: _description.text.isEmpty ? null : _description.text,
        price: price,
        compareAtPrice: compareAtPrice,
        sku: _sku.text.isEmpty ? null : _sku.text,
        stock: stock ?? 0,
        tags: _tags.text
            .split(',')
            .map((String s) => s.trim())
            .where((String s) => s.isNotEmpty)
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final BulkProductDraft draft = widget.draft;
    final bool isAnalyzing = draft.analyzing;
    final bool hasError = draft.error != null;
    final bool isValid = draft.isValid;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    draft.imageBytes,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (isAnalyzing) ...<Widget>[
                        const AppSkeleton(width: double.infinity, height: 14, radius: 8),
                        const SizedBox(height: 8),
                        const AppSkeleton(width: 120, height: 14, radius: 8),
                        const SizedBox(height: 8),
                        const AppSkeleton(width: 80, height: 14, radius: 8),
                      ] else if (hasError) ...<Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.error_outline, color: tokens.danger, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                draft.error!,
                                style: TextStyle(color: tokens.danger, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: widget.analyzing
                              ? null
                              : () => ref.read(bulkUploadControllerProvider.notifier).retryAnalysis(widget.index),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Reintentar IA'),
                        ),
                      ] else ...<Widget>[
                        _Field(
                          label: 'Nombre',
                          controller: _title,
                          onChanged: (_) => _commit(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _Field(
                                label: 'Precio',
                                controller: _price,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => _commit(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _Field(
                                label: 'Precio ant. (opc)',
                                controller: _compareAtPrice,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => _commit(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  icon: Icon(Icons.delete_outline, color: tokens.danger),
                  onPressed: widget.publishing
                      ? null
                      : () => ref.read(bulkUploadControllerProvider.notifier).removeDraft(widget.index),
                ),
              ],
            ),
            if (!isAnalyzing && !hasError) ...<Widget>[
              const SizedBox(height: 12),
              _Field(
                label: 'Descripción',
                controller: _description,
                maxLines: 2,
                onChanged: (_) => _commit(),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _CategoryDropdown(
                      value: ProductCategory.fromId(draft.category),
                      onChanged: (ProductCategory? value) {
                        if (value != null) {
                          _commit();
                          ref.read(bulkUploadControllerProvider.notifier).updateDraft(
                                widget.index,
                                draft.copyWith(category: value.id),
                              );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      label: 'Stock',
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _commit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Etiquetas (separadas por coma)',
                controller: _tags,
                onChanged: (_) => _commit(),
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'SKU (opcional)',
                controller: _sku,
                onChanged: (_) => _commit(),
              ),
            ],
            if (isValid && draft.analyzed && !hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.check_circle_outline, color: tokens.success, size: 16),
                    const SizedBox(width: 6),
                    Text('Listo para publicar', style: TextStyle(color: tokens.success, fontSize: 12)),
                  ],
                ),
              ),
            if (draft.publishing)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onChanged: onChanged,
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({required this.value, required this.onChanged});

  final ProductCategory value;
  final ValueChanged<ProductCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ProductCategory>(
      initialValue: value,
      isDense: true,
      decoration: InputDecoration(
        labelText: 'Categoría',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: ProductCategory.values
          .map((ProductCategory c) => DropdownMenuItem<ProductCategory>(
                value: c,
                child: Text(c.label),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state, required this.onPublish});

  final BulkUploadState state;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final int ready = state.publishableCount;
    final String progress = state.drafts.isEmpty
        ? ''
        : '${state.analyzedCount}/${state.drafts.length} analizados';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (progress.isNotEmpty)
              Text(
                progress,
                style: TextStyle(color: tokens.textSecondary, fontSize: 13),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.analyzing || state.publishing || ready == 0
                    ? null
                    : () {
                        AppHaptics.medium();
                        onPublish();
                      },
                child: state.publishing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Publicar $ready productos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
