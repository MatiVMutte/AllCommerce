import 'package:all_commerce/core/theme/app_theme.dart';
import 'package:all_commerce/features/store/presentation/views/tenant_settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('location picker sheet lays out without exceptions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            height: 600,
            child: LocationPickerSheet(initial: LatLng(-34.6, -58.4)),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Usar esta ubicación'), findsOneWidget);
    expect(find.text('Quitar ubicación'), findsOneWidget);
  });
}
