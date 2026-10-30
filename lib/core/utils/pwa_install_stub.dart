/// Non-web fallback: PWA install prompt is unavailable outside the web.
bool canInstallPwa() => false;

Future<bool> promptPwaInstall() async => false;
