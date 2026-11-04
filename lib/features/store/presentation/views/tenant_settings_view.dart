import 'dart:async';

import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/services/nominatim_geocoder.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/utils/share_service.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/utils/validators.dart';
import 'package:all_commerce/core/widgets/adaptive_nav_shell.dart';
import 'package:all_commerce/core/widgets/app_network_image.dart';
import 'package:all_commerce/core/widgets/section_card.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/store/presentation/view_models/tenant_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

const List<String> _palette = <String>[
  '#0052FF',
  '#1E88E5',
  '#00897B',
  '#43A047',
  '#F4511E',
  '#E53935',
  '#8E24AA',
  '#212121',
];

class TenantSettingsView extends ConsumerStatefulWidget {
  const TenantSettingsView({super.key});

  @override
  ConsumerState<TenantSettingsView> createState() => _TenantSettingsViewState();
}

class _TenantSettingsViewState extends ConsumerState<TenantSettingsView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _whatsapp = TextEditingController();
  final TextEditingController _transferAlias = TextEditingController();
  final TextEditingController _mercadoPagoLink = TextEditingController();
  final TextEditingController _openingHours = TextEditingController();
  final TextEditingController _cashDisc = TextEditingController();
  final TextEditingController _transferDisc = TextEditingController();
  final TextEditingController _mpDisc = TextEditingController();
  final TextEditingController _bulkMin = TextEditingController();
  final TextEditingController _bulkPct = TextEditingController();
  bool _acceptsCash = true;
  bool _acceptsCard = false;
  bool _isOpen = true;
  bool _isPublic = true;
  String _color = '#0052FF';
  double? _lat;
  double? _lng;
  bool _initialized = false;
  String? _refreshedTenantId;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _address.dispose();
    _whatsapp.dispose();
    _transferAlias.dispose();
    _mercadoPagoLink.dispose();
    _openingHours.dispose();
    _cashDisc.dispose();
    _transferDisc.dispose();
    _mpDisc.dispose();
    _bulkMin.dispose();
    _bulkPct.dispose();
    super.dispose();
  }

  void _init(TenantModel tenant) {
    _name.text = tenant.name;
    _description.text = tenant.description ?? '';
    _address.text = tenant.address ?? '';
    // Show the local part without the 549 prefix when possible.
    final String w = tenant.whatsapp;
    _whatsapp.text = w.startsWith('549') ? w.substring(3) : w;
    _transferAlias.text = tenant.transferAlias ?? '';
    _mercadoPagoLink.text = tenant.mercadoPagoLink ?? '';
    _openingHours.text = tenant.openingHours ?? '';
    _acceptsCash = tenant.acceptsCash;
    _acceptsCard = tenant.acceptsCard;
    _isOpen = tenant.isOpen;
    _isPublic = tenant.isPublic;
    _cashDisc.text = _numText(tenant.cashDiscountPct);
    _transferDisc.text = _numText(tenant.transferDiscountPct);
    _mpDisc.text = _numText(tenant.mpDiscountPct);
    _bulkMin.text = _numText(tenant.bulkDiscountMin);
    _bulkPct.text = _numText(tenant.bulkDiscountPct);
    _color = tenant.primaryColor;
    _lat = tenant.lat;
    _lng = tenant.lng;
    _initialized = true;
    _name.addListener(_onChange);
    _description.addListener(_onChange);
    _address.addListener(_onChange);
    _whatsapp.addListener(_onChange);
    _transferAlias.addListener(_onChange);
    _mercadoPagoLink.addListener(_onChange);
    _openingHours.addListener(_onChange);
    _cashDisc.addListener(_onChange);
    _transferDisc.addListener(_onChange);
    _mpDisc.addListener(_onChange);
    _bulkMin.addListener(_onChange);
    _bulkPct.addListener(_onChange);
  }

  /// '' for 0 so empty fields stay empty (not "0").
  static String _numText(double v) => v == 0 ? '' : v.toStringAsFixed(0);

  static double _numVal(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  void _onChange() => setState(() {});

  void _refreshDiscounts([String? _]) => _onChange();

  bool _isDirty(TenantModel tenant, bool hasPendingLogo) {
    final String w = tenant.whatsapp;
    final String currentPhone = w.startsWith('549') ? w.substring(3) : w;
    return hasPendingLogo ||
        _name.text.trim() != tenant.name ||
        _description.text.trim() != (tenant.description ?? '') ||
        _address.text.trim() != (tenant.address ?? '') ||
        _whatsapp.text.trim() != currentPhone ||
        _transferAlias.text.trim() != (tenant.transferAlias ?? '') ||
        _mercadoPagoLink.text.trim() != (tenant.mercadoPagoLink ?? '') ||
        _openingHours.text.trim() != (tenant.openingHours ?? '') ||
        _isOpen != tenant.isOpen ||
        _isPublic != tenant.isPublic ||
        _numVal(_cashDisc) != tenant.cashDiscountPct ||
        _numVal(_transferDisc) != tenant.transferDiscountPct ||
        _numVal(_mpDisc) != tenant.mpDiscountPct ||
        _numVal(_bulkMin) != tenant.bulkDiscountMin ||
        _numVal(_bulkPct) != tenant.bulkDiscountPct ||
        _lat != tenant.lat ||
        _lng != tenant.lng ||
        _color != tenant.primaryColor;
  }

  Future<void> _pickLocation() async {
    final LocationPickResult? result =
        await showModalBottomSheet<LocationPickResult>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (BuildContext context) => LocationPickerSheet(
            initial: (_lat != null && _lng != null)
                ? LatLng(_lat!, _lng!)
                : null,
            initialQuery: _address.text.trim(),
          ),
        );
    if (result == null || !mounted) return;
    setState(() {
      _lat = result.point?.latitude;
      _lng = result.point?.longitude;
      if (result.addressLabel != null &&
          result.addressLabel!.trim().isNotEmpty &&
          _address.text.trim().isEmpty) {
        _address.text = result.addressLabel!.trim();
      }
    });
  }

  /// Payment capability switches persist immediately — the owner expects
  /// a toggle to just work, not to require the bottom "Guardar" button.
  Future<void> _savePaymentFlags(TenantModel tenant) async {
    final bool ok = await ref
        .read(tenantSettingsControllerProvider.notifier)
        .setPaymentFlags(
          tenant,
          acceptsCash: _acceptsCash,
          acceptsCard: _acceptsCard,
        );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _acceptsCash = tenant.acceptsCash;
        _acceptsCard = tenant.acceptsCard;
      });
      final Object? error = ref.read(tenantSettingsControllerProvider).error;
      if (error != null) showErrorSnackBar(context, error);
      return;
    }
    showAppSnackBar(context, 'Medios de pago actualizados');
  }

  Future<void> _save(TenantModel tenant) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    double? lat = _lat;
    double? lng = _lng;
    final String addrText = _address.text.trim();
    if ((lat == null || lng == null) && addrText.length >= 4) {
      try {
        final List<AddressSuggestion> found = await const NominatimGeocoder()
            .search(addrText);
        if (found.isNotEmpty) {
          lat = found.first.point.latitude;
          lng = found.first.point.longitude;
          _lat = lat;
          _lng = lng;
        }
      } catch (_) {
        // Geocoding is best-effort: never block the save on it.
      }
    }
    final TenantModel? updated = await ref
        .read(tenantSettingsControllerProvider.notifier)
        .save(
          tenant,
          name: _name.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          address: addrText.isEmpty ? null : addrText,
          lat: lat,
          lng: lng,
          whatsapp: Validators.normalizePhone(_whatsapp.text),
          primaryColor: _color,
          transferAlias: _transferAlias.text.trim().isEmpty
              ? null
              : _transferAlias.text.trim(),
          mercadoPagoLink: _mercadoPagoLink.text.trim().isEmpty
              ? null
              : _mercadoPagoLink.text.trim(),
          acceptsCash: _acceptsCash,
          acceptsCard: _acceptsCard,
          isOpen: _isOpen,
          openingHours: _openingHours.text.trim().isEmpty
              ? null
              : _openingHours.text.trim(),
          isPublic: _isPublic,
          cashDiscountPct: _numVal(_cashDisc),
          transferDiscountPct: _numVal(_transferDisc),
          mpDiscountPct: _numVal(_mpDisc),
          bulkDiscountPct: _numVal(_bulkPct),
          bulkDiscountMin: _numVal(_bulkMin),
        );
    if (!mounted) return;
    if (updated == null) {
      final Object? error = ref.read(tenantSettingsControllerProvider).error;
      if (error != null) showErrorSnackBar(context, error);
      return;
    }
    AppHaptics.success();
    showAppSnackBar(context, 'Local actualizado');
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/owner');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final UserModel? profile = ref.watch(currentProfileProvider).value;
    final String? tenantId = profile?.tenantId;
    if (tenantId != null && tenantId != _refreshedTenantId) {
      _refreshedTenantId = tenantId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(tenantByIdProvider(tenantId));
      });
    }
    final TenantSettingsState state = ref.watch(
      tenantSettingsControllerProvider,
    );
    if (tenantId == null) {
      return const Scaffold(
        body: AppEmptyState(
          icon: Icons.error_outline,
          title: AppStrings.genericError,
        ),
      );
    }
    final AsyncValue<TenantModel?> tenantAsync = ref.watch(
      tenantByIdProvider(tenantId),
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: tenantAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace s) => AppErrorState(
            onRetry: () => ref.invalidate(tenantByIdProvider(tenantId)),
          ),
          data: (TenantModel? tenant) {
            if (tenant == null) {
              return const AppEmptyState(
                icon: Icons.storefront_outlined,
                title: AppStrings.storeNotFound,
              );
            }
            if (!_initialized) _init(tenant);
            final List<String> colors = _palette.contains(_color)
                ? _palette
                : <String>[..._palette, _color];
            final Color preview = _hexColor(_color);
            final bool dirty = _isDirty(
              tenant,
              state.pendingLogo != null || state.pendingCover != null,
            );
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      24 +
                          (AdaptiveNavShell.isWide(context)
                              ? 0
                              : FloatingNavBar.height),
                    ),
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Mi local',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AppSectionCard(
                        icon: Icons.storefront_outlined,
                        title: 'Identidad',
                        subtitle: 'Logo, portada, nombre y descripción',
                        children: <Widget>[
                          Center(
                            child: Column(
                              children: <Widget>[
                                Stack(
                                  children: <Widget>[
                                    _SettingsAvatar(
                                      tenant: tenant,
                                      pendingLogo: state.pendingLogo,
                                      loading:
                                          state.pickingLogo || state.saving,
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .scaffoldBackgroundColor,
                                            width: 2,
                                          ),
                                        ),
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Cambiar logo',
                                          iconSize: 16,
                                          icon: const Icon(
                                            Icons.photo_camera_outlined,
                                            color: Colors.white,
                                          ),
                                          onPressed: state.saving
                                              ? null
                                              : () => ref
                                                    .read(
                                                      tenantSettingsControllerProvider
                                                          .notifier,
                                                    )
                                                    .pickLogo(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _name.text.trim().isEmpty
                                      ? tenant.name
                                      : _name.text.trim(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _CoverPicker(
                            tenant: tenant,
                            pendingCover: state.pendingCover,
                            enabled: !state.saving,
                            loading: state.pickingCover || state.saving,
                            onPick: () => ref
                                .read(tenantSettingsControllerProvider.notifier)
                                .pickCover(),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del local',
                            ),
                            validator: Validators.storeName,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _description,
                            decoration: const InputDecoration(
                              labelText: 'Descripción (opcional)',
                            ),
                            maxLines: 3,
                            maxLength: 200,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AppSectionCard(
                        icon: Icons.visibility_outlined,
                        title: 'Visibilidad',
                        subtitle: 'Quién encuentra tu catálogo',
                        children: <Widget>[
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _isPublic,
                            onChanged: (bool value) =>
                                setState(() => _isPublic = value),
                            title: const Text('Aparecer en el directorio'),
                            subtitle: const Text(
                              'Apagado: solo entran con tu link o QR',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  '${ShareService.linkBase}/s/${tenant.slug}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.copy_outlined,
                                  size: 18,
                                  color: tokens.textSecondary,
                                ),
                                tooltip: 'Copiar link',
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text:
                                          'https://${ShareService.linkBase}/s/${tenant.slug}',
                                    ),
                                  );
                                  if (context.mounted) {
                                    showAppSnackBar(context, 'Link copiado');
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AppSectionCard(
                        icon: Icons.place_outlined,
                        title: 'Contacto',
                        children: <Widget>[
                          TextFormField(
                            controller: _address,
                            decoration: const InputDecoration(
                              labelText: 'Dirección (opcional)',
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: state.saving ? null : _pickLocation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: tokens.border),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.pin_drop_outlined,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        const Text(
                                          'Ubicación en el mapa',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          _lat != null && _lng != null
                                              ? 'Marcada · tocá para cambiarla'
                                              : 'Sin marcar · tu local no aparece en el mapa del directorio',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: tokens.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: tokens.textTertiary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _whatsapp,
                            decoration: const InputDecoration(
                              labelText: 'WhatsApp',
                              hintText: '11 2233 4455',
                            ),
                            keyboardType: TextInputType.phone,
                            validator: Validators.phone,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AppSectionCard(
                        icon: Icons.schedule_outlined,
                        title: 'Atención',
                        children: <Widget>[
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _isOpen,
                            onChanged: (bool value) =>
                                setState(() => _isOpen = value),
                            title: const Text('Local abierto ahora'),
                            subtitle: const Text(
                              'Se muestra como Abierto o Cerrado en el directorio y en tu catálogo',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _openingHours,
                            decoration: const InputDecoration(
                              labelText: 'Horarios de atención (opcional)',
                              hintText:
                                  'Ej: Lun a Vie 9 a 19 hs · Sáb 9 a 13 hs',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AppSectionCard(
                        icon: Icons.payments_outlined,
                        title: 'Cobro',
                        subtitle: 'Cómo te pagan',
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: TextFormField(
                                  controller: _transferAlias,
                                  decoration: const InputDecoration(
                                    labelText: 'Alias/CBU para transferencias',
                                    hintText: 'Ej: mateo.dietetica.mp',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Info',
                                icon: const Icon(Icons.help_outline, size: 20),
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (BuildContext context) =>
                                      AlertDialog(
                                        title: const Text('Pagos'),
                                        content: const Text(
                                          'Escribí tu alias de Mercado Pago, CVU o CBU. '
                                          'Los clientes lo verán al elegir "Transferencia".',
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: const Text('Entendido'),
                                          ),
                                        ],
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _mercadoPagoLink,
                            decoration: const InputDecoration(
                              labelText: 'Link de pago Mercado Pago (opcional)',
                              hintText: 'https://mpago.la/...',
                            ),
                            keyboardType: TextInputType.url,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  'Aceptar pago en efectivo',
                                  style: TextStyle(color: tokens.textSecondary),
                                ),
                              ),
                              Switch(
                                value: _acceptsCash,
                                onChanged: (bool value) {
                                  setState(() => _acceptsCash = value);
                                  _savePaymentFlags(tenant);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  'Aceptar tarjetas (crédito/débito)',
                                  style: TextStyle(color: tokens.textSecondary),
                                ),
                              ),
                              Switch(
                                value: _acceptsCard,
                                onChanged: (bool value) {
                                  setState(() => _acceptsCard = value);
                                  _savePaymentFlags(tenant);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AppSectionCard(
                        icon: Icons.percent_rounded,
                        title: 'Descuentos',
                        subtitle: 'Se aplican solos al confirmar el pedido',
                        children: <Widget>[
                          Text(
                            'Por forma de pago',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: tokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '% de descuento automático según el medio elegido',
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _DiscountField(
                            label: 'Efectivo',
                            icon: Icons.payments_outlined,
                            controller: _cashDisc,
                            onChanged: _refreshDiscounts,
                          ),
                          _DiscountField(
                            label: 'Transferencia',
                            icon: Icons.account_balance_outlined,
                            controller: _transferDisc,
                            onChanged: _refreshDiscounts,
                          ),
                          _DiscountField(
                            label: 'Mercado Pago',
                            icon: Icons.qr_code_2_rounded,
                            controller: _mpDisc,
                            onChanged: _refreshDiscounts,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Por total del pedido',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: tokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Descuento automático cuando el pedido es grande',
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _DiscountField(
                            label: 'Si el pedido supera',
                            icon: Icons.shopping_cart_checkout_rounded,
                            controller: _bulkMin,
                            prefix: r'$',
                            hint: '100000',
                            onChanged: _refreshDiscounts,
                          ),
                          _DiscountField(
                            label: 'Descuento',
                            icon: Icons.percent_rounded,
                            controller: _bulkPct,
                            suffix: '%',
                            hint: '10',
                            onChanged: _refreshDiscounts,
                          ),
                          const SizedBox(height: 10),
                          _DiscountsSummary(
                            cash: _cashDisc,
                            transfer: _transferDisc,
                            mp: _mpDisc,
                            bulkMin: _bulkMin,
                            bulkPct: _bulkPct,
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 24),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.local_offer_outlined),
                            title: const Text('Cupones de descuento'),
                            subtitle: const Text(
                              'Creá códigos como PROMO10 para tus clientes',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/owner/coupons'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AppSectionCard(
                        icon: Icons.palette_outlined,
                        title: 'Apariencia',
                        subtitle: 'El color de tu catálogo',
                        children: <Widget>[
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: <Widget>[
                              for (final String hex in colors)
                                _ColorDot(
                                  hex: hex,
                                  selected: hex == _color,
                                  onTap: () => setState(() => _color = hex),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Live preview of the catalog header.
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: tokens.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(height: 64, color: preview),
                                Transform.translate(
                                  offset: const Offset(0, -20),
                                  child: Column(
                                    children: <Widget>[
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .scaffoldBackgroundColor,
                                            width: 3,
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 24,
                                          backgroundColor: preview,
                                          child: Text(
                                            (_name.text.trim().isEmpty
                                                    ? tenant.name
                                                    : _name.text.trim())
                                                .characters
                                                .first
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _name.text.trim().isEmpty
                                            ? tenant.name
                                            : _name.text.trim(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: state.saving || !dirty
                            ? null
                            : () => _save(tenant),
                        child: state.saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Guardar cambios'),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: () => context.push('/owner/plans'),
                          child: Text(
                            'Tu plan: ${tenant.plan.label} · Ver planes',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Color _hexColor(String hex) {
  final String digits = hex.replaceFirst('#', '');
  return Color(0xFF000000 | (int.tryParse(digits, radix: 16) ?? 0));
}

/// Wide cover-image picker shown under the store logo.
class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.tenant,
    required this.pendingCover,
    required this.enabled,
    required this.loading,
    required this.onPick,
  });

  final TenantModel tenant;
  final Uint8List? pendingCover;
  final bool enabled;
  final bool loading;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final bool hasCover = pendingCover != null || tenant.coverUrl != null;
    final Widget image = pendingCover != null
        ? Image.memory(pendingCover!, fit: BoxFit.cover)
        : tenant.coverUrl != null
        ? Image.network(tenant.coverUrl!, fit: BoxFit.cover)
        : const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 140,
            width: double.infinity,
            color: tokens.surfaceMuted,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (hasCover) image,
                Center(
                  child: loading
                      ? Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(10),
                          child: const CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              hasCover
                                  ? Icons.photo_library_outlined
                                  : Icons.add_photo_alternate_outlined,
                              size: 28,
                              color: hasCover
                                  ? Colors.white
                                  : tokens.textTertiary,
                              shadows: hasCover
                                  ? const <Shadow>[
                                      Shadow(
                                        blurRadius: 8,
                                        color: Colors.black45,
                                      ),
                                    ]
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasCover ? 'Cambiar portada' : 'Agregar portada',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: hasCover
                                        ? Colors.white
                                        : tokens.textTertiary,
                                    fontWeight: FontWeight.w600,
                                    shadows: hasCover
                                        ? const <Shadow>[
                                            Shadow(
                                              blurRadius: 8,
                                              color: Colors.black45,
                                            ),
                                          ]
                                        : null,
                                  ),
                            ),
                          ],
                        ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: enabled ? onPick : null),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Se ve como banner en tu catálogo y en el directorio',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: tokens.textTertiary),
        ),
      ],
    );
  }
}

class _SettingsAvatar extends StatelessWidget {
  const _SettingsAvatar({
    required this.tenant,
    this.pendingLogo,
    this.loading = false,
  });

  final TenantModel tenant;
  final Uint8List? pendingLogo;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final Widget child = pendingLogo != null
        ? Image.memory(pendingLogo!, fit: BoxFit.cover)
        : tenant.logoUrl == null
        ? Center(
            child: Text(
              tenant.name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : AppNetworkImage(
            imageUrl: tenant.logoUrl!,
            errorBuilder: (_) => Center(
              child: Text(
                tenant.name.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: tenant.primaryColorValue,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          child,
          if (loading)
            const ColoredBox(
              color: Colors.black38,
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = _hexColor(hex);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 3,
                )
              : null,
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(color: color, blurRadius: 0, spreadRadius: 2),
                ]
              : null,
        ),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: color,
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : null,
        ),
      ),
    );
  }
}

/// Result of the map location picker: null point = remove location.
class LocationPickResult {
  const LocationPickResult(this.point, {this.addressLabel});

  final LatLng? point;
  final String? addressLabel;
}

/// Bottom sheet with address search (Nominatim) + interactive map pin.
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({
    this.initial,
    this.initialQuery = '',
    this.geocoder = const NominatimGeocoder(),
    super.key,
  });

  final LatLng? initial;
  final String initialQuery;
  final NominatimGeocoder geocoder;

  @override
  State<LocationPickerSheet> createState() => LocationPickerSheetState();
}

class LocationPickerSheetState extends State<LocationPickerSheet> {
  final MapController _mapController = MapController();
  late final TextEditingController _queryController;
  Timer? _debounce;
  LatLng? _picked;
  String? _pickedLabel;
  List<AddressSuggestion> _suggestions = const <AddressSuggestion>[];
  bool _searching = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
    _queryController = TextEditingController(text: widget.initialQuery);
    if (_picked == null && widget.initialQuery.trim().length >= 3) {
      unawaited(_runSearch(widget.initialQuery, autoSelectFirst: true));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _suggestions = const <AddressSuggestion>[];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _runSearch(value),
    );
  }

  Future<void> _runSearch(String value, {bool autoSelectFirst = false}) async {
    final List<AddressSuggestion> results = await widget.geocoder.search(value);
    if (!mounted) return;
    if (autoSelectFirst && results.isNotEmpty && _picked == null) {
      _selectSuggestion(results.first, keepRemaining: results.length > 1);
      if (results.length > 1) {
        setState(() {
          _suggestions = results;
          _searching = false;
        });
      }
      return;
    }
    setState(() {
      _suggestions = results;
      _searching = false;
    });
  }

  void _selectSuggestion(
    AddressSuggestion suggestion, {
    bool keepRemaining = false,
  }) {
    FocusScope.of(context).unfocus();
    setState(() {
      _picked = suggestion.point;
      _pickedLabel = suggestion.shortLabel;
      _queryController.text = suggestion.shortLabel;
      if (!keepRemaining) {
        _suggestions = const <AddressSuggestion>[];
      }
      _searching = false;
    });
    if (_mapReady) {
      _mapController.move(suggestion.point, 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppTokens tokens = context.tokens;
    final double height = MediaQuery.sizeOf(context).height * 0.84;
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Ubicación del local',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Escribí la dirección y elegila de la lista, o tocá el mapa para ajustar el pin.',
                  style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _queryController,
                  textInputAction: TextInputAction.search,
                  onChanged: _onQueryChanged,
                  onSubmitted: (String v) =>
                      _runSearch(v, autoSelectFirst: true),
                  decoration: InputDecoration(
                    hintText: 'Ej: Yatay 448, Valentín Alsina',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_queryController.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Limpiar',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _queryController.clear();
                                    _onQueryChanged('');
                                  },
                                )
                              : null),
                  ),
                ),
              ],
            ),
          ),
          if (_suggestions.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 196),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Material(
                  color: tokens.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: tokens.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: tokens.border),
                    itemBuilder: (BuildContext context, int index) {
                      final AddressSuggestion item = _suggestions[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.place_outlined,
                          color: scheme.primary,
                        ),
                        title: Text(
                          item.shortLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                        onTap: () => _selectSuggestion(item),
                      );
                    },
                  ),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _picked ?? const LatLng(-34.6, -58.4),
                    initialZoom: _picked != null ? 16 : 11,
                    onMapReady: () {
                      _mapReady = true;
                      if (_picked != null) {
                        _mapController.move(_picked!, 16);
                      }
                    },
                    onTap: (_, LatLng latLng) => setState(() {
                      _picked = latLng;
                      _suggestions = const <AddressSuggestion>[];
                    }),
                  ),
                  children: <Widget>[
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.allgorithm.allcommerce',
                    ),
                    if (_picked != null)
                      MarkerLayer(
                        markers: <Marker>[
                          Marker(
                            point: _picked!,
                            width: 40,
                            height: 48,
                            child: Icon(
                              Icons.location_on_rounded,
                              color: scheme.primary,
                              size: 44,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              16 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: Row(
              children: <Widget>[
                if (_picked != null || widget.initial != null) ...<Widget>[
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .pop(const LocationPickResult(null)),
                    child: const Text('Quitar ubicación'),
                  ),
                  const SizedBox(width: 12),
                ],
                // Expanded: FilledButton has infinite min width via theme
                // and crashes inside an unbounded Row.
                Expanded(
                  child: FilledButton(
                    onPressed: _picked == null
                        ? null
                        : () => Navigator.of(context).pop(
                            LocationPickResult(
                              _picked,
                              addressLabel: _pickedLabel,
                            ),
                          ),
                    child: const Text('Usar esta ubicación'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One discount rule row: full label on the left, small value field right.
class _DiscountField extends StatelessWidget {
  const _DiscountField({
    required this.label,
    required this.icon,
    required this.controller,
    this.prefix,
    this.suffix,
    this.hint,
    this.onChanged,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? prefix;
  final String? suffix;
  final String? hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: tokens.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: tokens.textPrimary),
            ),
          ),
          SizedBox(
            width: 108,
            child: TextFormField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                prefixText: prefix,
                suffixText: suffix,
                hintText: hint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live plain-language summary of the configured discounts.
class _DiscountsSummary extends StatelessWidget {
  const _DiscountsSummary({
    required this.cash,
    required this.transfer,
    required this.mp,
    required this.bulkMin,
    required this.bulkPct,
  });

  final TextEditingController cash;
  final TextEditingController transfer;
  final TextEditingController mp;
  final TextEditingController bulkMin;
  final TextEditingController bulkPct;

  static double _val(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final List<String> parts = <String>[
      if (_val(cash) > 0) 'Efectivo −${_val(cash).toStringAsFixed(0)}%',
      if (_val(transfer) > 0)
        'Transferencia −${_val(transfer).toStringAsFixed(0)}%',
      if (_val(mp) > 0) 'Mercado Pago −${_val(mp).toStringAsFixed(0)}%',
      if (_val(bulkMin) > 0 && _val(bulkPct) > 0)
        'Pedidos ≥ ${Formatters.price(_val(bulkMin))} '
            '→ −${_val(bulkPct).toStringAsFixed(0)}%',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            parts.isEmpty ? Icons.remove_circle_outline : Icons.check_circle,
            size: 15,
            color: parts.isEmpty ? tokens.textTertiary : tokens.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              parts.isEmpty
                  ? 'Sin descuentos: dejá los campos vacíos o en 0'
                  : parts.join('  ·  '),
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: parts.isEmpty ? FontWeight.w400 : FontWeight.w600,
                color: parts.isEmpty ? tokens.textTertiary : tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
