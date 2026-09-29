import 'package:all_commerce/core/storage/shared_preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _returnToKey = 'return_to';

/// Where to send the user after login/onboarding completes.
/// Persisted so it survives a web reload.
class ReturnToNotifier extends Notifier<String?> {
  @override
  String? build() {
    return ref.watch(sharedPreferencesProvider).getString(_returnToKey);
  }

  void set(String path) {
    state = path;
    ref.read(sharedPreferencesProvider).setString(_returnToKey, path);
  }

  /// Returns the stored path and clears it.
  String? consume() {
    final String? value = state;
    state = null;
    ref.read(sharedPreferencesProvider).remove(_returnToKey);
    return value;
  }
}

final NotifierProvider<ReturnToNotifier, String?> returnToProvider =
    NotifierProvider<ReturnToNotifier, String?>(ReturnToNotifier.new);
