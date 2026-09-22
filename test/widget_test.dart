import 'package:all_commerce/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows AllCommerce placeholder', (tester) async {
    await tester.pumpWidget(const AllCommerceApp());
    expect(find.text('AllCommerce'), findsOneWidget);
  });
}
