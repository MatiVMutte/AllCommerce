import 'package:all_commerce/core/constants/app_config.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  const AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Returns true when the user is logged in, false when Supabase requires
  /// email confirmation (session == null).
  Future<bool> signUp({required String email, required String password}) async {
    final AuthResponse response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    return response.session != null;
  }

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> sendPasswordReset(String email) async {
    final String base = AppConfig.publicBaseUrl;
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: base.isEmpty ? null : '$base/#/reset-password',
    );
  }

  Future<UserModel?> fetchProfile() async {
    final String? userId = currentUserId;
    if (userId == null) return null;
    final Map<String, dynamic>? row = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return UserModel.fromJson(row);
  }

  Future<UserModel> createCustomerProfile({
    required String fullName,
    String? phone,
  }) async {
    final Map<String, dynamic> row = await _client
        .from('users')
        .insert(<String, dynamic>{
          'id': currentUserId,
          'role': UserRole.customer.id,
          'full_name': fullName,
          'phone': phone,
        })
        .select()
        .single();
    return UserModel.fromJson(row);
  }

  Future<TenantModel> createTenant({
    required String slug,
    required String name,
    required String whatsapp,
    String? address,
    required String fullName,
  }) async {
    final Map<String, dynamic> row = await _client.rpc(
      'create_tenant',
      params: <String, dynamic>{
        'p_slug': slug,
        'p_name': name,
        'p_whatsapp': whatsapp,
        'p_address': address,
        'p_full_name': fullName,
      },
    );
    return TenantModel.fromJson(row);
  }
}
