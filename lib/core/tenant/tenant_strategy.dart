import 'package:all_commerce/core/constants/app_config.dart';

/// Decides which store is active. Priority:
/// fixed (white-label build) > route (/s/:slug) > user-selected.
class TenantResolver {
  const TenantResolver({this.fixedSlug = AppConfig.fixedTenantSlug});

  final String fixedSlug;

  bool get isWhiteLabel => fixedSlug.isNotEmpty;

  String? resolveSlug({String? routeSlug, String? selectedSlug}) {
    final String fixed = _normalize(fixedSlug);
    if (fixed.isNotEmpty) return fixed;
    final String route = _normalize(routeSlug);
    if (route.isNotEmpty) return route;
    final String selected = _normalize(selectedSlug);
    if (selected.isNotEmpty) return selected;
    return null;
  }

  String _normalize(String? slug) => (slug ?? '').trim().toLowerCase();
}
