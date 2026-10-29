
## flutter run en Xiaomi/HyperOS (duchamp, Android 16)

Este teléfono filtra TODOS los logs de apps de terceros en logcat
(`log.tag` global = M). Como `flutter run` descubre el VM service leyendo
la línea "A Dart VM Service on..." de logcat, se quedaba colgado en
"Installing app-debug.apk" y terminaba con
"The log reader stopped unexpectedly". La app en sí corría bien.

Fix (una sola vez, persiste entre reinicios):

    adb shell setprop persist.log.tag.flutter V

Si hay que ver logs de otras tags nativas (Firebase, plugins), repetir con
persist.log.tag.<TAG>. Tags alternativa menos granular: persist.log.tag con
valor de nivel (ej. V) abre todo, pero ensucia el log.

## FilledButton/OutlinedButton in Row = layout crash

app_theme.dart의 버튼 테마가 `minimumSize: Size.fromHeight(52)` (= Size(∞,52))라서
모든 FilledButton/OutlinedButton의 최소 너비가 무한대다. Column 등 너비가
제한된 곳에선 전체 너비 버튼으로 보이지만, Row·가로 스크롤처럼 폭이
unbounded인 곳에 넣으면 "BoxConstraints forces an infinite width"로 crash →
화면이 통째로 멈춘다. Row 안 버튼은 반드시 Expanded/Flexible로 감쌀 것.
