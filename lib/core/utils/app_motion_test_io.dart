import 'dart:io' show Platform;

/// `flutter test` exports FLUTTER_TEST=true; used to skip infinite animations
/// so `pumpAndSettle` in widget tests can never time out.
bool get inFlutterTest => Platform.environment['FLUTTER_TEST'] == 'true';
