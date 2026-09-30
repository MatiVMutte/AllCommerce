import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/utils/validators.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/auth/presentation/widgets/auth_layout.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  ConsumerState<ForgotPasswordView> createState() =>
      _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final bool ok = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_email.text.trim());
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si el email existe, te enviamos un link para recuperar la '
            'contraseña.',
          ),
        ),
      );
    } else {
      final Object? error = ref.read(authControllerProvider).error;
      if (error != null) showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool loading = ref.watch(authControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(fallback: '/')),
      body: Center(
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
                    title: 'Recuperar contraseña',
                    subtitle:
                        'Te enviamos un link para elegir una nueva',
                  ),
                  const SizedBox(height: 32),
                  LabeledField(
                    label: 'Email',
                    child: TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'tu@email.com',
                      ),
                      validator: Validators.email,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: loading ? null : _submit,
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Enviar link'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
