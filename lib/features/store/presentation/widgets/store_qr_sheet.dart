import 'dart:ui' as ui;

import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/file_download/file_download.dart';
import 'package:all_commerce/core/utils/share_service.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Bottom sheet with the store's catalog QR: meant to be printed and
/// stuck on the counter/window so walk-ins land on the catalog.
///
/// `isScrollControlled: true` is required — without it the sheet is
/// capped at ~half the screen and the tall QR content gets clipped.
Future<void> showStoreQrSheet(BuildContext context, TenantModel tenant) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) =>
        _StoreQrSheet(parentContext: context, tenant: tenant),
  );
}

class _StoreQrSheet extends StatelessWidget {
  const _StoreQrSheet({required this.parentContext, required this.tenant});

  /// The view's context — snackbars pop after the sheet is dismissed.
  final BuildContext parentContext;
  final TenantModel tenant;

  String get _url => ShareService.catalogUrl(tenant.slug);

  Future<void> _downloadPng() async {
    try {
      final QrPainter painter = QrPainter(
        data: _url,
        version: QrVersions.auto,
        gapless: true,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );
      final ByteData? data = await painter.toImageData(
        640,
        format: ui.ImageByteFormat.png,
      );
      if (data == null) return;
      final Uint8List bytes = data.buffer.asUint8List();
      final String filename = 'qr-${tenant.slug}.png';
      final bool downloaded = await downloadFile(
        filename: filename,
        bytes: bytes,
        mimeType: 'image/png',
      );
      if (!downloaded) {
        // Non-web platforms: hand it to the share sheet instead.
        await SharePlus.instance.share(
          ShareParams(
            files: <XFile>[
              XFile.fromData(bytes, mimeType: 'image/png', name: filename),
            ],
            subject: 'QR de ${tenant.name}',
          ),
        );
      }
      if (parentContext.mounted) {
        showAppSnackBar(parentContext, 'QR listo para imprimir');
      }
    } catch (_) {
      if (parentContext.mounted) {
        showAppSnackBar(
          parentContext,
          'No se pudo generar el QR',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    // viewPadding reports the system inset even if an ancestor consumed
    // `padding` — keeps the buttons clear of the Android gesture/nav bar.
    final double bottom = MediaQuery.viewPaddingOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                tenant.name,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Pegá este QR en el mostrador o la vidriera:\nquien lo escanea entra directo a tu catálogo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tokens.border),
                ),
                child: QrImageView(
                  data: _url,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _url,
                style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Descargar PNG'),
                      onPressed: _downloadPng,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Copiar link',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _url));
                      if (parentContext.mounted) {
                        showAppSnackBar(parentContext, 'Link copiado');
                      }
                    },
                    icon: const Icon(Icons.copy_outlined),
                  ),
                  IconButton(
                    tooltip: 'Compartir',
                    onPressed: () async {
                      await const ShareService().shareLink(
                        url: _url,
                        text:
                            'Mirá el catálogo de ${tenant.name}: precios actualizados y pedidos directo',
                      );
                    },
                    icon: const Icon(Icons.ios_share_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
