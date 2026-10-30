import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// The deferred `beforeinstallprompt` event captured in index.html.
@JS('__allcommerceInstallPrompt')
external JSObject? get _installPrompt;

@JS('__clearAllcommerceInstallPrompt')
external void _clearPrompt();

/// True when the browser offered an install prompt (app not yet
/// installed, manifest/service worker OK, Chromium-based browser).
bool canInstallPwa() => _installPrompt != null;

/// Triggers the browser's native install dialog. Returns false when no
/// prompt is available (already installed or unsupported browser).
Future<bool> promptPwaInstall() async {
  final JSObject? prompt = _installPrompt;
  if (prompt == null) return false;
  try {
    final JSAny? result = prompt.callMethod('prompt'.toJS);
    if (result.isA<JSPromise>()) {
      await (result! as JSPromise).toDart;
    }
    _clearPrompt();
    return true;
  } catch (_) {
    return false;
  }
}
