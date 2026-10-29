import 'package:all_commerce/core/theme/app_theme.dart';
import 'package:all_commerce/features/legal/presentation/views/legal_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TermsView renders sections', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const TermsView(),
      ),
    );
    expect(find.text('Términos y condiciones'), findsOneWidget);
    expect(find.text('1. Qué es AllCommerce'), findsOneWidget);
  });

  testWidgets('PrivacyView renders sections', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const PrivacyView(),
      ),
    );
    expect(find.text('Política de privacidad'), findsOneWidget);
    expect(find.text('1. Datos que recopilamos'), findsOneWidget);
  });
}
