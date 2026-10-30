import 'dart:typed_data';

/// Non-web fallback: browsers are the only place we can trigger a real
/// file download, so callers should treat false as "use share instead".
Future<bool> downloadFile({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) async {
  return false;
}
