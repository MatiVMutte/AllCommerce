import 'package:all_commerce/core/constants/app_config.dart';
import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/router/customer_mode.dart';
import 'package:all_commerce/core/services/user_location_service.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/utils/share_service.dart';
import 'package:all_commerce/core/widgets/app_avatar.dart';
import 'package:all_commerce/core/widgets/app_card.dart';
import 'package:all_commerce/core/widgets/app_refresh_button.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:all_commerce/core/widgets/install_app_card.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/catalog/data/repositories/catalog_repository.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/favorites_providers.dart';
import 'package:all_commerce/features/orders/data/services/whatsapp_message_builder.dart';
import 'package:all_commerce/core/widgets/adaptive_nav_shell.dart';
import 'package:all_commerce/core/widgets/app_network_image.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/utils/app_motion.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

enum _DirectoryView { list, map }

class StoreDirectoryView extends ConsumerStatefulWidget {
  const StoreDirectoryView({this.focusSearch = false, super.key});

  /// Focus the search field when the route is `/?focus=search`.
  final bool focusSearch;

  @override
  ConsumerState<StoreDirectoryView> createState() => _StoreDirectoryViewState();
}

class _StoreDirectoryViewState extends ConsumerState<StoreDirectoryView> {
  final FocusNode _searchFocus = FocusNode();
  bool _animated = false;
  _DirectoryView _view = _DirectoryView.list;
  String? _zone;
  bool _cardOnly = false;
  bool _nearby = false;
  bool _locating = false;
  LatLng? _userPos;

  Future<void> _toggleNearby() async {
    if (_nearby) {
      setState(() => _nearby = false);
      return;
    }
    LatLng? pos = _userPos;
    if (pos == null) {
      setState(() => _locating = true);
      final UserLocationResult result = await const UserLocationService()
          .locate();
      if (!mounted) return;
      setState(() => _locating = false);
      pos = result.position;
      if (pos == null) {
        showAppSnackBar(
          context,
          result.serviceDisabled
              ? 'La ubicación está desactivada en este dispositivo.'
              : result.permissionBlockedForever
              ? 'La ubicación está bloqueada para este sitio. Habilitála '
                    'desde el ícono del candado en la barra del navegador.'
              : 'No pudimos obtener tu ubicación. Aceptá el permiso que '
                    'aparece arriba, junto a la barra de direcciones.',
          isError: true,
          action: result.serviceDisabled && !kIsWeb
              ? SnackBarAction(
                  label: 'Activar',
                  onPressed: () =>
                      const UserLocationService().openLocationSettings(),
                )
              : null,
        );
        return;
      }
      _userPos = pos;
    }
    setState(() => _nearby = true);
  }

  int get _activeFilterCount => (_nearby ? 1 : 0) + (_cardOnly ? 1 : 0);

