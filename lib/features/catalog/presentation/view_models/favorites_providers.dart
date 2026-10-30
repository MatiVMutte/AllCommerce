import 'package:all_commerce/core/storage/shared_preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tenant ids marked as favorite by the customer, persisted locally.
class FavoriteStoresNotifier extends Notifier<Set<String>> {
  static const String _key = 'favorite_tenants';

  @override
  Set<String> build() {
    final SharedPreferences prefs = ref.watch(sharedPreferencesProvider);
    return Set<String>.of(prefs.getStringList(_key) ?? <String>[]);
  }

  void toggle(String tenantId) {
    final Set<String> next = Set<String>.of(state);
    if (!next.remove(tenantId)) next.add(tenantId);
    state = next;
    ref.read(sharedPreferencesProvider).setStringList(_key, next.toList());
  }
}

final favoriteStoresProvider =
    NotifierProvider<FavoriteStoresNotifier, Set<String>>(
      FavoriteStoresNotifier.new,
    );
