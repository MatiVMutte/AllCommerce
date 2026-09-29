import 'dart:convert';

import 'package:all_commerce/features/cart/data/models/cart_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartStorage {
  const CartStorage(this._prefs);

  static const String _key = 'cart_v1';

  final SharedPreferences _prefs;

  /// Returns null when nothing is stored or the JSON is corrupt.
  CartState? load() {
    final String? raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return CartState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(CartState state) =>
      _prefs.setString(_key, jsonEncode(state.toJson()));

  Future<void> clear() => _prefs.remove(_key);
}
