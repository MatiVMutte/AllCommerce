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

  @override
  String toString() => 'AiAnalyzeException($code): $message';
}

class AiAnalyzeService {
  const AiAnalyzeService(this._client);

  final SupabaseClient _client;

  Future<AiProductSuggestion> analyze(Uint8List jpegBytes) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'analyze-product',
        body: <String, dynamic>{
          'imageBase64': base64Encode(jpegBytes),
          'mimeType': 'image/jpeg',
        },
      );
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      return AiProductSuggestion.fromJson(
        data['product'] as Map<String, dynamic>,
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
