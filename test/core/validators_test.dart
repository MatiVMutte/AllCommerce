import 'package:all_commerce/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePhone', () {
    test('local AR number gets 549 prefix', () {
      expect(Validators.normalizePhone('11 2233-4455'), '5491122334455');
    });

    test('international format stays', () {
      expect(
        Validators.normalizePhone('+54 9 11 2233 4455'),
        '5491122334455',
      );
    });

    test('leading zero is stripped', () {
      expect(Validators.normalizePhone('011 2233 4455'), '5491122334455');
    });

    test('already normalized stays', () {
      expect(
        Validators.normalizePhone('5491122334455'),
        '5491122334455',
      );
    });
  });

  group('slugify', () {
    test('strips accents and joins with dashes', () {
      expect(
        Validators.slugify('Bazar Don Pepé  & Hijos'),
        'bazar-don-pepe-hijos',
      );
    });

    test('truncates at 40 chars without trailing dash', () {
      final String result = Validators.slugify('a' * 50);
      expect(result.length, 40);
      expect(result.endsWith('-'), isFalse);
      expect(Validators.slugify('tienda ${'x' * 40} nombre').length <= 40,
          isTrue);
    });
  });

  group('field validators', () {
    test('email', () {
      expect(Validators.email('no-es-email'), isNotNull);
      expect(Validators.email('a@b.com'), isNull);
    });

    test('password', () {
      expect(Validators.password('123'), isNotNull);
      expect(Validators.password('12345678'), isNull);
    });

    test('confirmPassword', () {
      expect(Validators.confirmPassword('abc', 'abd'), isNotNull);
      expect(Validators.confirmPassword('abc', 'abc'), isNull);
    });

    test('slug', () {
      expect(Validators.slug('Mi Local!'), isNotNull);
      expect(Validators.slug('mi-local'), isNull);
    });
  });
}
