import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/utils/validators.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
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
  ConsumerState<TenantSettingsView> createState() =>
      _TenantSettingsViewState();
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
          address:
              _address.text.trim().isEmpty ? null : _address.text.trim(),
          whatsapp: Validators.normalizePhone(_whatsapp.text),
          primaryColor: _color,
        );
    if (!mounted) return;
    if (updated == null) {
      final Object? error = ref.read(tenantSettingsControllerProvider).error;
      if (error != null) showErrorSnackBar(context, error);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local actualizado')),
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/owner');
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserModel? profile = ref.watch(currentProfileProvider).value;
    final String? tenantId = profile?.tenantId;
    final TenantSettingsState state =
        ref.watch(tenantSettingsControllerProvider);
    if (tenantId == null) {
      return const Scaffold(
        body: Center(child: Text(AppStrings.genericError)),
      );
    }
    final AsyncValue<TenantModel?> tenantAsync =
        ref.watch(tenantByIdProvider(tenantId));
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/owner'),
        title: const Text('Configuración'),
      ),
      body: tenantAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace s) =>
            const Center(child: Text(AppStrings.genericError)),
        data: (TenantModel? tenant) {
          if (tenant == null) {
            return const Center(child: Text(AppStrings.storeNotFound));
          }
          if (!_initialized) _init(tenant);
          final List<String> colors = _palette.contains(_color)
              ? _palette
              : <String>[..._palette, _color];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    24 + FloatingNavBar.height,
                  ),
                  children: <Widget>[
                    Center(
                      child: Column(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: tenant.primaryColorValue,
                            foregroundColor: Colors.white,
                            child: state.pendingLogo != null
                                ? ClipOval(
                                    child: Image.memory(
                                      state.pendingLogo!,
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : tenant.logoUrl == null
                                    ? Text(
                                        tenant.name.characters.first
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 32,
                                        ),
                                      )
                                    : ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: tenant.logoUrl!,
                                          width: 96,
                                          height: 96,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, _, _) => Text(
                                            tenant.name.characters.first
                                                .toUpperCase(),
                                          ),
                                        ),
                                      ),
                          ),
                          TextButton(
                            onPressed: state.saving
                                ? null
                                : () => ref
                                    .read(
                                      tenantSettingsControllerProvider
                                          .notifier,
                                    )
                                    .pickLogo(),
                            child: const Text('Cambiar logo'),
                          ),
                        ],
                      ),
                    ),
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
                    const SizedBox(height: 16),
                    const Text('Color principal'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
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
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Tu link: allcommerce.app/s/${tenant.slug}',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_outlined),
                          tooltip: 'Copiar link',
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text:
                                    'allcommerce.app/s/${tenant.slug}',
                              ),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Link copiado'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed:
                          state.saving ? null : () => _save(tenant),
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
                  ],
                ),
              ),
            ),
          );
        },
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
    final String digits = hex.replaceFirst('#', '');
    final Color color =
        Color(0xFF000000 | (int.tryParse(digits, radix: 16) ?? 0));
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: CircleAvatar(
        radius: 18,
        backgroundColor: color,
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
