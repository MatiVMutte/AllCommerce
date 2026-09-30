import 'package:all_commerce/core/constants/app_config.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

enum ShareResult { shared, copied }

typedef ShareSender = Future<void> Function(String text, String url);

/// Share store/product links; falls back to clipboard when the platform
/// share sheet isn't available (e.g. some web environments).
class ShareService {
  const ShareService({ShareSender? sender}) : _sender = sender ?? _share;

  final ShareSender _sender;

  /// Public web base for links ('allcommerce.app' by default).
  static String get linkBase => AppConfig.publicBaseUrl.isEmpty
      ? 'allcommerce.app'
      : AppConfig.publicBaseUrl;

  static String catalogUrl(String slug) => 'https://$linkBase/s/$slug';

  static String productUrl(String slug, String productId) =>
      'https://$linkBase/s/$slug/p/$productId';

  /// Default sender through share_plus.
  static Future<void> _share(String text, String url) {
    return SharePlus.instance.share(
      ShareParams(text: '$text\n$url'),
    );
  }

  Future<ShareResult> shareLink({
    required String url,
    required String text,
  }) async {
    try {
      await _sender(text, url);
      return ShareResult.shared;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      return ShareResult.copied;
    }
  }
}
