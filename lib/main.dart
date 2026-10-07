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
  }

  @override
  void dispose() {
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
    );
  }
}
