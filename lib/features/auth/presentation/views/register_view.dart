import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/utils/validators.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/auth/presentation/widgets/auth_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;
  bool _awaitingConfirmation = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final SignUpResult result = await ref
        .read(authControllerProvider.notifier)
        .signUp(email: _email.text.trim(), password: _password.text);
    if (!mounted) return;
    switch (result) {
      case SignUpResult.signedIn:
        break; // the router redirect takes it from here
      case SignUpResult.needsEmailConfirmation:
        setState(() => _awaitingConfirmation = true);
      case SignUpResult.failed:
        final Object? error = ref.read(authControllerProvider).error;
        if (error != null) showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    if (_awaitingConfirmation) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: tokens.surfaceMuted,
                    child: Icon(
                      Icons.mark_email_read_outlined,
                      size: 36,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Revisá tu email',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Te enviamos un email para confirmar tu cuenta. '
                    'Después ingresá con tu email y contraseña.',
                    style: TextStyle(color: tokens.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('Ir a ingresar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
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
                    title: 'Creá tu cuenta',
                    subtitle: 'Un email y una contraseña alcanzan para empezar',
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
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Contraseña',
                    child: TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: 'Mínimo 8 caracteres',
                        suffixIcon: IconButton(
                          tooltip: _obscure
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: tokens.textSecondary,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: Validators.password,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Repetir contraseña',
                    child: TextFormField(
                      controller: _confirm,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        hintText: 'Repetí tu contraseña',
                      ),
                      validator: (String? value) =>
                          Validators.confirmPassword(value, _password.text),
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
                        : const Text('Crear cuenta'),
                  ),
                  TextButton(
                    onPressed: () => context.push('/login'),
                    child: const Text('Ya tengo cuenta'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      Text(
                        'Al registrarte aceptás los ',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                        ),
                      ),
                      InkWell(
                        onTap: () => context.push('/terms'),
                        child: Text(
                          'Términos',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      Text(
                        ' y la ',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                        ),
                      ),
                      InkWell(
                        onTap: () => context.push('/privacy'),
                        child: Text(
                          'Política de privacidad',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
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
