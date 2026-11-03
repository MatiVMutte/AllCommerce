import 'dart:convert';
import 'dart:typed_data';

import 'package:all_commerce/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:all_commerce/features/billing/data/repositories/ai_usage_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One turn of the `ai-chat` edge function.
class AiChatResponse {
  const AiChatResponse({
    required this.reply,
    required this.actions,
    this.quota,
  });

  final String reply;
  final List<AiAction> actions;
  final AiUsage? quota;
}

/// Talks to the `ai-chat` edge function. Stateless — the client owns the
/// conversation history and sends the last turns with each request.
class AiChatService {
  const AiChatService(this._client);

  final SupabaseClient _client;

  Future<AiChatResponse> send({
    required List<AiChatMessage> history,
    Uint8List? imageBytes,
  }) async {
    final FunctionResponse res = await _client.functions.invoke(
      'ai-chat',
      body: <String, dynamic>{
        'messages': history.map((AiChatMessage m) => m.toJson()).toList(),
        if (imageBytes != null) 'imageBase64': base64Encode(imageBytes),
        if (imageBytes != null) 'mimeType': 'image/jpeg',
      },
    );
    if (res.status != 200) {
      final Object? data = res.data;
      final String message = data is Map<String, dynamic>
          ? (data['error']?['message']?.toString() ?? 'Error de la IA')
          : 'Error de la IA';
      throw AiChatException(message);
    }
    final Map<String, dynamic> body = res.data is Map<String, dynamic>
        ? res.data as Map<String, dynamic>
        : jsonDecode(res.data.toString()) as Map<String, dynamic>;
    final List<dynamic> rawActions = body['actions'] as List<dynamic>? ?? [];
    return AiChatResponse(
      reply: (body['reply'] as String? ?? '').trim(),
      actions: rawActions
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> a) => AiAction.fromJson(a))
          .toList(),
      quota: body['quota'] is Map<String, dynamic>
          ? AiUsage.fromJson(body['quota'] as Map<String, dynamic>)
          : null,
    );
  }
}

class AiChatException implements Exception {
  const AiChatException(this.message);
  final String message;

  @override
  String toString() => message;
}
