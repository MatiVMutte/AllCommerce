import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether an owner has explicitly switched to the customer store directory
/// (`/`). Defaults to `false` so opening the app takes owners straight to
/// their business panel (`/owner`).
class CustomerModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void enterCustomerMode() => state = true;

  void exitCustomerMode() => state = false;
}

final NotifierProvider<CustomerModeNotifier, bool> customerModeProvider =
    NotifierProvider<CustomerModeNotifier, bool>(CustomerModeNotifier.new);
