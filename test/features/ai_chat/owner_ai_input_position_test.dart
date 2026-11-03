import 'package:all_commerce/features/ai_chat/presentation/views/owner_ai_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The chat input must sit just above the floating nav pill, not mid-screen.
  // Scaffold propagates the bottomNavigationBar height into
  // MediaQuery.padding.bottom, so adding FloatingNavBar.height on top of it
  // double-counts the clearance (regression: input rendered ~60% up).
  testWidgets('chat input sits just above the nav bar', (
    WidgetTester tester,
  ) async {
    const double navHeight = 116; // pill (76) + margin (16) + safe area (24)
    await tester.pumpWidget(
      const ProviderScope(
        child: MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(top: 24, bottom: 24)),
          child: MaterialApp(
            home: Scaffold(
              extendBody: true,
              bottomNavigationBar: SizedBox(height: navHeight),
              body: OwnerAiView(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Finder field = find.byType(TextField);
    expect(field, findsOneWidget);
    final double screenHeight = tester
        .getSize(find.byType(Scaffold).last)
        .height;
    final double gapBelowField = screenHeight - tester.getBottomLeft(field).dy;
    // Expected: nav height + small gap + container padding ≈ 130.
    // With the old formula (FloatingNavBar.height + padding.bottom) it was ~216.
    expect(gapBelowField, greaterThan(navHeight));
    expect(gapBelowField, lessThan(navHeight + 30));
  });
}
