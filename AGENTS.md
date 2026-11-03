
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

## Build de Windows: geolocator_windows necesita fuente NuGet

`geolocator` (usado por "Cerca de vos") trae `geolocator_windows`, que en
CMake corre `nuget install Microsoft.Windows.CppWinRT ...` SIN `-Source`.
Si la máquina no tiene ninguna fuente NuGet configurada, falla con
`Argument cannot be null or empty, primarySources` →
`Failed to install nuget package` → "Unable to generate build files".

Fix (una sola vez por máquina, persiste): crear
`%APPDATA%\NuGet\NuGet.Config` con la fuente oficial:

    <?xml version="1.0" encoding="utf-8"?>
    <configuration>
      <packageSources>
        <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
      </packageSources>
    </configuration>

## MediaQuery.padding.bottom ya incluye la FloatingNavBar dentro del shell

Scaffold propaga la altura de su `bottomNavigationBar` al `MediaQuery.padding.bottom` del `body` (la FloatingNavBar mide ~116: pill 76 + margen 16 + safe area). Por eso dentro de una pantalla del shell `padding.bottom ≈ 116`, no solo el inset del sistema.

- Para elementos FIJOS arriba de la barra (input de chat, FAB manual): usar `MediaQuery.of(context).padding.bottom + gap` — NO sumar `FloatingNavBar.height` encima, eso la cuenta dos veces (~212dp, el elemento queda a media pantalla).
- `FloatingNavBar.height` (96) solo sirve como padding de fin de LISTAS scrolleables (convención existente; queda levemente corto pero no se nota).
- `viewPadding.bottom` dentro del body ya viene consumido a 0 por el Scaffold — no sirve para leer el inset crudo del sistema.

Test de referencia: `test/features/ai_chat/owner_ai_input_position_test.dart`.

## FilledButton / OutlinedButton dentro de un Row = crash de layout

En `app_theme.dart` los estilos de botones tienen `minimumSize: Size.fromHeight(52)` (`Size(∞, 52)`), por lo que todo `FilledButton` y `OutlinedButton` tiene ancho mínimo infinito. En un `Column` con ancho acotado se ve como botón a todo lo ancho, pero dentro de un `Row` o scroll horizontal sin ancho acotado lanza `BoxConstraints forces an infinite width` y congela la pantalla. Siempre envolver botones dentro de un `Row` con `Expanded` o `Flexible`.
