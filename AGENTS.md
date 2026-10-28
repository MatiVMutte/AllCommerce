
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
