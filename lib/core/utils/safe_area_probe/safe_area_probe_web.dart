import 'package:web/web.dart' as web;

/// Flutter web does not read `env(safe-area-inset-*)` — MediaQuery
/// reports 0 on Android Chrome even though edge-to-edge pages sit under
/// the gesture bar. Probe it via a hidden element + getComputedStyle
/// (requires `viewport-fit=cover` in index.html).
Future<double> probeSafeAreaBottom() async {
  try {
    final web.HTMLElement el =
        web.document.createElement('div') as web.HTMLElement;
    el.style
      ..position = 'fixed'
      ..visibility = 'hidden'
      ..pointerEvents = 'none'
      ..paddingBottom = 'env(safe-area-inset-bottom, 0px)';
    web.document.body?.appendChild(el);
    final String value = web.window
        .getComputedStyle(el)
        .getPropertyValue('padding-bottom');
    el.remove();
    return double.tryParse(value.replaceAll('px', '').trim()) ?? 0;
  } catch (_) {
    return 0;
  }
}
