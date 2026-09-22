import 'package:all_commerce/core/utils/auth_error_mapper.dart';
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

  test('maps generic exception', () {
    expect(
      AuthErrorMapper.toMessage(Exception('boom')),
      'Ocurrió un error inesperado',
    );
  });
}
