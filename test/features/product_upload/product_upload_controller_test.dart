import 'dart:typed_data';

import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/product_upload/data/models/ai_product_suggestion.dart';
import 'package:all_commerce/features/product_upload/data/models/product_input.dart';
import 'package:all_commerce/features/product_upload/data/repositories/product_repository.dart';
import 'package:all_commerce/features/product_upload/data/services/ai_analyze_service.dart';
import 'package:all_commerce/features/product_upload/data/services/image_service.dart';
import 'package:all_commerce/features/product_upload/presentation/view_models/product_upload_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockImageService extends Mock implements ImageService {}

class MockAiAnalyzeService extends Mock implements AiAnalyzeService {}

class MockProductRepository extends Mock implements ProductRepository {}

void main() {
  late MockImageService images;
  late MockAiAnalyzeService ai;
  late MockProductRepository products;
  late ProviderContainer container;

  final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);
  const AiProductSuggestion suggestion = AiProductSuggestion(
    title: 'Vaso',
    description: 'Acero',
    category: 'home',
    tags: <String>['vaso'],
  );
  final ProductModel product = ProductModel(
    id: 'p1',
    tenantId: 't1',
    title: 'Vaso',
    category: 'home',
    price: 100,
    isActive: true,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );
  const ProductInput input = ProductInput(
    title: 'Vaso',
    category: 'home',
    price: 100,
  );

  ProductUploadState readState() =>
      container.read(productUploadControllerProvider);
  ProductUploadController controller() =>
      container.read(productUploadControllerProvider.notifier);

  setUpAll(() {
    registerFallbackValue(ImageSource.gallery);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(input);
  });

  setUp(() {
    images = MockImageService();
    ai = MockAiAnalyzeService();
    products = MockProductRepository();
    container = ProviderContainer(
      overrides: [
        imageServiceProvider.overrideWithValue(images),
        aiAnalyzeServiceProvider.overrideWithValue(ai),
        productRepositoryProvider.overrideWithValue(products),
      ],
    );
    addTearDown(container.dispose);
  });

  test('pickAndAnalyze stores suggestion and image', () async {
    when(() => images.pick(any())).thenAnswer(
      (_) async => PickedImage(bytes: bytes, name: 'a.jpg'),
    );
    when(() => images.compress(any())).thenAnswer((_) async => bytes);
    when(() => ai.analyze(any())).thenAnswer((_) async => suggestion);

    await controller().pickAndAnalyze(ImageSource.gallery);

    expect(readState().suggestion, suggestion);
    expect(readState().analyzing, isFalse);
    expect(readState().imageBytes, bytes);
  });

  test('AI failure keeps image and sets infoMessage', () async {
    when(() => images.pick(any())).thenAnswer(
      (_) async => PickedImage(bytes: bytes, name: 'a.jpg'),
    );
    when(() => images.compress(any())).thenAnswer((_) async => bytes);
    when(() => ai.analyze(any())).thenThrow(
      const AiAnalyzeException('AI_UNAVAILABLE', 'down'),
    );

    await controller().pickAndAnalyze(ImageSource.gallery);

    expect(readState().suggestion, isNull);
    expect(readState().infoMessage, isNotNull);
    expect(readState().imageBytes, bytes);
  });

  test('cancelled pick changes nothing and skips analyze', () async {
    when(() => images.pick(any())).thenAnswer((_) async => null);

    await controller().pickAndAnalyze(ImageSource.gallery);

    expect(readState().imageBytes, isNull);
    verifyNever(() => ai.analyze(any()));
  });

  test('save runs create -> uploadImage -> setImageUrl in order', () async {
    when(() => images.pick(any())).thenAnswer(
      (_) async => PickedImage(bytes: bytes, name: 'a.jpg'),
    );
    when(() => images.compress(any())).thenAnswer((_) async => bytes);
    when(() => ai.analyze(any())).thenAnswer((_) async => suggestion);
    when(() => products.create(any(), any())).thenAnswer((_) async => product);
    when(
      () => products.uploadImage(
        tenantId: any(named: 'tenantId'),
        productId: any(named: 'productId'),
        jpegBytes: any(named: 'jpegBytes'),
      ),
    ).thenAnswer((_) async => 'https://img');
    when(() => products.setImageUrl(any(), any())).thenAnswer((_) async {});

    await controller().pickAndAnalyze(ImageSource.gallery);
    final ProductModel? result = await controller().save(input, 't1');

    expect(result, product);
    verifyInOrder(<dynamic Function()>[
      () => products.create(any(), any()),
      () => products.uploadImage(
            tenantId: any(named: 'tenantId'),
            productId: any(named: 'productId'),
            jpegBytes: any(named: 'jpegBytes'),
          ),
      () => products.setImageUrl(any(), any()),
    ]);
  });

  test('save blocked by PRODUCT_LIMIT_REACHED skips upload', () async {
    when(() => products.create(any(), any())).thenThrow(
      const PostgrestException(message: 'PRODUCT_LIMIT_REACHED'),
    );

    final ProductModel? result = await controller().save(input, 't1');

    expect(result, isNull);
    expect(readState().blockedCode, 'PRODUCT_LIMIT_REACHED');
    verifyNever(
      () => products.uploadImage(
        tenantId: any(named: 'tenantId'),
        productId: any(named: 'productId'),
        jpegBytes: any(named: 'jpegBytes'),
      ),
    );
  });

  test('update without image calls update only', () async {
    when(() => products.update(any(), any(), any()))
        .thenAnswer((_) async => product);

    final ProductModel? result = await controller().update(product, input);

    expect(result, product);
    verify(() => products.update('p1', 't1', input)).called(1);
    verifyNever(
      () => products.uploadImage(
        tenantId: any(named: 'tenantId'),
        productId: any(named: 'productId'),
        jpegBytes: any(named: 'jpegBytes'),
      ),
    );
  });

  test('update with image runs update -> uploadImage -> setImageUrl', () async {
    when(() => images.pick(any())).thenAnswer(
      (_) async => PickedImage(bytes: bytes, name: 'a.jpg'),
    );
    when(() => images.compress(any())).thenAnswer((_) async => bytes);
    when(() => ai.analyze(any())).thenAnswer((_) async => suggestion);
    when(() => products.update(any(), any(), any()))
        .thenAnswer((_) async => product);
    when(
      () => products.uploadImage(
        tenantId: any(named: 'tenantId'),
        productId: any(named: 'productId'),
        jpegBytes: any(named: 'jpegBytes'),
      ),
    ).thenAnswer((_) async => 'https://img');
    when(() => products.setImageUrl(any(), any())).thenAnswer((_) async {});

    await controller().pickAndAnalyze(ImageSource.gallery);
    final ProductModel? result = await controller().update(product, input);

    expect(result, product);
    verifyInOrder(<dynamic Function()>[
      () => products.update(any(), any(), any()),
      () => products.uploadImage(
            tenantId: any(named: 'tenantId'),
            productId: any(named: 'productId'),
            jpegBytes: any(named: 'jpegBytes'),
          ),
      () => products.setImageUrl(any(), any()),
    ]);
  });

  test('update returns product even if image upload fails', () async {
    when(() => images.pick(any())).thenAnswer(
      (_) async => PickedImage(bytes: bytes, name: 'a.jpg'),
    );
    when(() => images.compress(any())).thenAnswer((_) async => bytes);
    when(() => ai.analyze(any())).thenAnswer((_) async => suggestion);
    when(() => products.update(any(), any(), any()))
        .thenAnswer((_) async => product);
    when(
      () => products.uploadImage(
        tenantId: any(named: 'tenantId'),
        productId: any(named: 'productId'),
        jpegBytes: any(named: 'jpegBytes'),
      ),
    ).thenThrow(Exception('storage down'));

    await controller().pickAndAnalyze(ImageSource.gallery);
    final ProductModel? result = await controller().update(product, input);

    expect(result, product);
    expect(readState().infoMessage, isNotNull);
  });

  test('save returns product even if image upload fails', () async {
    when(() => images.pick(any())).thenAnswer(
      (_) async => PickedImage(bytes: bytes, name: 'a.jpg'),
    );
    when(() => images.compress(any())).thenAnswer((_) async => bytes);
    when(() => ai.analyze(any())).thenAnswer((_) async => suggestion);
    when(() => products.create(any(), any())).thenAnswer((_) async => product);
    when(
      () => products.uploadImage(
        tenantId: any(named: 'tenantId'),
        productId: any(named: 'productId'),
        jpegBytes: any(named: 'jpegBytes'),
      ),
    ).thenThrow(Exception('storage down'));

    await controller().pickAndAnalyze(ImageSource.gallery);
    final ProductModel? result = await controller().save(input, 't1');

    expect(result, product);
    expect(readState().infoMessage, isNotNull);
  });
}
