import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/utils/validators.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final TenantModel? tenant = await ref
        .read(authControllerProvider.notifier)
        .createTenant(
          slug: _slug.text.trim(),
          name: _storeName.text.trim(),
          whatsapp: Validators.normalizePhone(_whatsapp.text),
          address: address.isEmpty ? null : address,
          fullName: _fullName.text.trim(),
        );
    if (tenant == null && mounted) {
      final Object? error = ref.read(authControllerProvider).error;
      if (error != null) showErrorSnackBar(context, error);
    }
    // On success the router redirect takes it to '/owner'.
  }

  @override
  Widget build(BuildContext context) {
    final bool loading = ref.watch(authControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Creá tu local'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _fullName,
                  decoration: const InputDecoration(labelText: 'Tu nombre'),
                  validator: Validators.fullName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _storeName,
                  decoration:
                      const InputDecoration(labelText: 'Nombre del local'),
                  validator: Validators.storeName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _slug,
                  decoration: const InputDecoration(
                    labelText: 'Link de tu catálogo',
                    prefixText: 'allcommerce.app/s/',
                  ),
                  onChanged: (_) => _slugEdited = true,
                  validator: Validators.slug,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _whatsapp,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp del local',
                    helperText: 'Con código de área, sin 0 ni 15',
                  ),
                  validator: Validators.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _address,
                  decoration:
                      const InputDecoration(labelText: 'Dirección (opcional)'),
                ),
                const SizedBox(height: 24),
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
    );
  }
}
