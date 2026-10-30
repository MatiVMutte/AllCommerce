import 'package:all_commerce/core/services/nominatim_geocoder.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/share_service.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/utils/validators.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/auth/presentation/widgets/auth_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      context.go('/owner');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final bool loading = ref.watch(authControllerProvider).isLoading;
    final bool hasCustomerProfile =
        ref.watch(currentProfileProvider).value != null;
    final bool slugValid =
        Validators.slug(_slug.text.trim()) == null &&
        _slug.text.trim().isNotEmpty;
    return Scaffold(
      appBar: hasCustomerProfile
          ? AppBar(leading: const AppBackButton(fallback: '/profile'))
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
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
                        decoration: const InputDecoration(
                          hintText: 'Ana López',
                        ),
                        validator: Validators.fullName,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LabeledField(
                      label: 'Nombre del local',
                      child: TextFormField(
                        controller: _storeName,
                        decoration: const InputDecoration(
                          hintText: 'Bazar Don Pepe',
                        ),
                        validator: Validators.storeName,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LabeledField(
                      label: 'Link de tu catálogo',
                      child: Container(
                        decoration: BoxDecoration(
                          color: tokens.surfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: <Widget>[
                            Text(
                              '${ShareService.linkBase}/s/',
                              style: TextStyle(
                                color: tokens.textTertiary,
                                fontSize: 13,
                              ),
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: _slug,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  filled: false,
                                  hintText: 'tu-local',
                                  isDense: true,
                                ),
                                onChanged: (_) => _slugEdited = true,
                                validator: Validators.slug,
                              ),
                            ),
                            if (slugValid)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                                color: tokens.success,
                              ),
                          ],
                        ),
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
            ),
          ),
        ),
      ),
    );
  }
}
