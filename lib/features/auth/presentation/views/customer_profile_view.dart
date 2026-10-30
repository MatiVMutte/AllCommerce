import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/utils/validators.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/auth/presentation/widgets/auth_layout.dart';
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
                      title: 'Tu perfil',
                      subtitle: 'Solo necesitamos tu nombre para tus pedidos',
                    ),
                    const SizedBox(height: 32),
                    LabeledField(
                      label: 'Nombre completo',
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
                      label: 'WhatsApp (opcional)',
                      child: TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: '11 2233 4455',
                          helperText: 'Lo pedimos al confirmar un pedido',
                        ),
                        validator: (String? value) {
                          if ((value ?? '').trim().isEmpty) {
                            return null;
                          }
                          return Validators.phone(value);
                        },
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
                          : const Text('Continuar'),
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
