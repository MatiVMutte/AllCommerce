import 'dart:typed_data';

import 'package:all_commerce/features/product_upload/data/models/bulk_product_draft.dart';
import 'package:all_commerce/features/product_upload/presentation/view_models/bulk_upload_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BulkUploadState', () {
    test('counts analyzed and publishable drafts', () {
      final BulkProductDraft valid = BulkProductDraft(
        id: '1',
        title: 'Yerba',
        price: 1000,
        imageBytes: Uint8List(0),
        fileName: '1.jpg',
        analyzed: true,
      );
      final BulkProductDraft invalid = BulkProductDraft(
        id: '2',
        imageBytes: Uint8List(0),
        fileName: '2.jpg',
        analyzed: true,
      );
      final BulkProductDraft pending = BulkProductDraft(
        id: '3',
        imageBytes: Uint8List(0),
        fileName: '3.jpg',
        analyzed: false,
      );

      const BulkUploadState state = BulkUploadState(
        drafts: <BulkProductDraft>[],
      );
      expect(state.analyzedCount, 0);
      expect(state.publishableCount, 0);

      final BulkUploadState withDrafts = BulkUploadState(
        drafts: <BulkProductDraft>[valid, invalid, pending],
      );
      expect(withDrafts.analyzedCount, 2);
      expect(withDrafts.validCount, 1);
      expect(withDrafts.publishableCount, 1);
    });

    test('draft copyWith updates fields', () {
      final BulkProductDraft draft = BulkProductDraft(
        id: '1',
        imageBytes: Uint8List(0),
        fileName: '1.jpg',
      );
      final BulkProductDraft updated = draft.copyWith(
        title: 'Yerba',
        price: 1500,
        category: 'food',
      );
      expect(updated.title, 'Yerba');
      expect(updated.price, 1500);
      expect(updated.category, 'food');
      expect(updated.id, draft.id);
      expect(updated.isValid, isTrue);
    });
  });
}
