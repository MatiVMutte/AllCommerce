import 'package:all_commerce/core/theme/app_theme.dart';
import 'package:all_commerce/core/widgets/app_confirm_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildApp(void Function(BuildContext) onTap) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () => onTap(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  testWidgets('returns true when confirmed', (tester) async {
    bool? result;
    await tester.pumpWidget(
      buildApp((BuildContext context) async {
        result = await showAppConfirmSheet(
          context,
          title: 'Eliminar',
          message: 'No se puede deshacer',
          confirmLabel: 'Eliminar',
          destructive: true,
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar'), findsWidgets);
    expect(find.text('No se puede deshacer'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('returns false when cancelled', (tester) async {
    bool? result;
    await tester.pumpWidget(
      buildApp((BuildContext context) async {
        result = await showAppConfirmSheet(
          context,
          title: 'Confirmar',
          message: 'msg',
          confirmLabel: 'OK',
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