  /// Filters live in a sheet: keeps the toolbar to Lista/Mapa + one pill,
  /// and leaves room for future filters (open now, delivery...).
  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Filtros',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (_activeFilterCount > 0)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _nearby = false;
                                _cardOnly = false;
                              });
                              setSheetState(() {});
                            },
                            child: const Text('Limpiar'),
                          ),
                      ],
                    ),
                  ),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.near_me_rounded),
                    title: const Text('Cerca de vos'),
                    subtitle: const Text('Ordena los locales por distancia'),
                    value: _nearby,
                    onChanged: _locating
                        ? null
                        : (_) async {
                            setSheetState(() {});
                            await _toggleNearby();
                            if (!context.mounted) return;
                            setSheetState(() {});
                            if (!_nearby &&
                                _userPos == null &&
                                sheetContext.mounted) {
                              // Location failed: close so the snackbar shows.
                              Navigator.of(sheetContext).pop();
                            }
                          },
                  ),
                  if (_locating)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.credit_card_rounded),
                    title: const Text('Solo locales que aceptan tarjeta'),
                    value: _cardOnly,
                    onChanged: (bool v) {
                      setState(() => _cardOnly = v);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.focusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(publicZonesProvider);
    ref.invalidate(activeTenantsProvider(_zone));
    await ref
        .read(activeTenantsProvider(_zone).future)
        .catchError((Object _) => const <TenantModel>[]);
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final AsyncValue<List<TenantModel>> tenants = ref.watch(
      activeTenantsProvider(_zone),
    );
    final AsyncValue<List<String>> zonesAsync = ref.watch(publicZonesProvider);
    final String search = ref.watch(storeSearchProvider);
    final UserModel? profile = ref.watch(currentProfileProvider).value;
    final bool animate = !_animated && AppMotion.enabled(context);
    _animated = true;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          profile == null
                              ? 'Hola'
                              : 'Hola, ${profile.fullName.split(' ').first}',
                          style: Theme.of(context).textTheme.headlineMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile?.isOwner ?? false) ...<Widget>[
                        Flexible(
                          child: FilledButton.tonalIcon(
                            icon: const Icon(
                              Icons.storefront_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Mi negocio',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () {
                              ref
                                  .read(customerModeProvider.notifier)
                                  .exitCustomerMode();
                              context.go('/owner');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      AppRefreshButton(onRefresh: () => _refresh(ref)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: Text(
                    '¿Qué vas a pedir hoy?',
                    style: TextStyle(fontSize: 16, color: tokens.textSecondary),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    focusNode: _searchFocus,
                    decoration: const InputDecoration(
                      hintText: AppStrings.searchStores,
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (String value) =>
                        ref.read(storeSearchProvider.notifier).setQuery(value),
                  ),
                ),
                const SizedBox(height: 12),
                _ZoneChips(
                  zonesAsync: zonesAsync,
                  selected: _zone,
                  onSelected: (String? zone) {
                    setState(() => _zone = zone);
                    ref.invalidate(activeTenantsProvider(_zone));
                  },
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: SegmentedButton<_DirectoryView>(
                          selected: <_DirectoryView>{_view},
                          onSelectionChanged: (Set<_DirectoryView> value) {
                            setState(() => _view = value.first);
                          },
                          segments: const <ButtonSegment<_DirectoryView>>[
                            ButtonSegment<_DirectoryView>(
                              value: _DirectoryView.list,
                              label: Text('Lista'),
                              icon: Icon(Icons.list_rounded),
                            ),
                            ButtonSegment<_DirectoryView>(
                              value: _DirectoryView.map,
                              label: Text('Mapa'),
                              icon: Icon(Icons.map_rounded),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _FiltersPill(
                        activeCount: _activeFilterCount,
                        onTap: _openFilters,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const InstallAppCard(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => context.push('/para-locales'),
                      icon: const Icon(Icons.storefront_outlined, size: 16),
                      label: const Text('¿Tenés un local? Sumalo gratis'),
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: tenants.when(
                    loading: () =>
                        const AppSkeletonList(itemCount: 4, itemHeight: 132),
                    error: (Object error, StackTrace stack) =>
                        AppErrorState(onRetry: () => _refresh(ref)),
                    data: (List<TenantModel> list) {
                      List<TenantModel> filtered = filterTenants(list, search);
                      if (_cardOnly) {
                        filtered = filtered
                            .where((TenantModel t) => t.acceptsCard)
                            .toList();
                      }
                      final Set<String> favs = ref.watch(
                        favoriteStoresProvider,
                      );
                      filtered.sort((TenantModel a, TenantModel b) {
                        final int fav =
                            (favs.contains(a.id) ? 0 : 1) -
                            (favs.contains(b.id) ? 0 : 1);
                        if (fav != 0) return fav;
                        if (_nearby && _userPos != null) {
                          final double? da = UserLocationService.distanceTo(
                            a,
                            _userPos,
                          );
                          final double? db = UserLocationService.distanceTo(
                            b,
                            _userPos,
                          );
                          if (da == null && db == null) return 0;
                          if (da == null) return 1;
                          if (db == null) return -1;
                          return da.compareTo(db);
                        }
                        return 0;
                      });
                      final bool searchingProducts = search.trim().length >= 2;
                      final List<GlobalProductHit> productHits =
                          searchingProducts
                          ? (ref
                                    .watch(
                                      globalProductSearchProvider(
                                        search.trim(),
                                      ),
                                    )
                                    .value ??
                                const <GlobalProductHit>[])
                          : const <GlobalProductHit>[];
                      final bool productsLoading =
                          searchingProducts &&
                          ref
                              .watch(globalProductSearchProvider(search.trim()))
                              .isLoading;
                      if (filtered.isEmpty &&
                          productHits.isEmpty &&
                          !productsLoading) {
                        return const AppEmptyState(
                          icon: Icons.storefront_outlined,
                          title: AppStrings.noStoresFound,
                        );
                      }
                      if (_view == _DirectoryView.map) {
                        return _DirectoryMap(
                          tenants: filtered,
                          myTenantId: profile?.tenantId,
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async => _refresh(ref),
                        child: LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints box) {
                            final bool multiColumn = box.maxWidth >= 680;
                            if (!multiColumn || productHits.isNotEmpty) {
                              return ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  FloatingNavBar.height,
                                ),
                                children: <Widget>[
                                  if (productHits.isNotEmpty) ...<Widget>[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        4,
                                        4,
                                        4,
                                        8,
                                      ),
                                      child: Text(
                                        'PRODUCTOS ENCONTRADOS (${productHits.length})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                          color: context.tokens.textTertiary,
                                        ),
                                      ),
                                    ),
                                    for (final (int i, GlobalProductHit hit)
                                        in productHits.indexed)
                                      animate && i < 8
                                          ? FadeInUp(
                                              duration: const Duration(
                                                milliseconds: 240,
                                              ),
                                              delay: Duration(
                                                milliseconds: (i % 6) * 35,
                                              ),
                                              from: 14,
                                              child: _GlobalProductHitCard(
                                                hit: hit,
                                              ),
                                            )
                                          : _GlobalProductHitCard(hit: hit),
                                    if (filtered.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          4,
                                          12,
                                          4,
                                          8,
                                        ),
                                        child: Text(
                                          'LOCALES (${filtered.length})',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                            color: context.tokens.textTertiary,
                                          ),
                                        ),
                                      ),
                                  ],
                                  for (
                                    int index = 0;
                                    index < filtered.length;
                                    index++
                                  )
                                    Builder(
                                      builder: (BuildContext context) {
                                        final Widget card = _StoreCard(
                                          tenant: filtered[index],
                                          isMine:
                                              profile?.tenantId ==
                                              filtered[index].id,
                                          distanceMeters: _nearby
                                              ? UserLocationService.distanceTo(
                                                  filtered[index],
                                                  _userPos,
                                                )
                                              : null,
                                        );
                                        return animate && index < 8
                                            ? card
                                                  .animate()
                                                  .fadeIn(
                                                    duration: 300.ms,
                                                    delay: (index * 40).ms,
                                                  )
                                                  .slideY(
                                                    begin: 0.08,
                                                    end: 0,
                                                    duration: 300.ms,
                                                    delay: (index * 40).ms,
                                                    curve: Curves.easeOutCubic,
                                                  )
                                            : card;
                                      },
                                    ),
                                ],
                              );
                            }
                            final int columns = box.maxWidth >= 1280
                                ? 4
                                : box.maxWidth >= 980
                                ? 3
                                : 2;
                            return GridView.builder(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                4,
                                16,
                                AdaptiveNavShell.isWide(context)
                                    ? 24
                                    : FloatingNavBar.height,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    mainAxisExtent: 252,
                                  ),
                              itemCount: filtered.length,
                              itemBuilder: (BuildContext context, int index) {
                                final Widget card = _StoreCard(
                                  tenant: filtered[index],
                                  bottomMargin: 0,
                                  isMine:
                                      profile?.tenantId == filtered[index].id,
                                  distanceMeters: _nearby
                                      ? UserLocationService.distanceTo(
                                          filtered[index],
                                          _userPos,
                                        )
                                      : null,
                                );
                                return animate && index < 8
                                    ? card
                                          .animate()
                                          .fadeIn(
                                            duration: 300.ms,
                                            delay: (index * 40).ms,
                                          )
                                          .slideY(
                                            begin: 0.08,
                                            end: 0,
                                            duration: 300.ms,
                                            delay: (index * 40).ms,
                                            curve: Curves.easeOutCubic,
                                          )
                                    : card;
                              },
                            );
                          },
                        ),
                      );
                    },
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

class _ZoneChips extends StatelessWidget {
  const _ZoneChips({
    required this.zonesAsync,
    required this.selected,
    required this.onSelected,
  });

  final AsyncValue<List<String>> zonesAsync;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: zonesAsync.when(
        loading: () => ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: const <Widget>[
            AppSkeleton(width: 80, height: 32, radius: 999),
            SizedBox(width: 8),
            AppSkeleton(width: 100, height: 32, radius: 999),
          ],
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (List<String> zones) {
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: zones.length + 1,
            itemBuilder: (BuildContext context, int index) {
              final bool isAll = index == 0;
              final String? zone = isAll ? null : zones[index - 1];
              final bool active = selected == zone;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(isAll ? 'Todas' : zone!),
                  selected: active,
                  showCheckmark: false,
                  onSelected: (_) => onSelected(zone),
                  selectedColor: scheme.primary,
                  labelStyle: TextStyle(
                    color: active ? scheme.onPrimary : tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DirectoryMap extends StatelessWidget {
  const _DirectoryMap({required this.tenants, this.myTenantId});

  final List<TenantModel> tenants;

  /// Tenant id of the signed-in owner, to flag their own store's marker.
  final String? myTenantId;

  List<TenantModel> get _withCoords => tenants
      .where(
        (TenantModel t) => t.lat != null && t.lng != null && !t.isUnclaimedLead,
      )
      .toList();

  LatLng get _center {
    final List<TenantModel> list = _withCoords;
    if (list.isEmpty) return const LatLng(-34.6, -58.4);
    final double lat =
        list.map((TenantModel t) => t.lat!).reduce((a, b) => a + b) /
        list.length;
    final double lng =
        list.map((TenantModel t) => t.lng!).reduce((a, b) => a + b) /
        list.length;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final List<TenantModel> points = _withCoords;
    if (points.isEmpty) {
      return const AppEmptyState(
        icon: Icons.map_outlined,
        title: 'Sin locales en el mapa',
        subtitle: 'Los locales sin dirección exacta aparecen solo en la lista.',
      );
    }
    return FlutterMap(
      options: MapOptions(initialCenter: _center, initialZoom: 14),
      children: <Widget>[
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.allgorithm.allcommerce',
        ),
        MarkerLayer(
          markers: points.map((TenantModel t) {
            final bool isMine = t.id == myTenantId;
            return Marker(
              point: LatLng(t.lat!, t.lng!),
              width: isMine ? 72 : 40,
              height: isMine ? 76 : 50,
              child: _MapMarker(
                tenant: t,
                isMine: isMine,
                onTap: () => _showStoreSheet(context, t),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showStoreSheet(BuildContext context, TenantModel tenant) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (BuildContext context) =>
          _MapStoreSheet(tenant: tenant, isMine: tenant.id == myTenantId),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.tenant,
    required this.onTap,
    this.isMine = false,
  });

  final TenantModel tenant;
  final VoidCallback onTap;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: <Widget>[
          if (isMine)
            Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: const Text(
                'Tu local',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tenant.primaryColorValue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
            child: Center(
              child: Text(
                tenant.name.isEmpty ? '?' : tenant.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Icon(Icons.location_on, color: tenant.primaryColorValue, size: 12),
        ],
      ),
    );
  }
}

class _MapStoreSheet extends StatelessWidget {
  const _MapStoreSheet({required this.tenant, this.isMine = false});

  final TenantModel tenant;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                AppAvatar(tenant: tenant, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              tenant.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (isMine) ...<Widget>[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Tu local',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (tenant.address != null)
                        Text(
                          tenant.address!,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (tenant.isUnclaimedLead) ...<Widget>[
              _ClaimCallout(tenant: tenant),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: tenant.isUnclaimedLead
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        context.push('/s/${tenant.slug}');
                      },
                child: Text(
                  tenant.isUnclaimedLead ? 'Próximamente' : 'Ver catálogo',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.tenant,
    this.bottomMargin = 16,
    this.isMine = false,
    this.distanceMeters,
  });

  final TenantModel tenant;
  final double bottomMargin;

  /// Distance to the user when "Cerca de vos" is active (km badge).
  final double? distanceMeters;

  /// True when this store belongs to the signed-in owner (customer mode).
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Container(
      margin: EdgeInsets.only(bottom: bottomMargin),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tenant.isUnclaimedLead
            ? null
            : () => context.push('/s/${tenant.slug}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: 96,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: tenant.logoUrl == null
                        ? Container(color: tenant.primaryColorValue)
                        : AppNetworkImage(
                            imageUrl: tenant.logoUrl!,
                            placeholder: Container(
                              color: tenant.primaryColorValue,
                            ),
                            errorBuilder: (_) =>
                                Container(color: tenant.primaryColorValue),
                          ),
                  ),
                  if (tenant.isUnclaimedLead)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Próximamente',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (distanceMeters != null)
                    Positioned(
                      bottom: 10,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.near_me_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'a ${UserLocationService.distanceLabel(distanceMeters!)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isMine)
                    Positioned(
                      top: 10,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary
                              .withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Tu local',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  if (!tenant.isUnclaimedLead)
                    Positioned(
                      top: 10,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (tenant.isOpen ? tokens.success : Colors.black87)
                                  .withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tenant.isOpen ? 'Abierto' : 'Cerrado',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 16,
                    bottom: -20,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: tokens.surface, width: 3),
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: AppAvatar(tenant: tenant, size: 56),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          tenant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                      if (!tenant.isUnclaimedLead)
                        _FavHeart(tenantId: tenant.id),
                    ],
                  ),
                  if (tenant.description != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      tenant.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (tenant.zone != null ||
                      tenant.address != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: tokens.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            <String>[
                              if (tenant.zone != null) tenant.zone!,
                              if (tenant.address != null) tenant.address!,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (tenant.openingHours != null &&
                      tenant.openingHours!.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: tokens.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            tenant.openingHours!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (tenant.isUnclaimedLead) ...<Widget>[
                    const SizedBox(height: 10),
                    _ClaimCallout(tenant: tenant),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimCallout extends StatelessWidget {
  const _ClaimCallout({required this.tenant});

  final TenantModel tenant;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () {
        final String support = AppConfig.supportWhatsapp;
        if (support.isEmpty) return;
        launchUrl(
          buildWhatsAppUri(
            support,
            'Hola! Soy el dueño de ${tenant.name} '
            '(${ShareService.linkBase}/s/${tenant.slug}) y quiero reclamar mi local.',
          ),
          mode: LaunchMode.externalApplication,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.storefront_outlined, size: 16, color: primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '¿Sos el dueño? Reclamá tu local',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: primary),
          ],
        ),
      ),
    );
  }
}

/// Heart toggle to mark a store as favorite (persisted locally).
class _FavHeart extends ConsumerWidget {
  const _FavHeart({required this.tenantId});

  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool fav = ref.watch(favoriteStoresProvider).contains(tenantId);
    final bool animate = AppMotion.enabled(context);
    final Widget icon = Icon(
      fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      color: fav ? const Color(0xFFEF4444) : context.tokens.textTertiary,
    );
    return IconButton(
      iconSize: 22,
      visualDensity: VisualDensity.compact,
      tooltip: fav ? 'Quitar de favoritos' : 'Agregar a favoritos',
      icon: (animate && fav)
          ? ElasticIn(
              key: const ValueKey<bool>(true),
              duration: const Duration(milliseconds: 420),
              child: icon,
            )
          : icon,
      onPressed: () =>
          ref.read(favoriteStoresProvider.notifier).toggle(tenantId),
    );
  }
}

class _GlobalProductHitCard extends StatelessWidget {
  const _GlobalProductHitCard({required this.hit});

  final GlobalProductHit hit;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: () => context.push('/s/${hit.tenantSlug}/p/${hit.productId}'),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: hit.imageUrl == null
                    ? Container(
                        color: tokens.surfaceMuted,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 22,
                          color: tokens.textTertiary,
                        ),
                      )
                    : AppNetworkImage(
                        imageUrl: hit.imageUrl!,
                        placeholder: Container(color: tokens.surfaceMuted),
                        errorBuilder: (_) => Container(
                          color: tokens.surfaceMuted,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 22,
                            color: tokens.textTertiary,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    hit.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.storefront_outlined,
                        size: 13,
                        color: tokens.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          hit.tenantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  Formatters.price(hit.price),
                  style: TextStyle(fontWeight: FontWeight.w800, color: primary),
                ),
                if (hit.isOnSale && hit.compareAtPrice != null)
                  Text(
                    Formatters.price(hit.compareAtPrice!),
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.textTertiary,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                if (hit.hasWholesale)
                  Text(
                    'Mayor. ${Formatters.price(hit.wholesalePrice!)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact pill that opens the filters sheet; shows how many are active.
class _FiltersPill extends StatelessWidget {
  const _FiltersPill({required this.activeCount, required this.onTap});

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool active = activeCount > 0;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? primary.withValues(alpha: 0.12) : tokens.surface,
          border: Border.all(color: active ? primary : tokens.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.tune_rounded,
              size: 16,
              color: active ? primary : tokens.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              active ? 'Filtros · $activeCount' : 'Filtros',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? primary : tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
