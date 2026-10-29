// Genera los íconos de AllCommerce ({ bolsa + chispa IA }) para Android,
// Web y Windows.
import 'dart:io';
import 'dart:math' as math;
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
    ..strokeWidth = 4.2
    ..strokeJoin = ui.StrokeJoin.round
    ..strokeCap = ui.StrokeCap.round;
  final ui.Paint blueFill = ui.Paint()
    ..color = const ui.Color(0xFF0A68CC)
    ..style = ui.PaintingStyle.fill;
  final ui.Paint navyStroke = ui.Paint()
    ..color = const ui.Color(0xFF142882)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 4.2
    ..strokeJoin = ui.StrokeJoin.round
    ..strokeCap = ui.StrokeCap.round;

  // Llave izquierda {
  final ui.Path leftBrace = ui.Path()
    ..moveTo(29, 36)
    ..cubicTo(24, 36, 24, 41, 24, 46)
    ..lineTo(24, 50)
    ..cubicTo(24, 52.5, 22, 54, 19.5, 54)
    ..cubicTo(22, 54, 24, 55.5, 24, 58)
    ..lineTo(24, 62)
    ..cubicTo(24, 67, 24, 72, 29, 72);
  c.drawPath(leftBrace, navyStroke);

  // Llave derecha }
  final ui.Path rightBrace = ui.Path()
    ..moveTo(79, 36)
    ..cubicTo(84, 36, 84, 41, 84, 46)
    ..lineTo(84, 50)
    ..cubicTo(84, 52.5, 86, 54, 88.5, 54)
    ..cubicTo(86, 54, 84, 55.5, 84, 58)
    ..lineTo(84, 62)
    ..cubicTo(84, 67, 84, 72, 79, 72);
  c.drawPath(rightBrace, navyStroke);

  // Manija de la bolsa (arco superior)
  final ui.Path handle = ui.Path()
    ..moveTo(45.5, 45)
    ..lineTo(45.5, 40.5)
    ..arcTo(
      const ui.Rect.fromLTWH(45.5, 32, 17, 17),
      math.pi,
      math.pi,
      false,
    )
    ..lineTo(62.5, 45);
  c.drawPath(handle, blueStroke);

  // Cuerpo de la bolsa
  final ui.Path bag = ui.Path()
    ..moveTo(38, 45)
    ..lineTo(70, 45)
    ..lineTo(68, 72)
    ..lineTo(40, 72)
    ..close();
  c.drawPath(bag, blueStroke);

  // Chispa / estrella de IA dentro de la bolsa
  final ui.Path spark = ui.Path()
    ..moveTo(54, 50.5)
    ..lineTo(56, 56.5)
    ..lineTo(62, 58.5)
    ..lineTo(56, 60.5)
    ..lineTo(54, 66.5)
    ..lineTo(52, 60.5)
    ..lineTo(46, 58.5)
    ..lineTo(52, 56.5)
    ..close();
  c.drawPath(spark, blueFill);
}

Future<Uint8List> renderIcon(
  int size, {
  bool round = false,
  double pad = 0,
  double glyphScale = 0.95,
}) async {
  final ui.PictureRecorder rec = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(rec);
  final ui.Paint white = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  // Logo circular: esquinas transparentes y glifo dentro del círculo.
  canvas.drawCircle(ui.Offset(size / 2, size / 2), size / 2, white);
  canvas.save();
  canvas.clipPath(
    ui.Path()
      ..addOval(ui.Rect.fromCircle(
          center: ui.Offset(size / 2, size / 2), radius: size / 2)),
  );
  final double base = size * (1 - pad * 2);
  canvas.translate(size / 2, size / 2);
  canvas.scale(glyphScale);
  canvas.translate(-base / 2, -base / 2);
  paintAllCommerceGlyph(canvas, base);
  canvas.restore();
  final ui.Image img = await rec.endRecording().toImage(size, size);
  final ByteData? data =
      await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
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
  for (final MapEntry<String, int> e in _densities.entries) {
    final String dir = 'android/app/src/main/res/mipmap-${e.key}';
    await File('$dir/ic_launcher.png')
        .writeAsBytes(await renderIcon(e.value, round: false));
    await File('$dir/ic_launcher_round.png')
        .writeAsBytes(await renderIcon(e.value, round: true));
  }
  await File('web/favicon.png')
      .writeAsBytes(await renderIcon(64, round: false));
  await File('web/icons/Icon-192.png')
      .writeAsBytes(await renderIcon(192, round: false));
  await File('web/icons/Icon-512.png')
      .writeAsBytes(await renderIcon(512, round: false));
  await File('web/icons/Icon-maskable-192.png')
      .writeAsBytes(await renderIcon(192, round: false, pad: 0.16));
  await File('web/icons/Icon-maskable-512.png')
      .writeAsBytes(await renderIcon(512, round: false, pad: 0.16));
  const List<int> sizes = <int>[16, 32, 48, 64, 128, 256];
  final List<Uint8List> pngs = <Uint8List>[
    for (final int s in sizes) await renderIcon(s, round: false),
  ];
  await writeIco('windows/runner/resources/app_icon.ico', pngs, sizes);
}

Future<void> main() => generateAllPlatformIcons();
