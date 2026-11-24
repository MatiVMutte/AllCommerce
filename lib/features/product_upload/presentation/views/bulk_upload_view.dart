import 'package:all_commerce/core/constants/categories.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:all_commerce/features/product_upload/data/models/bulk_product_draft.dart';
import 'package:all_commerce/features/product_upload/presentation/view_models/bulk_upload_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _BulkFilter { all, attention, ready }

class BulkUploadView extends ConsumerStatefulWidget {
  const BulkUploadView({super.key});

  @override
  ConsumerState<BulkUploadView> createState() => _BulkUploadViewState();
}

class _BulkUploadViewState extends ConsumerState<BulkUploadView> {
  _BulkFilter _filter = _BulkFilter.all;
  String? _highlightedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bulkUploadControllerProvider.notifier).clear();
    });
  }

  void _focusDraft(String draftId) {
    setState(() {
      _filter = _BulkFilter.all;
      _highlightedId = draftId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? targetContext = GlobalObjectKey(draftId)
          .currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: 0.12,
        );
      }
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
              onPressed: state.publishing ? null : () => _confirmClear(context),
            ),
        ],
      ),
      body: SafeArea(
        child: hasDrafts
            ? Column(
                children: <Widget>[
                  _BulkStatusHeader(
                    state: state,
                    filter: _filter,
                    highlightedId: _highlightedId,
                    onFilterChanged: (_BulkFilter next) =>
                        setState(() => _filter = next),
                    onTapThumbnail: _focusDraft,
                  ),
                  Expanded(
                    child: _DraftsList(
                      state: state,
                      filter: _filter,
                      highlightedId: _highlightedId,
                    ),
                  ),
                ],
              )
            : _EmptyPicker(onPick: _pickImages),
      ),
      bottomNavigationBar: !hasDrafts
          ? null
          : _BottomBar(state: state, onPublish: _publish),
    );
  }

  Future<void> _pickImages() async {
    try {
      setState(() {
        _filter = _BulkFilter.all;
        _highlightedId = null;
      });
      await ref.read(bulkUploadControllerProvider.notifier).pickAndAnalyze();
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudieron procesar las fotos');
      }
    }
  }

  Future<void> _publish() async {
    final int published = await ref
        .read(bulkUploadControllerProvider.notifier)
        .publishAll();
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

class _BulkStatusHeader extends ConsumerWidget {
  const _BulkStatusHeader({
    required this.state,
    required this.filter,
    required this.highlightedId,
    required this.onFilterChanged,
    required this.onTapThumbnail,
  });

  final BulkUploadState state;
  final _BulkFilter filter;
  final String? highlightedId;
  final ValueChanged<_BulkFilter> onFilterChanged;
  final ValueChanged<String> onTapThumbnail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int total = state.drafts.length;
    final int analyzed = state.analyzedCount;
    final int ready = state.publishableCount;
    final int errors = state.errorCount;
    final int missing = state.missingPriceCount;
    final int attention = state.attentionCount;

    final double progressValue = state.publishing
        ? (ready == 0 ? 0 : state.publishedCount / ready)
        : (total == 0 ? 0 : analyzed / total);

    String statusTitle;
    String statusSubtitle;
    if (state.publishing) {
      statusTitle =
          'Publicando productos (${state.publishedCount} de $ready)...';
      statusSubtitle = 'Subiendo fotos y guardando en tu catálogo';
    } else if (state.analyzing) {
      statusTitle = 'Analizando fotos con IA ($analyzed de $total)...';
      statusSubtitle = 'Podés ir revisando o poniendo precios mientras termina';
    } else if (attention > 0) {
      final List<String> parts = <String>[
        if (ready > 0) '$ready listos',
        if (missing > 0) '$missing sin precio',
        if (errors > 0) '$errors con error',
      ];
      statusTitle = parts.join(' · ');
      statusSubtitle = 'Pusimos arriba los que necesitan revisión para que no tengas que buscarlos';
    } else {
      statusTitle = '¡$ready de $total productos listos para publicar!';
      statusSubtitle = 'Revisá los precios o tocá Publicar abajo';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (state.analyzing || state.publishing) ...<Widget>[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
              ] else ...<Widget>[
                Icon(
                  attention > 0
                      ? Icons.info_outline_rounded
                      : Icons.check_circle_rounded,
                  size: 18,
                  color: attention > 0 ? tokens.warning : tokens.success,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  statusTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              if (!state.analyzing && !state.publishing && errors > 0)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: () => ref
                      .read(bulkUploadControllerProvider.notifier)
                      .retryAllFailed(),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text('Reintentar ($errors)'),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            statusSubtitle,
            style: TextStyle(fontSize: 11.5, color: tokens.textSecondary),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: tokens.border,
              color: attention > 0 && !state.analyzing
                  ? tokens.warning
                  : scheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.drafts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (BuildContext context, int index) {
                final BulkProductDraft d = state.drafts[index];
                return _MiniThumbTile(
                  index: index,
                  draft: d,
                  selected: d.id == highlightedId,
                  onTap: () => onTapThumbnail(d.id),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _FilterChipPill(
                  label: 'Todos ($total)',
                  selected: filter == _BulkFilter.all,
                  onTap: () => onFilterChanged(_BulkFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChipPill(
                  label: 'Para revisar ($attention)',
                  selected: filter == _BulkFilter.attention,
                  highlightColor: attention > 0 ? tokens.warning : null,
                  onTap: () => onFilterChanged(_BulkFilter.attention),
                ),
                const SizedBox(width: 8),
                _FilterChipPill(
                  label: 'Listos ($ready)',
                  selected: filter == _BulkFilter.ready,
                  highlightColor: ready > 0 ? tokens.success : null,
                  onTap: () => onFilterChanged(_BulkFilter.ready),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniThumbTile extends StatelessWidget {
  const _MiniThumbTile({
    required this.index,
    required this.draft,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final BulkProductDraft draft;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    Color badgeColor;
    Widget badgeChild;
    if (draft.analyzing || !draft.analyzed) {
      badgeColor = scheme.primary;
      badgeChild = const SizedBox(
        width: 9,
        height: 9,
        child: CircularProgressIndicator(strokeWidth: 1.6, color: Colors.white),
      );
    } else if (draft.error != null) {
      badgeColor = tokens.danger;
      badgeChild = const Icon(
        Icons.priority_high,
        size: 11,
        color: Colors.white,
      );
    } else if (!draft.isValid) {
      badgeColor = tokens.warning;
      badgeChild = const Icon(
        Icons.attach_money,
        size: 11,
        color: Colors.white,
      );
    } else {
      badgeColor = tokens.success;
      badgeChild = const Icon(Icons.check, size: 11, color: Colors.white);
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? scheme.primary : badgeColor,
                width: selected ? 2.4 : 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.5),
              child: Image.memory(draft.imageBytes, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 1.5),
              ),
              alignment: Alignment.center,
              child: badgeChild,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipPill extends StatelessWidget {
  const _FilterChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.highlightColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color accent = highlightColor ?? scheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.14) : tokens.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent : tokens.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? accent : tokens.textSecondary,
          ),
        ),
      ),
    );
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
  const _DraftsList({
    required this.state,
    required this.filter,
    required this.highlightedId,
  });

  final BulkUploadState state;
  final _BulkFilter filter;
  final String? highlightedId;

  bool _matches(BulkProductDraft d) {
    switch (filter) {
      case _BulkFilter.all:
        return true;
      case _BulkFilter.attention:
        return d.error != null || (d.analyzed && !d.isValid);
      case _BulkFilter.ready:
        return d.analyzed && d.error == null && d.isValid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final List<int> visibleIndices = <int>[
      for (int i = 0; i < state.drafts.length; i++)
        if (_matches(state.drafts[i])) i,
    ];

    if (visibleIndices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            filter == _BulkFilter.attention
                ? '¡Ningún producto pendiente de revisión!'
                : 'No hay productos en este filtro.',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        FloatingNavBar.height + 60,
      ),
      itemCount: visibleIndices.length,
      itemBuilder: (BuildContext context, int pos) {
        final int realIndex = visibleIndices[pos];
        final BulkProductDraft draft = state.drafts[realIndex];
        return KeyedSubtree(
          key: GlobalObjectKey(draft.id),
          child: _DraftCard(
            index: realIndex,
            draft: draft,
            analyzing: state.analyzing,
            publishing: state.publishing,
            highlighted: draft.id == highlightedId,
          ),
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
    required this.highlighted,
  });

  final int index;
  final BulkProductDraft draft;
  final bool analyzing;
  final bool publishing;
  final bool highlighted;

  @override
  ConsumerState<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends ConsumerState<_DraftCard> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _compareAtPrice;
  late final TextEditingController _wholesalePrice;
  late final TextEditingController _wholesaleMinQty;
  late final TextEditingController _sku;
  late final TextEditingController _stock;
  late final TextEditingController _tags;
  late final TextEditingController _variants;
  late final TextEditingController _category;
  bool _expanded = false;

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
    _wholesalePrice = TextEditingController(
      text: widget.draft.wholesalePrice?.toStringAsFixed(0) ?? '',
    );
    _wholesaleMinQty = TextEditingController(
      text: widget.draft.wholesaleMinQty?.toString() ?? '',
    );
    _sku = TextEditingController(text: widget.draft.sku ?? '');
    _stock = TextEditingController(text: widget.draft.stock.toString());
    _tags = TextEditingController(text: widget.draft.tags.join(', '));
    _variants = TextEditingController(text: widget.draft.variants.join(', '));
    _category = TextEditingController(
      text: ProductCategory.labelOf(widget.draft.category),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _compareAtPrice.dispose();
    _wholesalePrice.dispose();
    _wholesaleMinQty.dispose();
    _sku.dispose();
    _stock.dispose();
    _tags.dispose();
    _variants.dispose();
    _category.dispose();
    super.dispose();
  }

  void _syncIfDifferent(TextEditingController c, String next) {
    if (c.text != next) {
      c.text = next;
    }
  }

  @override
  void didUpdateWidget(covariant _DraftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final BulkProductDraft draft = widget.draft;
    if (oldWidget.draft.id != draft.id ||
        (!oldWidget.draft.analyzed && draft.analyzed) ||
        (oldWidget.draft.analyzing && !draft.analyzing)) {
      _syncIfDifferent(_title, draft.title);
      _syncIfDifferent(_description, draft.description ?? '');
      _syncIfDifferent(_price, draft.price?.toStringAsFixed(0) ?? '');
      _syncIfDifferent(
        _compareAtPrice,
        draft.compareAtPrice?.toStringAsFixed(0) ?? '',
      );
      _syncIfDifferent(
        _wholesalePrice,
        draft.wholesalePrice?.toStringAsFixed(0) ?? '',
      );
      _syncIfDifferent(
        _wholesaleMinQty,
        draft.wholesaleMinQty?.toString() ?? '',
      );
      _syncIfDifferent(_sku, draft.sku ?? '');
      _syncIfDifferent(_stock, draft.stock.toString());
      _syncIfDifferent(_tags, draft.tags.join(', '));
      _syncIfDifferent(_variants, draft.variants.join(', '));
      _syncIfDifferent(_category, ProductCategory.labelOf(draft.category));
    }
  }

  void _commit() {
    final double? price = double.tryParse(
      _price.text.replaceAll('.', '').replaceAll(',', '.'),
    );
    final double? compareAtPrice = double.tryParse(
      _compareAtPrice.text.replaceAll('.', '').replaceAll(',', '.'),
    );
    final double? wholesalePrice = double.tryParse(
      _wholesalePrice.text.replaceAll('.', '').replaceAll(',', '.'),
    );
    final int? wholesaleMinQty = int.tryParse(_wholesaleMinQty.text.trim());
    final int? stock = int.tryParse(_stock.text);
    final BulkUploadController controller = ref.read(
      bulkUploadControllerProvider.notifier,
    );
    controller.updateDraft(
      widget.index,
      widget.draft.copyWith(
        title: _title.text,
        description: _description.text.isEmpty ? null : _description.text,
        price: price,
        compareAtPrice: compareAtPrice,
        wholesalePrice: wholesalePrice,
        wholesaleMinQty: wholesaleMinQty,
        sku: _sku.text.isEmpty ? null : _sku.text,
        category: _category.text.trim().isEmpty
            ? ProductCategory.other.id
            : ProductCategory.storedValue(_category.text),
        stock: stock ?? 0,
        tags: _tags.text
            .split(',')
            .map((String s) => s.trim())
            .where((String s) => s.isNotEmpty)
            .toList(),
        variants: _variants.text
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BulkProductDraft draft = widget.draft;
    final bool isAnalyzing = draft.analyzing;
    final bool hasError = draft.error != null;
    final bool isValid = draft.isValid;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    if (isAnalyzing || !draft.analyzed) {
      statusColor = scheme.primary;
      statusLabel = 'Analizando...';
      statusIcon = Icons.auto_awesome;
    } else if (hasError) {
      statusColor = tokens.danger;
      statusLabel = 'Error';
      statusIcon = Icons.error_outline;
    } else if (!isValid) {
      statusColor = tokens.warning;
      statusLabel = draft.title.trim().isEmpty
          ? 'Falta nombre/precio'
          : 'Falta precio';
      statusIcon = Icons.edit_note_rounded;
    } else {
      statusColor = tokens.success;
      statusLabel = 'Listo';
      statusIcon = Icons.check_circle_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: widget.highlighted
              ? scheme.primary
              : (hasError
                    ? tokens.danger.withValues(alpha: 0.45)
                    : (!isValid && draft.analyzed
                          ? tokens.warning.withValues(alpha: 0.45)
                          : tokens.border)),
          width: widget.highlighted ? 1.8 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        draft.imageBytes,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#${widget.index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(statusIcon, size: 12, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              tooltip: 'Eliminar',
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: tokens.danger,
                              ),
                              onPressed: widget.publishing
                                  ? null
                                  : () => ref
                                        .read(
                                          bulkUploadControllerProvider.notifier,
                                        )
                                        .removeDraft(widget.index),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (isAnalyzing) ...<Widget>[
                        const AppSkeleton(
                          width: double.infinity,
                          height: 14,
                          radius: 6,
                        ),
                        const SizedBox(height: 6),
                        const AppSkeleton(width: 110, height: 14, radius: 6),
                      ] else if (hasError) ...<Widget>[
                        Text(
                          draft.error!,
                          style: TextStyle(
                            color: tokens.danger,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: widget.analyzing
                                    ? null
                                    : () => ref
                                          .read(
                                            bulkUploadControllerProvider
                                                .notifier,
                                          )
                                          .retryAnalysis(widget.index),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Reintentar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () => ref
                                    .read(bulkUploadControllerProvider.notifier)
                                    .fillManually(widget.index),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('A mano'),
                              ),
                            ),
                          ],
                        ),
                      ] else ...<Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              flex: 3,
                              child: _Field(
                                label: 'Nombre',
                                controller: _title,
                                onChanged: (_) => _commit(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: _Field(
                                label: 'Precio \$',
                                controller: _price,
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
              ],
            ),
            if (!isAnalyzing && !hasError) ...<Widget>[
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.category_outlined,
                        size: 13,
                        color: tokens.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${ProductCategory.labelOf(draft.category)}'
                          '${draft.description != null && draft.description!.trim().isNotEmpty ? ' · ${draft.description!.trim()}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _expanded ? 'Menos detalles' : 'Más detalles',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded) ...<Widget>[
                const SizedBox(height: 10),
                _Field(
                  label: 'Descripción',
                  controller: _description,
                  maxLines: 2,
                  onChanged: (_) => _commit(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Field(
                        label: 'Categoría',
                        controller: _category,
                        onChanged: (_) => _commit(),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Field(
                        label: 'Precio ant. (opc)',
                        controller: _compareAtPrice,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _commit(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Field(
                        label: 'Mayorista (opc)',
                        controller: _wholesalePrice,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _commit(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Field(
                        label: 'Desde (u.)',
                        controller: _wholesaleMinQty,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _commit(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: _Field(
                        label: 'Etiquetas (coma)',
                        controller: _tags,
                        onChanged: (_) => _commit(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Field(
                        label: 'SKU (opc)',
                        controller: _sku,
                        onChanged: (_) => _commit(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _Field(
                  label: 'Variantes separadas por coma (opc)',
                  controller: _variants,
                  onChanged: (_) => _commit(),
                ),
              ],
            ],
            if (draft.publishing)
              const Padding(
                padding: EdgeInsets.only(top: 8),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: SafeArea(
        child: SizedBox(
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    ready == 0
                        ? 'Completá al menos 1 precio para publicar'
                        : 'Publicar $ready ${ready == 1 ? 'producto' : 'productos'}',
                  ),
          ),
        ),
      ),
    );
  }
}
