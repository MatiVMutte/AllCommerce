import 'dart:typed_data';

import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/features/product_upload/data/services/image_service.dart';
import 'package:all_commerce/features/product_upload/presentation/view_models/product_upload_controller.dart';
import 'package:all_commerce/features/store/data/repositories/tenant_settings_repository.dart';
import 'package:all_commerce/features/store/presentation/view_models/tenant_settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class MockTenantSettingsRepository extends Mock
    implements TenantSettingsRepository {}

class MockImageService extends Mock implements ImageService {}

TenantModel _tenant() {
  return TenantModel(
    id: 't1',
    slug: 'demo',
    name: 'Demo Store',
    whatsapp: '5491122334455',
    primaryColor: '#0052FF',
    plan: PlanType.trial,
    trialStartedAt: DateTime(2025),
    planExpiresAt: DateTime.now().add(const Duration(days: 10)),
    isActive: true,
    isClaimed: true,
    createdAt: DateTime(2025),
  );
}

void main() {
  late MockTenantSettingsRepository repo;
  late MockImageService images;
  late ProviderContainer container;
  final TenantModel tenant = _tenant();

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(ImageSource.gallery);
  });

  setUp(() {
    repo = MockTenantSettingsRepository();
    images = MockImageService();
    container = ProviderContainer(
      overrides: [
        tenantSettingsRepositoryProvider.overrideWithValue(repo),
        imageServiceProvider.overrideWithValue(images),
      ],
    );
    addTearDown(container.dispose);
  });

  test('save without logo calls update only', () async {
    when(
      () => repo.update(
        't1',
        name: any(named: 'name'),
        description: any(named: 'description'),
        address: any(named: 'address'),
        whatsapp: any(named: 'whatsapp'),
        primaryColor: any(named: 'primaryColor'),
      ),
    ).thenAnswer((_) async => tenant);

    final TenantModel? result = await container
        .read(tenantSettingsControllerProvider.notifier)
        .save(
          tenant,
          name: 'Demo Store',
          whatsapp: '5491122334455',
          primaryColor: '#0052FF',
        );

    expect(result?.id, 't1');
    verifyNever(
      () => repo.uploadLogo(
        tenantId: any(named: 'tenantId'),
        bytes: any(named: 'bytes'),
      ),
    );
  });

  test('save with logo runs update -> uploadLogo -> setLogoUrl', () async {
    final Uint8List jpeg = Uint8List.fromList(<int>[1, 2, 3]);
    when(() => images.pick(any()))
        .thenAnswer((_) async => PickedImage(bytes: jpeg, name: 'logo.png'));
    when(() => images.compressLogo(jpeg)).thenAnswer((_) async => jpeg);
    when(
      () => repo.update(
        't1',
        name: any(named: 'name'),
        description: any(named: 'description'),
        address: any(named: 'address'),
        whatsapp: any(named: 'whatsapp'),
        primaryColor: any(named: 'primaryColor'),
      ),
    ).thenAnswer((_) async => tenant);
    when(() => repo.uploadLogo(tenantId: 't1', bytes: jpeg))
        .thenAnswer((_) async => 'https://x/logo.jpg?v=1');
    when(() => repo.setLogoUrl('t1', 'https://x/logo.jpg?v=1'))
        .thenAnswer((_) async {});

    await container.read(tenantSettingsControllerProvider.notifier).pickLogo();
    final TenantModel? result = await container
        .read(tenantSettingsControllerProvider.notifier)
        .save(
          tenant,
          name: 'Demo Store',
          whatsapp: '5491122334455',
          primaryColor: '#0052FF',
        );

    expect(result, isNotNull);
    verifyInOrder(<Future<dynamic> Function()>[
      () => repo.update(
        't1',
        name: any(named: 'name'),
        description: any(named: 'description'),
        address: any(named: 'address'),
        whatsapp: any(named: 'whatsapp'),
        primaryColor: any(named: 'primaryColor'),
      ),
      () => repo.uploadLogo(tenantId: 't1', bytes: jpeg),
      () => repo.setLogoUrl('t1', 'https://x/logo.jpg?v=1'),
    ]);
  });

  test('update error sets state.error and returns null', () async {
    when(
      () => repo.update(
        't1',
        name: any(named: 'name'),
        description: any(named: 'description'),
        address: any(named: 'address'),
        whatsapp: any(named: 'whatsapp'),
        primaryColor: any(named: 'primaryColor'),
      ),
    ).thenThrow(Exception('boom'));

    final TenantModel? result = await container
        .read(tenantSettingsControllerProvider.notifier)
        .save(
          tenant,
          name: 'Demo Store',
          whatsapp: '5491122334455',
          primaryColor: '#0052FF',
        );

    expect(result, isNull);
    expect(container.read(tenantSettingsControllerProvider).error, isNotNull);
    expect(container.read(tenantSettingsControllerProvider).saving, isFalse);
  });

  test('toggleOpen calls setOpen with inverted value', () async {
    when(() => repo.setOpen('t1', false)).thenAnswer((_) async {});

    final bool ok = await container
        .read(tenantSettingsControllerProvider.notifier)
        .toggleOpen(tenant);

    expect(ok, isTrue);
    verify(() => repo.setOpen('t1', false)).called(1);
  });
}
