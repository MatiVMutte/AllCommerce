import 'dart:async';

import 'package:all_commerce/core/constants/app_config.dart';
import 'package:all_commerce/core/firebase/firebase_messaging_service.dart';
import 'package:all_commerce/core/router/app_router.dart';
import 'package:all_commerce/core/router/parent_path.dart';
import 'package:all_commerce/core/storage/shared_preferences_provider.dart';
import 'package:all_commerce/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
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
    if (parent == null) return false;
    router.go(parent);
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
    return Material(
      color: const Color(0xFF0052FF),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_bag_rounded,
                size: 40,
                color: Color(0xFF0052FF),
              ),
            ),
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
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
