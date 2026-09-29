import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// A picked image held in memory, always delivered as JPEG after compress().
@immutable
class PickedImage {
  const PickedImage({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

class ImageService {
  static const int _maxBytes = 300 * 1024;

  /// Returns null when the user cancels.
  Future<PickedImage?> pick(ImageSource source) async {
    final XFile? file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;
    return PickedImage(bytes: await file.readAsBytes(), name: file.name);
  }

  /// Compresses to JPEG (<=1024px, q80); retries at q60 if still over 300 KB.
  Future<Uint8List> compress(Uint8List bytes) async {
    Uint8List result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1024,
      minHeight: 1024,
      quality: 80,
      format: CompressFormat.jpeg,
    );
    if (result.length > _maxBytes) {
      result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1024,
        minHeight: 1024,
        quality: 60,
        format: CompressFormat.jpeg,
      );
    }
    return result;
  }

  /// Compresses to JPEG at max 512px — used for tenant logos.
  Future<Uint8List> compressLogo(Uint8List bytes) {
    return FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 512,
      minHeight: 512,
      quality: 85,
      format: CompressFormat.jpeg,
    );
  }
}
