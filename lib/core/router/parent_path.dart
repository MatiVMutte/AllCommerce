/// Parent location to go to when the system back button is pressed and
/// there is no navigation history left. null = root (let Android close).
String? parentPathOf(String location) {
  // Strip query/fragment if present.
  final int q = location.indexOf('?');
  final String loc =
      (q >= 0 ? location.substring(0, q) : location).split('#').first;
  final List<String> segs =
      loc.split('/').where((String s) => s.isNotEmpty).toList();

  if (segs.isEmpty) return null; // '/'
  if (segs[0] == 's') {
    // /s/{slug}/p/{id}, /s/{slug}/cart, /s/{slug}/order/{id} -> /s/{slug}
    if (segs.length >= 3) return '/s/${segs[1]}';
    return '/'; // /s/{slug}
  }
  if (segs[0] == 'owner') {
    if (segs.length == 1) return null; // '/owner'
    if (segs[1] == 'products') {
      // /owner/products/new, /owner/products/{id}/edit -> /owner/products
      if (segs.length >= 3) return '/owner/products';
      return '/owner';
    }
    if (segs[1] == 'orders') {
      // /owner/orders/{id} -> /owner/orders
      if (segs.length >= 3) return '/owner/orders';
      return '/owner';
    }
    if (segs[1] == 'settings') return '/owner';
    return '/owner';
  }
  if (loc == '/my-orders') return '/';
  switch (loc) {
    case '/login':
    case '/welcome':
      return '/';
    case '/register':
    case '/forgot-password':
      return '/login';
    default:
      // /select-role, /onboarding/* -> router decides, Android may close.
      return null;
  }
}
