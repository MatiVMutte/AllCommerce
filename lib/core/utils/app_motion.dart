import 'package:flutter/widgets.dart';

import 'package:all_commerce/core/utils/app_motion_test_stub.dart'
    if (dart.library.io) 'package:all_commerce/core/utils/app_motion_test_io.dart'
    as impl;

/// Central switch for motion: respects the OS "reduce motion" setting and
/// keeps `flutter test` deterministic (FLUTTER_TEST env is set by the runner).
abstract final class AppMotion {
  static bool enabled(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context) && !impl.inFlutterTest;

  /// Infinite/looping animations (Pulse, attention seekers) only run here.
  static bool loopsEnabled(BuildContext context) => enabled(context);
}
