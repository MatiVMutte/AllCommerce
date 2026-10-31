import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Resilient network image widget across platforms:
/// - On Web (`kIsWeb`), uses the browser-native `Image.network` pipeline
///   (avoids `cached_network_image_web` XHR drops when multiple Supabase
///   Storage images load in parallel) and retries automatically on transient
///   network errors.
/// - On Android/iOS/Desktop, uses `CachedNetworkImage` for on-disk caching
///   plus automatic retry.
class AppNetworkImage extends StatefulWidget {
  const AppNetworkImage({
    required this.imageUrl,
    required this.errorBuilder,
    this.placeholder,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String imageUrl;
  final WidgetBuilder errorBuilder;
  final Widget? placeholder;
  final BoxFit fit;

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  int _attempt = 0;
  Timer? _retryTimer;

  @override
  void didUpdateWidget(covariant AppNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _retryTimer?.cancel();
      _attempt = 0;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _scheduleRetry() {
    if (_attempt >= 2 || (_retryTimer?.isActive ?? false)) return;
    _retryTimer = Timer(Duration(milliseconds: 500 * (_attempt + 1)), () {
      if (mounted) setState(() => _attempt++);
    });
  }

  String get _effectiveUrl {
    if (_attempt == 0) return widget.imageUrl;
    final String sep = widget.imageUrl.contains('?') ? '&' : '?';
    return '${widget.imageUrl}${sep}_r=$_attempt';
  }

  @override
  Widget build(BuildContext context) {
    final Widget loadingFallback =
        widget.placeholder ?? const SizedBox.expand();
    // Decode at display size instead of full resolution — a 1600px upload
    // shown in a ~300px card wastes decode time and memory (desktop scroll).
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double w = constraints.maxWidth;
        final int? cacheWidth = w.isFinite && w > 0
            ? (w * MediaQuery.devicePixelRatioOf(context)).round().clamp(
                64,
                4096,
              )
            : null;
        if (kIsWeb) {
          return Image.network(
            _effectiveUrl,
            key: ValueKey<String>(_effectiveUrl),
            fit: widget.fit,
            cacheWidth: cacheWidth,
            frameBuilder:
                (
                  BuildContext context,
                  Widget child,
                  int? frame,
                  bool wasSynchronouslyLoaded,
                ) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return loadingFallback;
                },
            errorBuilder: (BuildContext context, Object error, StackTrace? st) {
              _scheduleRetry();
              return widget.errorBuilder(context);
            },
          );
        }
        return CachedNetworkImage(
          key: ValueKey<String>(_effectiveUrl),
          imageUrl: _effectiveUrl,
          fit: widget.fit,
          memCacheWidth: cacheWidth,
          placeholder: widget.placeholder != null
              ? (_, _) => loadingFallback
              : null,
          errorWidget: (BuildContext context, String url, Object error) {
            _scheduleRetry();
            return widget.errorBuilder(context);
          },
        );
      },
    );
  }
}
