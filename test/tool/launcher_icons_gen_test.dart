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

Future<Uint8List> _r(int size, {required bool round}) async {
  final ui.PictureRecorder rec = ui.PictureRecorder();
  final ui.Canvas c = ui.Canvas(rec);
  final ui.Paint w = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  if (round) {
    c.drawCircle(ui.Offset(size / 2, size / 2), size / 2, w);
  } else {
    c.drawRect(ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), w);
  }
  _g(c, size.toDouble());
  final ui.Image i = await rec.endRecording().toImage(size, size);
  return (await i.toByteData(format: ui.ImageByteFormat.png))!
      .buffer.asUint8List();
}

void main() {
  test('write legacy launcher PNGs', () async {
    for (final MapEntry<String, int> e in _d.entries) {
      final String dir = 'android/app/src/main/res/mipmap-${e.key}';
      await File('$dir/ic_launcher.png')
          .writeAsBytes(await _r(e.value, round: false));
      await File('$dir/ic_launcher_round.png')
          .writeAsBytes(await _r(e.value, round: true));
    }
  });
}
