import 'package:all_commerce/core/router/customer_mode.dart';
import 'package:all_commerce/core/router/return_to.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/utils/validators.dart';
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
    final bool ok = await ref
        .read(authControllerProvider.notifier)
        .deleteAccount();
    if (!context.mounted) return;
    if (!ok) {
      final Object? error = ref.read(authControllerProvider).error;
      if (error != null) showErrorSnackBar(context, error);
      return;
    }
    showAppSnackBar(context, 'Tu cuenta fue eliminada');
    context.go('/');
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    UserModel profile,
  ) async {
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditProfileSheet(profile: profile),
    );
    if (saved == true && context.mounted) {
      showAppSnackBar(context, 'Datos actualizados');
    }
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
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary,
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
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary,
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
                      if (profile != null)
                        ListTile(
                          leading: const Icon(Icons.edit_outlined),
                          title: const Text('Editar mis datos'),
                          subtitle: const Text('Nombre y WhatsApp'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _editProfile(context, ref, profile),
                        ),
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
                          trailing: const Icon(Icons.chevron_right_rounded),
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

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});

  final UserModel profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.fullName);
    _phone = TextEditingController(text: widget.profile.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final String rawPhone = _phone.text.trim();
    final String? cleanPhone = rawPhone.isEmpty
        ? null
        : Validators.normalizePhone(rawPhone);
    final bool ok = await ref
        .read(authControllerProvider.notifier)
        .updateProfile(fullName: _name.text.trim(), phone: cleanPhone);
    if (!mounted) return;
    if (!ok) {
      final Object? error = ref.read(authControllerProvider).error;
      if (error != null) showErrorSnackBar(context, error);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bool loading = ref.watch(authControllerProvider).isLoading;
    final EdgeInsets insets = MediaQuery.viewInsetsOf(context);
    final double bottomPad = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        20 + (insets.bottom > 0 ? insets.bottom : bottomPad),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Editar mis datos',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Tu nombre',
              ),
              validator: Validators.fullName,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp',
                hintText: '5491122334455',
              ),
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? null : Validators.phone(v),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: loading ? null : _save,
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
