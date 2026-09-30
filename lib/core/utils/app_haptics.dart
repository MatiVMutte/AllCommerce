import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Haptics that no-op on web.
abstract final class AppHaptics {
  static void light() {
    if (!kIsWeb) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (!kIsWeb) HapticFeedback.mediumImpact();
  }

  static void success() {
    if (!kIsWeb) HapticFeedback.mediumImpact();
  }
}
