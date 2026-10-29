// Genera los íconos de AllCommerce (hexágono-tienda con toldo + bolsita)
// para Android, Web y Windows.
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

void paintAllCommerceGlyph(ui.Canvas c, double s) {
  c.scale(s / 108);
  final ui.Paint blueStroke = ui.Paint()
    ..color = const ui.Color(0xFF0A68CC)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeJoin = ui.StrokeJoin.round
    ..strokeCap = ui.StrokeCap.round;
  final ui.Paint blueFill = ui.Paint()
    ..color = const ui.Color(0xFF0A68CC);
  final ui.Paint navyStroke = ui.Paint()
    ..color = const ui.Color(0xFF142882)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = ui.StrokeCap.round;
  final ui.Paint navyFill = ui.Paint()
    ..color = const ui.Color(0xFF142882);

  // Lados y base del hexágono.
  c.drawPath(ui.Path()
    ..moveTo(37, 44)
    ..lineTo(37, 64)
    ..lineTo(54, 74)
    ..lineTo(71, 64)
    ..lineTo(71, 44), blueStroke);

  // Toldo sólido con borde ondulado.
  c.drawPath(ui.Path()
    ..moveTo(36, 38)
    ..lineTo(72, 38)
    ..lineTo(72, 44)
    ..relativeQuadraticBezierTo(-3, 6, -6, 0)
    ..relativeQuadraticBezierTo(-3, 6, -6, 0)
    ..relativeQuadraticBezierTo(-3, 6, -6, 0)
    ..relativeQuadraticBezierTo(-3, 6, -6, 0)
    ..relativeQuadraticBezierTo(-3, 6, -6, 0)
    ..relativeQuadraticBezierTo(-3, 6, -6, 0)
    ..close(), blueFill);

  // Manija de la bolsita.
  c.drawPath(ui.Path()
    ..moveTo(49.5, 58)
    ..lineTo(49.5, 54.5)
    ..arcTo(const ui.Rect.fromLTWH(49.5, 50, 9, 9), 3.14159, 3.14159, false)
    ..lineTo(58.5, 58), navyStroke);

  // Cuerpo de la bolsita (relleno).
  c.drawPath(ui.Path()
    ..moveTo(46.5, 58)
    ..lineTo(61.5, 58)
    ..lineTo(60.4, 66)
    ..lineTo(47.6, 66)
    ..close(), navyFill);
}

Future<Uint8List> renderIcon(
  int size, {
  bool round = false,
  double pad = 0,
  double glyphScale = 1.1,
}) async {
  final ui.PictureRecorder rec = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(rec);
  final ui.Paint white = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  canvas.drawCircle(ui.Offset(size / 2, size / 2), size / 2, white);
  canvas.save();
  canvas.clipPath(ui.Path()
    ..addOval(ui.Rect.fromCircle(
        center: ui.Offset(size / 2, size / 2), radius: size / 2)));
  final double base = size * (1 - pad * 2);
  canvas.translate(size / 2, size / 2);
  canvas.scale(glyphScale);
  canvas.translate(-base / 2, -base / 2);
  paintAllCommerceGlyph(canvas, base);
  canvas.restore();
  final ui.Image img = await rec.endRecording().toImage(size, size);
  return (await img.toByteData(format: ui.ImageByteFormat.png))!
      .buffer.asUint8List();
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
    out.add(<int>[len & 0xFF, (len >> 8) & 0xFF,
        (len >> 16) & 0xFF, (len >> 24) & 0xFF]);
    out.add(<int>[offset & 0xFF, (offset >> 8) & 0xFF,
        (offset >> 16) & 0xFF, (offset >> 24) & 0xFF]);
    offset += len;
  }
  for (final Uint8List p in pngs) {
    out.add(p);
  }
  await File(path).writeAsBytes(out.toBytes());
}

Future<void> generateAllPlatformIcons() async {
  for (final MapEntry<String, int> e in _densities.entries) {
    final String dir = 'android/app/src/main/res/mipmap-${e.key}';
    await File('$dir/ic_launcher.png')
        .writeAsBytes(await renderIcon(e.value));
    await File('$dir/ic_launcher_round.png')
        .writeAsBytes(await renderIcon(e.value));
  }
  await File('web/favicon.png').writeAsBytes(await renderIcon(64));
  await File('web/icons/Icon-192.png').writeAsBytes(await renderIcon(192));
  await File('web/icons/Icon-512.png').writeAsBytes(await renderIcon(512));
  await File('web/icons/Icon-maskable-192.png')
      .writeAsBytes(await renderIcon(192, pad: 0.18));
  await File('web/icons/Icon-maskable-512.png')
      .writeAsBytes(await renderIcon(512, pad: 0.18));
  const List<int> sizes = <int>[16, 32, 48, 64, 128, 256];
  final List<Uint8List> pngs = <Uint8List>[
    for (final int s in sizes) await renderIcon(s),
  ];
  await writeIco('windows/runner/resources/app_icon.ico', pngs, sizes);
}

Future<void> main() => generateAllPlatformIcons();
