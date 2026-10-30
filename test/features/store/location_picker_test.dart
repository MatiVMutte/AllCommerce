import 'package:all_commerce/core/services/nominatim_geocoder.dart';
import 'package:all_commerce/core/theme/app_theme.dart';
import 'package:all_commerce/features/store/presentation/views/tenant_settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _FakeGeocoder extends NominatimGeocoder {
  const _FakeGeocoder(this.results);

  final List<AddressSuggestion> results;

  @override
  Future<List<AddressSuggestion>> search(String rawQuery) async => results;
}

void main() {
  testWidgets('location picker sheet lays out without exceptions', (
    tester,
  ) async {
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

  testWidgets('typing an address shows suggestions and selects pin', (
    tester,
  ) async {
    const _FakeGeocoder geocoder = _FakeGeocoder(<AddressSuggestion>[
      AddressSuggestion(
        displayName:
            '448, Yatay, Valentín Alsina, Lanús, Buenos Aires, Argentina',
        shortLabel: 'Yatay 448, Valentín Alsina, Buenos Aires',
        point: LatLng(-34.6715, -58.4142),
      ),
    ]);

    LocationPickResult? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () async {
                picked = await showModalBottomSheet<LocationPickResult>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const LocationPickerSheet(geocoder: geocoder),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Yatay 448');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(
      find.text('Yatay 448, Valentín Alsina, Buenos Aires'),
      findsOneWidget,
    );

    await tester.tap(find.text('Yatay 448, Valentín Alsina, Buenos Aires'));
    await tester.pump();

    await tester.tap(find.text('Usar esta ubicación'));
    await tester.pumpAndSettle();

    expect(picked?.point?.latitude, closeTo(-34.6715, 0.0001));
    expect(picked?.point?.longitude, closeTo(-58.4142, 0.0001));
    expect(picked?.addressLabel, 'Yatay 448, Valentín Alsina, Buenos Aires');
  });
}
