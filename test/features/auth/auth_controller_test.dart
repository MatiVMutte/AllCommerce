import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/features/auth/data/repositories/auth_repository.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late ProviderContainer container;

  final TenantModel tenant = TenantModel(
    id: 't1',
    slug: 'demo',
    name: 'Demo',
    whatsapp: '5491122334455',
    primaryColor: '#0052FF',
    plan: PlanType.trial,
    trialStartedAt: DateTime(2025),
    planExpiresAt: DateTime.now().add(const Duration(days: 10)),
    isActive: true,
      isClaimed: true,
    createdAt: DateTime(2025),
  );

  setUp(() {
    repository = MockAuthRepository();
    when(() => repository.onAuthStateChange)
        .thenAnswer((_) => const Stream<AuthState>.empty());
    when(() => repository.currentSession).thenReturn(null);
    when(() => repository.currentUserId).thenReturn(null);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  test('signIn success returns true and state is AsyncData', () async {
    when(
      () => repository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});

    final bool ok = await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'a@b.com', password: '12345678');

    expect(ok, isTrue);
    expect(container.read(authControllerProvider), isA<AsyncData<void>>());
  });

  test('signIn error returns false and state hasError', () async {
    when(
      () => repository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const AuthException('x', code: 'invalid_credentials'));

    final bool ok = await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'a@b.com', password: '12345678');

    expect(ok, isFalse);
    expect(container.read(authControllerProvider).hasError, isTrue);
  });

  test('signUp without session returns needsEmailConfirmation', () async {
    when(
      () => repository.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => false);

    final SignUpResult result = await container
        .read(authControllerProvider.notifier)
        .signUp(email: 'a@b.com', password: '12345678');

    expect(result, SignUpResult.needsEmailConfirmation);
  });

  test('createTenant success returns tenant', () async {
    when(
      () => repository.createTenant(
        slug: any(named: 'slug'),
        name: any(named: 'name'),
        whatsapp: any(named: 'whatsapp'),
        address: any(named: 'address'),
        fullName: any(named: 'fullName'),
      ),
    ).thenAnswer((_) async => tenant);

    final TenantModel? result = await container
        .read(authControllerProvider.notifier)
        .createTenant(
          slug: 'demo',
          name: 'Demo',
          whatsapp: '5491122334455',
          fullName: 'Dueño Demo',
        );

    expect(result?.slug, 'demo');
    expect(container.read(authControllerProvider), isA<AsyncData<void>>());
  });
}
