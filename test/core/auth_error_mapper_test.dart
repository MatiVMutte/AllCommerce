import 'dart:typed_data';

import 'package:all_commerce/core/utils/auth_error_mapper.dart';
import 'package:all_commerce/features/product_upload/data/models/bulk_product_draft.dart';
import 'package:all_commerce/features/product_upload/data/services/ai_analyze_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('maps AuthException invalid_credentials', () {
    expect(
      AuthErrorMapper.toMessage(
        const AuthException('x', code: 'invalid_credentials'),
      ),
      'Email o contraseña incorrectos',
    );
  });

  test('maps PostgrestException SLUG_TAKEN', () {
    expect(
      AuthErrorMapper.toMessage(
        const PostgrestException(message: 'SLUG_TAKEN'),
      ),
      'Ese nombre de link ya está en uso, elegí otro',
    );
  });

  test('maps PostgrestException plan errors', () {
    expect(
      AuthErrorMapper.toMessage(
        const PostgrestException(message: 'PLAN_EXPIRED'),
      ),
      contains('plan venció'),
    );
    expect(
      AuthErrorMapper.toMessage(
        const PostgrestException(message: 'PRODUCT_LIMIT_REACHED'),
      ),
      'Llegaste al máximo de productos de tu plan',
    );
  });

  test('maps AiAnalyzeException codes', () {
    expect(
      AuthErrorMapper.toMessage(
        const AiAnalyzeException('AI_RATE_LIMITED', 'x'),
      ),
      'La IA está ocupada, probá en un minuto',
    );
    expect(
      AuthErrorMapper.toMessage(
        const AiAnalyzeException('IMAGE_TOO_LARGE', 'x'),
      ),
      'La imagen supera los 2 MB',
    );
    expect(
      AuthErrorMapper.toMessage(const AiAnalyzeException('AI_EMPTY', 'x')),
      'La IA no pudo analizar la foto, completá los datos a mano',
    );
    expect(
      AuthErrorMapper.toMessage(
        const AiAnalyzeException('UNRECOGNIZABLE_IMAGE', 'x'),
      ),
      contains('no se descontó de tu cuota'),
    );
    expect(
      const AiAnalyzeException('AI_RATE_LIMITED', 'x').isRetryable,
      isTrue,
    );
    expect(const AiAnalyzeException('AI_TIMEOUT', 'x').isRetryable, isTrue);
    expect(
      const AiAnalyzeException('UNRECOGNIZABLE_IMAGE', 'x').isRetryable,
      isFalse,
    );
    expect(
      const AiAnalyzeException('AI_LIMIT_REACHED', 'x').isRetryable,
      isFalse,
    );
  });

  test('BulkProductDraft copyWith clearError resets previous error', () {
    final BulkProductDraft draft = BulkProductDraft(
      id: '1',
      imageBytes: Uint8List(0),
      fileName: 'a.jpg',
      error: 'Error viejo',
    );
    expect(draft.copyWith(title: 'Vaso').error, 'Error viejo');
    expect(draft.copyWith(clearError: true).error, isNull);
  });

  test('maps PostgrestException checkout codes', () {
    const Map<String, String> cases = <String, String>{
      'PHONE_REQUIRED': 'Necesitamos tu WhatsApp para enviar el pedido',
      'PROFILE_REQUIRED': 'Completá tu perfil para hacer el pedido',
      'EMPTY_CART': 'Tu carrito está vacío',
      'PRODUCT_UNAVAILABLE': 'Un producto del carrito ya no está disponible',
      'TENANT_INACTIVE': 'Este local no está recibiendo pedidos',
      'INVALID_COUPON': 'El cupón no es válido',
      'INVALID_QUANTITY': 'Cantidad inválida',
      'OUT_OF_STOCK': 'No alcanza el stock disponible de uno de los productos',
    };
    for (final MapEntry<String, String> entry in cases.entries) {
      expect(
        AuthErrorMapper.toMessage(PostgrestException(message: entry.key)),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('maps generic exception', () {
    expect(
      AuthErrorMapper.toMessage(Exception('boom')),
      'Ocurrió un error inesperado',
    );
  });
}
