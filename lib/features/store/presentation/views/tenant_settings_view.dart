import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:all_commerce/core/utils/share_service.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/utils/validators.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/store/presentation/view_models/tenant_settings_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  String _color = '#0052FF';
  bool _initialized = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _address.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  void _init(TenantModel tenant) {
    _name.text = tenant.name;
    _description.text = tenant.description ?? '';
    _address.text = tenant.address ?? '';
    // Show the local part without the 549 prefix when possible.
    final String w = tenant.whatsapp;
    _whatsapp.text = w.startsWith('549') ? w.substring(3) : w;
    _color = tenant.primaryColor;
    _initialized = true;
    _name.addListener(_onChange);
    _description.addListener(_onChange);
    _address.addListener(_onChange);
    _whatsapp.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  bool _isDirty(TenantModel tenant, bool hasPendingLogo) {
    final String w = tenant.whatsapp;
    final String currentPhone = w.startsWith('549') ? w.substring(3) : w;
    return hasPendingLogo ||
        _name.text.trim() != tenant.name ||
        _description.text.trim() != (tenant.description ?? '') ||
        _address.text.trim() != (tenant.address ?? '') ||
        _whatsapp.text.trim() != currentPhone ||
        _color != tenant.primaryColor;
  }

  Future<void> _save(TenantModel tenant) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final TenantModel? updated = await ref
        .read(tenantSettingsControllerProvider.notifier)
        .save(
          tenant,
          name: _name.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          whatsapp: Validators.normalizePhone(_whatsapp.text),
          primaryColor: _color,
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
            final bool dirty = _isDirty(tenant, state.pendingLogo != null);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      24 + FloatingNavBar.height,
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
                      Center(
                        child: Column(
                          children: <Widget>[
                            Stack(
                              children: <Widget>[
                                _SettingsAvatar(
                                  tenant: tenant,
                                  pendingLogo: state.pendingLogo,
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
                      const SizedBox(height: 24),
                      const _Section('DATOS'),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 4),
                      const _Section('CONTACTO'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _address,
                        decoration: const InputDecoration(
                          labelText: 'Dirección (opcional)',
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
                      const SizedBox(height: 4),
                      const _Section('APARIENCIA'),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '${ShareService.linkBase}/s/${tenant.slug}',
                              style: TextStyle(color: tokens.textSecondary),
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

class _SettingsAvatar extends StatelessWidget {
  const _SettingsAvatar({required this.tenant, this.pendingLogo});

  final TenantModel tenant;
  final Uint8List? pendingLogo;

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
        : CachedNetworkImage(
            imageUrl: tenant.logoUrl!,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => Center(
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
      child: child,
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
