import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/utils/validators.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomerProfileView extends ConsumerStatefulWidget {
  const CustomerProfileView({super.key});

  @override
  ConsumerState<CustomerProfileView> createState() =>
      _CustomerProfileViewState();
}

class _CustomerProfileViewState extends ConsumerState<CustomerProfileView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _phone = TextEditingController();

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final String phone = _phone.text.trim();
    final bool ok = await ref
        .read(authControllerProvider.notifier)
        .createCustomerProfile(
          fullName: _fullName.text.trim(),
          phone: phone.isEmpty ? null : Validators.normalizePhone(phone),
        );
    if (!ok && mounted) {
      final Object? error = ref.read(authControllerProvider).error;
      if (error != null) showErrorSnackBar(context, error);
    }
    // On success the router redirect takes it to '/'.
  }

  @override
  Widget build(BuildContext context) {
    final bool loading = ref.watch(authControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Tu perfil')),
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
                  decoration:
                      const InputDecoration(labelText: 'Nombre completo'),
                  validator: Validators.fullName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp (opcional)',
                    helperText: 'Lo pedimos al confirmar un pedido',
                  ),
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) return null;
                    return Validators.phone(value);
                  },
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
                      : const Text('Continuar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
