import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI analyses used/allowed for the logged-in owner's store this month.
class AiUsage {
  const AiUsage({required this.used, this.limit});

  final int used;

  /// Monthly cap; null = unlimited.
  final int? limit;

  bool get reached => limit != null && used >= limit!;

  factory AiUsage.fromJson(Map<String, dynamic> json) {
    return AiUsage(
      used: json['used'] as int? ?? 0,
      limit: json['limit'] as int?,
    );
  }
}

final Provider<AiUsageRepository> aiUsageRepositoryProvider =
    Provider<AiUsageRepository>(
      (Ref ref) => AiUsageRepository(ref.watch(supabaseClientProvider)),
    );

final FutureProvider<AiUsage> aiUsageProvider = FutureProvider<AiUsage>(
  (Ref ref) => ref.watch(aiUsageRepositoryProvider).current(),
);

class AiUsageRepository {
  const AiUsageRepository(this._client);

  final SupabaseClient _client;

  Future<AiUsage> current() async {
    final Map<String, dynamic> row = await _client.rpc<Map<String, dynamic>>(
      'ai_usage_current',
    );
    return AiUsage.fromJson(row);
  }
}
