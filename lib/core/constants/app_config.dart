import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class AppConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get publicBaseUrl =>
      dotenv.isInitialized ? dotenv.env['PUBLIC_BASE_URL'] ?? '' : '';

  /// Support WhatsApp in E.164 without '+'.
  static String get supportWhatsapp => dotenv.env['SUPPORT_WHATSAPP'] ?? '';

  /// Fixed slug for white-label per-store builds. Empty = multi-store app.
  static const String fixedTenantSlug = String.fromEnvironment('TENANT_SLUG');
  static const String appName = 'AllCommerce';
  static const int trialDays = 14;
}
