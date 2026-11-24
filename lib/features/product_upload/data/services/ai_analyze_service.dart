import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:all_commerce/features/product_upload/data/models/ai_product_suggestion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Error returned by the analyze-product Edge Function.
/// [code] is one of the documented codes (PLAN_EXPIRED, AI_RATE_LIMITED, ...).
class AiAnalyzeException implements Exception {
  const AiAnalyzeException(this.code, this.message);

  final String code;
  final String message;

  /// True only for transient errors (rate limit, timeout, temporary upstream
  /// failure) where an automatic retry makes sense. False for bad/blurry
  /// images, quota limits, or auth/plan blocks so we never retry in vain.
  bool get isRetryable {
    switch (code) {
      case 'AI_RATE_LIMITED':
      case 'AI_TIMEOUT':
      case 'AI_UNAVAILABLE':
      case 'AI_EMPTY':
      case 'AI_INVALID_JSON':
      case 'UNKNOWN':
        return true;
      default:
        return false;
    }
  }

  @override
  String toString() => 'AiAnalyzeException($code): $message';
}

class AiAnalyzeService {
  const AiAnalyzeService(
    this._client, {
    this.timeout = const Duration(seconds: 30),
  });

  final SupabaseClient _client;
  final Duration timeout;

  Future<AiProductSuggestion> analyze(Uint8List jpegBytes) async {
    try {
      final FunctionResponse response = await _client.functions
          .invoke(
            'analyze-product',
            body: <String, dynamic>{
              'imageBase64': base64Encode(jpegBytes),
              'mimeType': 'image/jpeg',
            },
          )
          .timeout(timeout);
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      return AiProductSuggestion.fromJson(
        data['product'] as Map<String, dynamic>,
      );
    } on TimeoutException {
      throw const AiAnalyzeException(
        'AI_TIMEOUT',
        'La IA demoró demasiado en responder, intentá de nuevo',
      );
    } on FunctionException catch (e) {
      final Object? details = e.details;
      if (details is Map<String, dynamic> && details['error'] is Map) {
        final Map<String, dynamic> error =
            details['error'] as Map<String, dynamic>;
        throw AiAnalyzeException(
          error['code'] as String? ?? 'UNKNOWN',
          error['message'] as String? ?? 'Error desconocido',
        );
      }
      throw AiAnalyzeException('UNKNOWN', e.reasonPhrase ?? 'Error de la IA');
    }
  }
}
