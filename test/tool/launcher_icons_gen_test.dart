import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const Map<String, int> _d = <String, int>{
  'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192,
};

void _g(ui.Canvas c, double s) {
  c.scale(s / 108);
  final ui.Paint b = ui.Paint()
    ..color = const ui.Color(0xFF1E88E5)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeJoin = ui.StrokeJoin.round
    ..strokeCap = ui.StrokeCap.round;
  final ui.Paint n = ui.Paint()
    ..color = const ui.Color(0xFF1A237E)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = ui.StrokeCap.round;
  c.drawPath(ui.Path()
    ..moveTo(54, 32)..lineTo(73, 43)..lineTo(73, 65)..lineTo(54, 76)
    ..lineTo(35, 65)..lineTo(35, 43)..close(), b);
  c.drawPath(ui.Path()
    ..moveTo(35, 43)..lineTo(54, 54)..moveTo(73, 43)..lineTo(54, 54)
    ..moveTo(54, 54)..lineTo(73, 65)..moveTo(54, 54)..lineTo(35, 65), b);
  c.drawPath(ui.Path()
    ..moveTo(27, 37)..cubicTo(22, 37, 22, 43, 22, 47)..lineTo(22, 50)
    ..cubicTo(22, 52, 20, 54, 18, 54)..cubicTo(20, 54, 22, 56, 22, 58)
    ..lineTo(22, 61)..cubicTo(22, 65, 22, 71, 27, 71), n);
  c.drawPath(ui.Path()
    ..moveTo(81, 37)..cubicTo(86, 37, 86, 43, 86, 47)..lineTo(86, 50)
    ..cubicTo(86, 52, 88, 54, 90, 54)..cubicTo(88, 54, 86, 56, 86, 58)
    ..lineTo(86, 61)..cubicTo(86, 65, 86, 71, 81, 71), n);
}

Future<Uint8List> _r(int size, {required bool round, double pad = 0}) async {
  final ui.PictureRecorder rec = ui.PictureRecorder();
  final ui.Canvas c = ui.Canvas(rec);
  final ui.Paint w = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  if (round) {
    c.drawCircle(ui.Offset(size / 2, size / 2), size / 2, w);
  } else {
    c.drawRect(ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), w);
  }
  final double glyph = size * (1 - pad * 2);
  c.translate(size * pad, size * pad);
  _g(c, glyph);
  final ui.Image i = await rec.endRecording().toImage(size, size);
  return (await i.toByteData(format: ui.ImageByteFormat.png))!
      .buffer.asUint8List();
}

Future<void> _writeIco(
    String path, List<Uint8List> pngs, List<int> sizes) async {
  final BytesBuilder out = BytesBuilder();
  out.add(<int>[0, 0, 1, 0]); // reserved + type(1=ICO)
  out.add(<int>[pngs.length & 0xFF, 0]); // count
  int offset = 6 + 16 * pngs.length;
  for (int i = 0; i < pngs.length; i++) {
    final int s = sizes[i] >= 256 ? 0 : sizes[i];
    out.add(<int>[s, s, 0, 0]); // w, h, colors, reserved
    out.add(<int>[1, 0]); // planes
    out.add(<int>[32, 0]); // bpp
    final int len = pngs[i].length;
    out.add(<int>[len & 0xFF, (len >> 8) & 0xFF, (len >> 16) & 0xFF,
        (len >> 24) & 0xFF]);
    out.add(<int>[offset & 0xFF, (offset >> 8) & 0xFF,
        (offset >> 16) & 0xFF, (offset >> 24) & 0xFF]);
    offset += len;
  }
  for (final Uint8List p in pngs) {
    out.add(p);
  }
  await File(path).writeAsBytes(out.toBytes());
}

void main() {
  test('write all platform launcher icons', () async {
    // Android legacy mipmaps
    for (final MapEntry<String, int> e in _d.entries) {
      final String dir = 'android/app/src/main/res/mipmap-${e.key}';
      await File('$dir/ic_launcher.png')
          .writeAsBytes(await _r(e.value, round: false));
      await File('$dir/ic_launcher_round.png')
          .writeAsBytes(await _r(e.value, round: true));
    }
    // Web favicon + PWA icons (maskable con padding ~20%)
    await File('web/favicon.png').writeAsBytes(await _r(64, round: false));
    await File('web/icons/Icon-192.png')
        .writeAsBytes(await _r(192, round: false));
    await File('web/icons/Icon-512.png')
        .writeAsBytes(await _r(512, round: false));
    await File('web/icons/Icon-maskable-192.png')
        .writeAsBytes(await _r(192, round: false, pad: 0.2));
    await File('web/icons/Icon-maskable-512.png')
        .writeAsBytes(await _r(512, round: false, pad: 0.2));
    // Windows .ico multi-size
    const List<int> sizes = <int>[16, 32, 48, 64, 128, 256];
    final List<Uint8List> pngs = <Uint8List>[
      for (final int s in sizes) await _r(s, round: false),
    ];
    await _writeIco('windows/runner/resources/app_icon.ico', pngs, sizes);
  });
}
