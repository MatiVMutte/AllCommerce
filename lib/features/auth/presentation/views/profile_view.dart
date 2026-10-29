import 'package:all_commerce/core/router/customer_mode.dart';
import 'package:all_commerce/core/router/return_to.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/widgets/app_card.dart';
import 'package:all_commerce/core/widgets/app_confirm_sheet.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref, {
    required bool isOwner,
  }) async {
    final bool? confirmed = await showAppConfirmSheet(
      context,
      title: '¿Eliminar tu cuenta?',
      message: isOwner
          ? 'Se eliminará tu cuenta, tu local, todos tus productos y los pedidos recibidos. Esta acción no se puede deshacer.'
          : 'Se eliminará tu cuenta y tus datos personales de forma permanente. Esta acción no se puede deshacer.',
      confirmLabel: 'Sí, eliminar mi cuenta',
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    final bool ok =
        await ref.read(authControllerProvider.notifier).deleteAccount();
    if (!context.mounted) return;
    if (!ok) {
      final Object? error = ref.read(authControllerProvider).error;
      if (error != null) showErrorSnackBar(context, error);
      return;
    }
    showAppSnackBar(context, 'Tu cuenta fue eliminada');
    context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final Session? session = ref.watch(sessionProvider);
    if (session == null) {
      return Scaffold(
        body: SafeArea(
          bottom: false,
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
                      Icons.person_outline_rounded,
                      size: 36,
                      color: tokens.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tu perfil',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingresá para ver tus pedidos y guardar tus datos',
                    style: TextStyle(color: tokens.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        ref.read(returnToProvider.notifier).set('/profile');
                        context.push('/login');
                      },
                      child: const Text('Ingresar'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(returnToProvider.notifier).set('/profile');
                        context.push('/register');
                      },
                      child: const Text('Crear cuenta'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => context.push('/terms'),
                        child: const Text('Términos y condiciones'),
                      ),
                      TextButton(
                        onPressed: () => context.push('/privacy'),
                        child: const Text('Privacidad'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final AsyncValue<UserModel?> profileAsync = ref.watch(
      currentProfileProvider,
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace s) =>
              const Center(child: Text('Ocurrió un error')),
          data: (UserModel? profile) {
            final String name =
                profile?.fullName ?? session.user.email ?? 'Tu cuenta';
            final String? phone = profile?.phone;
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
              children: <Widget>[
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    session.user.email ?? '',
                    style: TextStyle(color: tokens.textSecondary),
                  ),
                ),
                if (phone != null)
                  Center(
                    child: Text(
                      'WhatsApp $phone',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                  ),
                const SizedBox(height: 32),
                if (profile != null && profile.isOwner) ...<Widget>[
                  AppCard(
                    onTap: () {
                      ref
                          .read(customerModeProvider.notifier)
                          .exitCustomerMode();
                      context.go('/owner');
                    },
                    child: Row(
                      children: <Widget>[
                        CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Panel de mi negocio',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              Text(
                                'Administrá tus productos, pedidos y ventas',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (profile != null && !profile.isOwner) ...<Widget>[
                  AppCard(
                    onTap: () => context.push('/onboarding/business'),
                    child: Row(
                      children: <Widget>[
                        CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '¿Tenés un comercio?',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              Text(
                                'Creá tu catálogo gratis con IA en 1 minuto',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Card(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: const Text('Mis pedidos'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/my-orders'),
                      ),
                      if (profile?.isAdmin ?? false)
                        ListTile(
                          leading: const Icon(
                            Icons.admin_panel_settings_outlined,
                          ),
                          title: const Text('Administración'),
                          trailing:
                              const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/admin'),
                        ),
                      ListTile(
                        leading: const Icon(Icons.dark_mode_outlined),
                        title: const Text('Tema'),
                        subtitle: const Text('Sigue al sistema'),
                        trailing: Switch(
                          value:
                              Theme.of(context).brightness == Brightness.dark,
                          onChanged: null,
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('Términos y condiciones'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/terms'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Política de privacidad'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/privacy'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                    child: const Text('Cerrar sesión'),
                  ),
                ),
                if (!(profile?.isAdmin ?? false))
                  Center(
                    child: TextButton(
                      onPressed: () => _confirmDeleteAccount(
                        context,
                        ref,
                        isOwner: profile?.isOwner ?? false,
                      ),
                      child: Text(
                        'Eliminar mi cuenta',
                        style: TextStyle(color: tokens.danger, fontSize: 13),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
