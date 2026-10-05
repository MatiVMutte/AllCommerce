import 'dart:async';

import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/features/billing/data/repositories/ai_usage_repository.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
  (Ref ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final StreamProvider<AuthState> authStateProvider = StreamProvider<AuthState>(
  (Ref ref) => ref.watch(authRepositoryProvider).onAuthStateChange,
);

final Provider<Session?> sessionProvider = Provider<Session?>((Ref ref) {
  final AsyncValue<AuthState> authState = ref.watch(authStateProvider);
  return authState.value?.session ??
      ref.read(authRepositoryProvider).currentSession;
});

final FutureProvider<UserModel?> currentProfileProvider =
    FutureProvider<UserModel?>((Ref ref) {
  final Session? session = ref.watch(sessionProvider);
  if (session == null) return null;
  return ref.watch(authRepositoryProvider).fetchProfile();
});

enum SignUpResult { signedIn, needsEmailConfirmation, failed }

class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData<void>(null);

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading<void>();
    final AsyncValue<void> result = await AsyncValue.guard(
      () => _repository.signIn(email: email, password: password),
    );
    state = result;
    return !result.hasError;
  }

  Future<SignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading<void>();
    bool signedIn = false;
    final AsyncValue<void> result = await AsyncValue.guard(() async {
      signedIn = await _repository.signUp(email: email, password: password);
    });
    state = result;
    if (result.hasError) return SignUpResult.failed;
    return signedIn
        ? SignUpResult.signedIn
        : SignUpResult.needsEmailConfirmation;
  }

  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncLoading<void>();
    final AsyncValue<void> result = await AsyncValue.guard(
      () => _repository.sendPasswordReset(email),
    );
    state = result;
    return !result.hasError;
  }

  Future<bool> createCustomerProfile({
    required String fullName,
    String? phone,
  }) async {
    state = const AsyncLoading<void>();
    final AsyncValue<void> result = await AsyncValue.guard(
      () => _repository.createCustomerProfile(fullName: fullName, phone: phone),
    );
    state = result;
    if (result.hasError) return false;
    ref.invalidate(currentProfileProvider);
    return true;
  }

  Future<TenantModel?> createTenant({
    required String slug,
    required String name,
    required String whatsapp,
    String? address,
    required String fullName,
  }) async {
    state = const AsyncLoading<void>();
    TenantModel? tenant;
    final AsyncValue<void> result = await AsyncValue.guard(() async {
      tenant = await _repository.createTenant(
        slug: slug,
        name: name,
        whatsapp: whatsapp,
        address: address,
        fullName: fullName,
      );
    });
    state = result;
    if (result.hasError) return null;
    ref.invalidate(currentProfileProvider);
    return tenant;
  }

  Future<void> signOut() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(() => _repository.signOut());
    // Drop tenant-scoped caches so the next session never sees stale data
    // (tenantByIdProvider/tenantBySlugProvider are kept alive for the whole
    // session and do not depend on auth state).
    ref.invalidate(tenantByIdProvider);
    ref.invalidate(tenantBySlugProvider);
    ref.invalidate(aiUsageProvider);
  }
}

final NotifierProvider<AuthController, AsyncValue<void>>
    authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);
