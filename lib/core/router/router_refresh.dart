import 'dart:async';

import 'package:all_commerce/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Re-evaluates go_router redirects whenever the auth session changes.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(AuthRepository repository) {
    _subscription = repository.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  /// Triggers a router redirect re-evaluation.
  void refresh() => notifyListeners();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
