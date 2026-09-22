import 'dart:io';

import 'package:all_commerce/features/product_upload/data/services/ai_analyze_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AuthErrorMapper {
  static String toMessage(Object error) {
    if (error is AiAnalyzeException) {
      switch (error.code) {
        case 'AI_RATE_LIMITED':
          return 'La IA está ocupada, probá en un minuto';
        case 'IMAGE_TOO_LARGE':
          return 'La imagen supera los 2 MB';
        case 'PLAN_EXPIRED':
          return 'Tu período de prueba o plan venció. '
              'Activá un plan para seguir publicando';
        default:
          return 'La IA no pudo analizar la foto, completá los datos a mano';
      }
    }
    if (error is AuthException) {
      switch (error.code) {
        case 'invalid_credentials':
          return 'Email o contraseña incorrectos';
        case 'email_not_confirmed':
          return 'Confirmá tu email antes de ingresar';
        case 'user_already_exists':
        case 'email_exists':
          return 'Ya existe una cuenta con ese email';
        case 'weak_password':
          return 'La contraseña es muy débil';
        case 'over_email_send_rate_limit':
          return 'Demasiados intentos. Esperá unos minutos';
        default:
          return 'No pudimos completar la operación. Intentá de nuevo';
      }
    }
    if (error is PostgrestException) {
      final String message = error.message;
      if (message.contains('PLAN_EXPIRED')) {
        return 'Tu período de prueba o plan venció. '
            'Activá un plan para seguir publicando';
      }
      if (message.contains('PRODUCT_LIMIT_REACHED')) {
        return 'Llegaste al máximo de productos de tu plan';
      }
      if (message.contains('SLUG_TAKEN')) {
        return 'Ese nombre de link ya está en uso, elegí otro';
      }
      if (message.contains('PROFILE_EXISTS')) {
        return 'Tu cuenta ya tiene un perfil';
      }
      if (message.contains('AUTH_REQUIRED')) {
        return 'Iniciá sesión para continuar';
      }
      if (message.contains('tenants_slug_check')) {
        return 'Solo letras minúsculas, números y guiones (3 a 40)';
      }
      if (message.contains('tenants_whatsapp_check')) {
        return 'Ingresá un WhatsApp válido (ej: 11 2233 4455)';
      }
      return 'No pudimos completar la operación. Intentá de nuevo';
    }
    if (error is SocketException) {
      return 'Sin conexión. Revisá tu internet';
    }
    return 'Ocurrió un error inesperado';
  }
}
