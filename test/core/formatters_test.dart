import 'package:all_commerce/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats es_AR prices', () {
    expect(Formatters.price(1234), r'$1.234');
    expect(Formatters.price(1234.5), r'$1.234,50');
    expect(Formatters.price(0), r'$0');
    expect(Formatters.price(8500), r'$8.500');
    expect(Formatters.price(1234567.89), r'$1.234.567,89');
  });

  test('formats dateTime as dd/MM HH:mm', () {
    expect(
      Formatters.dateTime(DateTime(2025, 3, 7, 9, 5)),
      '07/03 09:05',
    );
  });
}
