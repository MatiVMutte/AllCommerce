// Genera los íconos de AllCommerce desde assets/brand_icon.png
// para Android (legacy + adaptive + splash), Web (favicon + PWA + maskable) y Windows (.ico).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

const Map<String, int> _densities = <String, int>{
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

const Map<String, int> _foregroundDensities = <String, int>{
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};

const ui.Color _brandBlue = ui.Color(0xFF0066FF);

Future<ui.Image> _loadSourceIcon() async {
  final Uint8List bytes = await File('assets/brand_icon.png').readAsBytes();
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  return frame.image;
}

Future<Uint8List> renderIcon(
  ui.Image source,
  int size, {
  bool round = false,
  double cornerFactor = 0,
  double pad = 0,
}) async {
  final ui.PictureRecorder rec = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(rec);
  final ui.Rect fullRect = ui.Rect.fromLTWH(
    0,
    0,
    size.toDouble(),
    size.toDouble(),
  );

  canvas.save();
  if (round) {
    canvas.clipPath(ui.Path()..addOval(fullRect));
  } else if (cornerFactor > 0) {
    canvas.clipRRect(
      ui.RRect.fromRectAndRadius(
        fullRect,
        ui.Radius.circular(size * cornerFactor),
      ),
    );
  }

  canvas.drawRect(fullRect, ui.Paint()..color = _brandBlue);

  final double inset = size * pad;
  final ui.Rect dst = ui.Rect.fromLTWH(
    inset,
    inset,
    size - inset * 2,
    size - inset * 2,
  );
  final ui.Rect src = ui.Rect.fromLTWH(
    0,
    0,
    source.width.toDouble(),
    source.height.toDouble(),
  );
  canvas.drawImageRect(
    source,
    src,
    dst,
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  canvas.restore();

  final ui.Image img = await rec.endRecording().toImage(size, size);
  return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer
      .asUint8List();
}

Future<void> writeIco(
  String path,
  List<Uint8List> pngs,
  List<int> sizes,
) async {
  final BytesBuilder out = BytesBuilder();
  out.add(<int>[0, 0, 1, 0]);
  out.add(<int>[pngs.length & 0xFF, 0]);
  int offset = 6 + 16 * pngs.length;
  for (int i = 0; i < pngs.length; i++) {
    final int s = sizes[i] >= 256 ? 0 : sizes[i];
    out.add(<int>[s, s, 0, 0]);
    out.add(<int>[1, 0]);
    out.add(<int>[32, 0]);
    final int len = pngs[i].length;
    out.add(<int>[
      len & 0xFF,
      (len >> 8) & 0xFF,
      (len >> 16) & 0xFF,
      (len >> 24) & 0xFF,
    ]);
    out.add(<int>[
      offset & 0xFF,
      (offset >> 8) & 0xFF,
      (offset >> 16) & 0xFF,
      (offset >> 24) & 0xFF,
    ]);
    offset += len;
  }
  for (final Uint8List p in pngs) {
    out.add(p);
  }
  await File(path).writeAsBytes(out.toBytes());
}

Future<void> generateAllPlatformIcons() async {
  final ui.Image source = await _loadSourceIcon();

  for (final MapEntry<String, int> e in _densities.entries) {
    final String dir = 'android/app/src/main/res/mipmap-${e.key}';
    await File('$dir/ic_launcher.png')
        .writeAsBytes(await renderIcon(source, e.value, cornerFactor: 0.22));
    await File('$dir/ic_launcher_round.png')
        .writeAsBytes(await renderIcon(source, e.value, round: true));
  }

  for (final MapEntry<String, int> e in _foregroundDensities.entries) {
    final String dir = 'android/app/src/main/res/mipmap-${e.key}';
    await File('$dir/ic_launcher_foreground.png')
        .writeAsBytes(await renderIcon(source, e.value, pad: 0.06));
  }

  await File('android/app/src/main/res/drawable-nodpi/splash_brand_logo.png')
      .writeAsBytes(await renderIcon(source, 512));

  await File('web/favicon.png')
      .writeAsBytes(await renderIcon(source, 64, cornerFactor: 0.22));
  await File('web/icons/Icon-192.png')
      .writeAsBytes(await renderIcon(source, 192));
  await File('web/icons/Icon-512.png')
      .writeAsBytes(await renderIcon(source, 512));
  await File('web/icons/Icon-maskable-192.png')
      .writeAsBytes(await renderIcon(source, 192));
  await File('web/icons/Icon-maskable-512.png')
      .writeAsBytes(await renderIcon(source, 512));

  const List<int> sizes = <int>[16, 32, 48, 64, 128, 256];
  final List<Uint8List> pngs = <Uint8List>[
    for (final int s in sizes) await renderIcon(source, s, cornerFactor: 0.22),
  ];
  await writeIco('windows/runner/resources/app_icon.ico', pngs, sizes);
}

Future<void> main() => generateAllPlatformIcons();
