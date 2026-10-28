import 'dart:async';

import 'package:all_commerce/core/constants/app_config.dart';
import 'package:all_commerce/core/firebase/firebase_messaging_service.dart';
import 'package:all_commerce/core/router/app_router.dart';
import 'package:all_commerce/core/router/parent_path.dart';
import 'package:all_commerce/core/storage/shared_preferences_provider.dart';
import 'package:all_commerce/core/theme/app_theme.dart';
import 'package:all_commerce/core/widgets/app_confirm_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  unawaited(FirebaseMessagingService.instance.initialize());
  // Que el framework reciba SIEMPRE el botón atrás (Android 15+ no se lo
  // entrega si el Navigator no reporta canHandlePop). Sin esto, atrás en
  // una pantalla raíz cierra la app sin pasar por didPopRoute.
  unawaited(SystemNavigator.setFrameworkHandlesBack(true));
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const AllCommerceApp(),
    ),
  );
}

class AllCommerceApp extends ConsumerStatefulWidget {
  const AllCommerceApp({super.key});

  @override
  ConsumerState<AllCommerceApp> createState() => _AllCommerceAppState();
}

class _AllCommerceAppState extends ConsumerState<AllCommerceApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Registered before the Router's RootBackButtonDispatcher (created
    // when MaterialApp builds below us), so handlePopRoute hits us first.
    WidgetsBinding.instance.addObserver(this);
    _splashTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  Timer? _splashTimer;
  bool _showSplash = true;

  @override
  void dispose() {
    _splashTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Android back button/gesture without navigation history: go to the
  /// parent route instead of closing the app.
  @override
  Future<bool> didPopRoute() async {
    final GoRouter router = ref.read(routerProvider);
    if (router.canPop()) {
      router.pop();
      return true;
    }
    final String loc =
        router.routerDelegate.currentConfiguration.uri.path;
    final String? parent = parentPathOf(loc);
    if (parent != null) {
      router.go(parent);
      return true;
    }
    // En una pantalla raíz Android cerraría la app: pedir confirmación.
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    final BuildContext? ctx =
        router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return false;
    final bool exit = await showAppConfirmSheet(
          ctx,
          title: '¿Salir de AllCommerce?',
          message: '¿Seguro que querés salir de la aplicación?',
          confirmLabel: 'Salir',
        ) ??
        false;
    if (exit) await SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      // El Navigator re-evalúa canHandlePop en cada cambio de historial y
      // volvería a false en la raíz; lo anclamos en true para que el
      // sistema siempre delegue el atrás en didPopRoute.
      onNavigationNotification: (NavigationNotification _) {
        unawaited(SystemNavigator.setFrameworkHandlesBack(true));
        return true;
      },
      builder: (BuildContext context, Widget? child) {
        return Stack(
          children: <Widget>[
            ?child,
            IgnorePointer(
              ignoring: !_showSplash,
              child: AnimatedOpacity(
                opacity: _showSplash ? 1 : 0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: const _BrandSplashOverlay(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BrandSplashOverlay extends StatelessWidget {
  const _BrandSplashOverlay();

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool wide = size.width >= 720;
    return Material(
      color: const Color(0xFF0052FF),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.15,
                colors: <Color>[
                  Color(0xFF1F6BFF),
                  Color(0xFF0052FF),
                  Color(0xFF0037B3),
                ],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: wide ? const _WideBrandSplash() : const _CompactBrandSplash(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactBrandSplash extends StatelessWidget {
  const _CompactBrandSplash();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _BrandLogoTile(size: 76, iconSize: 40, radius: 22),
        const SizedBox(height: 16),
        const Text(
          'AllCommerce',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tu catálogo inteligente',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _WideBrandSplash extends StatelessWidget {
  const _WideBrandSplash();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _BrandLogoTile(size: 88, iconSize: 46, radius: 24),
          const SizedBox(width: 24),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.auto_awesome,
                        size: 13,
                        color: Colors.white,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'IMPULSADO CON IA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'AllCommerce',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tu catálogo inteligente y pedidos por WhatsApp',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
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

class _BrandLogoTile extends StatelessWidget {
  const _BrandLogoTile({
    required this.size,
    required this.iconSize,
    required this.radius,
  });

  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        Icons.shopping_bag_rounded,
        size: iconSize,
        color: const Color(0xFF0052FF),
      ),
    );
  }
}
