import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/pwa_install.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// "Instalá AllCommerce" banner shown only on web when the browser
/// offers an install prompt. Polls briefly because the
/// `beforeinstallprompt` event may fire after the first frame.
class InstallAppCard extends StatefulWidget {
  const InstallAppCard({super.key});

  @override
  State<InstallAppCard> createState() => _InstallAppCardState();
}

class _InstallAppCardState extends State<InstallAppCard> {
  bool _canInstall = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _checked = true;
      return;
    }
    _poll();
  }

  Future<void> _poll() async {
    for (int i = 0; i < 12 && mounted && !_canInstall; i++) {
      if (canInstallPwa()) {
        setState(() {
          _canInstall = true;
          _checked = true;
        });
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (mounted) setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_checked || !_canInstall) {
      return const SizedBox.shrink();
    }
    final AppTokens tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.download_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Instalá AllCommerce en este dispositivo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final bool started = await promptPwaInstall();
                if (!started && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Usá el ícono de instalar en la barra del navegador.',
                      ),
                    ),
                  );
                } else if (context.mounted) {
                  setState(() => _canInstall = false);
                }
              },
              child: const Text('Instalar'),
            ),
          ],
        ),
      ),
    );
  }
}
