import 'package:all_commerce/core/services/nominatim_geocoder.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/theme/app_brand.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/share_service.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/utils/validators.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/auth/presentation/widgets/auth_layout.dart';
import 'package:all_commerce/features/store/presentation/widgets/store_qr_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 3-step owner onboarding: intro → store form → live catalog with QR.
/// The first product is NOT forced here — the owner can add it later from
/// the catalog tab or the AI assistant.
class BusinessOnboardingView extends ConsumerStatefulWidget {
  const BusinessOnboardingView({super.key});

  @override
  ConsumerState<BusinessOnboardingView> createState() =>
      _BusinessOnboardingViewState();
}

class _BusinessOnboardingViewState
    extends ConsumerState<BusinessOnboardingView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _storeName = TextEditingController();
  final TextEditingController _slug = TextEditingController();
  final TextEditingController _whatsapp = TextEditingController();
  final TextEditingController _address = TextEditingController();
  bool _slugEdited = false;
  int _step = 0;
  TenantModel? _created;

  @override
  void initState() {
    super.initState();
    final UserModel? existing = ref.read(currentProfileProvider).value;
    if (existing != null) {
      _fullName.text = existing.fullName;
      if (existing.phone != null && existing.phone!.isNotEmpty) {
        _whatsapp.text = existing.phone!;
      }
    }
    _storeName.addListener(() {
      if (!_slugEdited) {
        _slug.value = TextEditingValue(
          text: Validators.slugify(_storeName.text),
          selection: TextSelection.collapsed(
            offset: Validators.slugify(_storeName.text).length,
          ),
        );
      }
    });
    _slug.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fullName.dispose();
    _storeName.dispose();
    _slug.dispose();
    _whatsapp.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final String address = _address.text.trim();
    double? lat;
    double? lng;
    if (address.length >= 4) {
      final List<AddressSuggestion> found = await const NominatimGeocoder()
          .search(address);
      if (found.isNotEmpty) {
        lat = found.first.point.latitude;
        lng = found.first.point.longitude;
      }
    }
    final TenantModel? tenant = await ref
        .read(authControllerProvider.notifier)
        .createTenant(
          slug: _slug.text.trim(),
          name: _storeName.text.trim(),
          whatsapp: Validators.normalizePhone(_whatsapp.text),
          address: address.isEmpty ? null : address,
          fullName: _fullName.text.trim(),
          lat: lat,
          lng: lng,
        );
    if (tenant == null && mounted) {
      final Object? error = ref.read(authControllerProvider).error;
      if (error != null) showErrorSnackBar(context, error);
      return;
    }
    if (tenant != null && mounted) {
      setState(() => _created = tenant);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TenantModel? created = _created;
    if (created != null) {
      return _SuccessStep(tenant: created);
    }
    return _step == 0
        ? _IntroStep(onStart: () => setState(() => _step = 1))
        : _formStep();
  }

  Widget _formStep() {
    final AppTokens tokens = context.tokens;
    final bool loading = ref.watch(authControllerProvider).isLoading;
    final bool hasCustomerProfile =
        ref.watch(currentProfileProvider).value != null;
    final bool slugValid =
        Validators.slug(_slug.text.trim()) == null &&
        _slug.text.trim().isNotEmpty;
    return AuthScaffold(
      showBack: true,
      backFallback: hasCustomerProfile ? '/profile' : '/',
      leading: BackButton(onPressed: () => setState(() => _step = 0)),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const AuthHeader(
              title: 'Creá tu local',
              subtitle: 'Tu catálogo queda online en un minuto',
            ),
            const SizedBox(height: 32),
            LabeledField(
              label: 'Tu nombre',
              child: TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(hintText: 'Ana López'),
                validator: Validators.fullName,
              ),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Nombre del local',
              child: TextFormField(
                controller: _storeName,
                decoration: const InputDecoration(hintText: 'Bazar Don Pepe'),
                validator: Validators.storeName,
              ),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Link de tu catálogo',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextFormField(
                    controller: _slug,
                    decoration: InputDecoration(
                      hintText: 'tu-local',
                      prefixIcon: Icon(
                        Icons.link_rounded,
                        size: 20,
                        color: tokens.textTertiary,
                      ),
                      suffixIcon: slugValid
                          ? Icon(
                              Icons.check_circle_rounded,
                              size: 20,
                              color: tokens.success,
                            )
                          : null,
                    ),
                    onChanged: (_) => _slugEdited = true,
                    validator: Validators.slug,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${ShareService.linkBase}/s/'
                    '${_slug.text.trim().isEmpty ? 'tu-local' : _slug.text.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: slugValid
                          ? Theme.of(context).colorScheme.primary
                          : tokens.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'WhatsApp del local',
              child: TextFormField(
                controller: _whatsapp,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '11 2233 4455',
                  helperText: 'Con código de área, sin 0 ni 15',
                ),
                validator: Validators.phone,
              ),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Dirección (opcional)',
              child: TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  hintText: 'Av. Siempre Viva 742',
                  helperText:
                      'Dejalo vacío si vendés online o coordinás la entrega',
                ),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: loading ? null : _submit,
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crear mi local'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 0 — what you get, in three bullets, before asking for data.
class _IntroStep extends StatelessWidget {
  const _IntroStep({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 8),
          const BrandIconBadge(icon: Icons.storefront_rounded, size: 80),
          const SizedBox(height: 20),
          Text(
            'Tu local online en 3 pasos',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Catálogo propio, pedidos por WhatsApp y una IA que te ayuda a cargar productos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          _IntroBullet(
            icon: Icons.link_rounded,
            color: scheme.primary,
            title: 'Tu link y tu QR',
            subtitle: 'Compartilo por WhatsApp o pegalo en la vidriera.',
          ),
          _IntroBullet(
            icon: Icons.inventory_2_outlined,
            color: scheme.primary,
            title: 'Catálogo con precios y stock',
            subtitle: 'Los clientes arman el pedido solos, sin llamarte.',
          ),
          _IntroBullet(
            icon: Icons.auto_awesome,
            color: scheme.primary,
            title: 'IA que te ahorra tiempo',
            subtitle: 'Una foto → título, descripción y precio sugerido.',
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: onStart, child: const Text('Empezar')),
          const SizedBox(height: 8),
          Text(
            'Gratis para empezar · sin tarjeta',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: tokens.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _IntroBullet extends StatelessWidget {
  const _IntroBullet({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: tokens.textSecondary,
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

/// Step 2 — the catalog is live. QR + link + optional next actions.
class _SuccessStep extends StatelessWidget {
  const _SuccessStep({required this.tenant});

  final TenantModel tenant;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String url = ShareService.catalogUrl(tenant.slug);
    return AuthScaffold(
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 8),
          const BrandIconBadge(
            icon: Icons.check_circle_outline_rounded,
            size: 80,
          ),
          const SizedBox(height: 18),
          Text(
            '¡${tenant.name} ya está online!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Este es tu catálogo: compartilo por WhatsApp o imprimí el QR para la vidriera.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tokens.border),
              ),
              child: QrImageView(
                data: url,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                showAppSnackBar(context, 'Link copiado');
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      url,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.copy_rounded, size: 16, color: scheme.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () => showStoreQrSheet(context, tenant),
            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
            label: const Text('Descargar QR para imprimir'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => context.go('/owner'),
            child: const Text('Ir a mi panel'),
          ),
          const SizedBox(height: 8),
          Text(
            'Después podés cargar productos a mano o con una foto desde la pestaña IA.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: tokens.textTertiary),
          ),
        ],
      ),
    );
  }
}
