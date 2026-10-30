import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a real browser download via a Blob + anchor click.
Future<bool> downloadFile({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final web.Blob blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final String url = web.URL.createObjectURL(blob);
  try {
    final web.HTMLAnchorElement anchor =
        web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = filename;
    anchor.click();
    return true;
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
