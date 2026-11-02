import 'package:all_commerce/core/theme/app_theme.dart';
import 'package:all_commerce/features/auth/presentation/views/forgot_password_view.dart';
import 'package:all_commerce/features/auth/presentation/views/login_view.dart';
import 'package:all_commerce/features/auth/presentation/views/register_view.dart';
import 'package:all_commerce/features/auth/presentation/views/role_select_view.dart';
import 'package:all_commerce/features/auth/presentation/views/welcome_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Redesigned account screens must lay out cleanly on a small phone and on
/// desktop, in light and dark mode (catches RenderFlex overflows).
void main() {
  const Map<String, Widget> screens = <String, Widget>{
    'login': LoginView(),
    'register': RegisterView(),
    'forgot': ForgotPasswordView(),
    'role select': RoleSelectView(),
    'welcome': WelcomeView(),
  };
  const Map<String, Size> sizes = <String, Size>{
    'phone': Size(360, 740),
    'desktop': Size(1280, 860),
  };

  for (final MapEntry<String, Widget> screen in screens.entries) {
    for (final MapEntry<String, Size> size in sizes.entries) {
      for (final bool dark in <bool>[false, true]) {
        testWidgets('${screen.key} on ${size.key}${dark ? ' (dark)' : ''}', (
          WidgetTester tester,
        ) async {
          tester.view.physicalSize = size.value;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                home: screen.value,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
