// Genera los PNG legacy de ic_launcher (pre-API 26) a partir del glifo del
// logo: hexágono + X + llaves. Uso: dart run tool/generate_launcher_icons.dart
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

void _paintGlyph(ui.Canvas canvas, double s) {
  canvas.scale(s / 108);
  final ui.Paint blue = ui.Paint()
    ..color = const ui.Color(0xFF1E88E5)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeJoin = ui.StrokeJoin.round
    ..strokeCap = ui.StrokeCap.round;
  final ui.Paint navy = ui.Paint()
    ..color = const ui.Color(0xFF1A237E)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = ui.StrokeCap.round;

  final ui.Path hex = ui.Path()
    ..moveTo(54, 32)
    ..lineTo(73, 43)
    ..lineTo(73, 65)
    ..lineTo(54, 76)
    ..lineTo(35, 65)
    ..lineTo(35, 43)
    ..close();
  canvas.drawPath(hex, blue);

  final ui.Path x = ui.Path()
    ..moveTo(35, 43)..lineTo(54, 54)
    ..moveTo(73, 43)..lineTo(54, 54)
    ..moveTo(54, 54)..lineTo(73, 65)
    ..moveTo(54, 54)..lineTo(35, 65);
  canvas.drawPath(x, blue);

  final ui.Path left = ui.Path()
    ..moveTo(27, 37)
    ..cubicTo(22, 37, 22, 43, 22, 47)
    ..lineTo(22, 50)
    ..cubicTo(22, 52, 20, 54, 18, 54)
    ..cubicTo(20, 54, 22, 56, 22, 58)
    ..lineTo(22, 61)
    ..cubicTo(22, 65, 22, 71, 27, 71);
  canvas.drawPath(left, navy);

  final ui.Path right = ui.Path()
    ..moveTo(81, 37)
    ..cubicTo(86, 37, 86, 43, 86, 47)
    ..lineTo(86, 50)
    ..cubicTo(86, 52, 88, 54, 90, 54)
    ..cubicTo(88, 54, 86, 56, 86, 58)
    ..lineTo(86, 61)
    ..cubicTo(86, 65, 86, 71, 81, 71);
  canvas.drawPath(right, navy);
}

Future<Uint8List> _render(int size, {required bool round}) async {
  final ui.PictureRecorder rec = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(rec);
  if (round) {
    canvas.drawCircle(
      ui.Offset(size / 2, size / 2),
      size / 2,
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
  } else {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
  }
  _paintGlyph(canvas, size.toDouble());
  final ui.Image img =
      await rec.endRecording().toImage(size, size);
  final ByteData? data =
      await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<void> main() async {
  for (final MapEntry<String, int> e in _densities.entries) {
    final String dir =
        'android/app/src/main/res/mipmap-${e.key}';
    await File('$dir/ic_launcher.png')
        .writeAsBytes(await _render(e.value, round: false));
    await File('$dir/ic_launcher_round.png')
        .writeAsBytes(await _render(e.value, round: true));
    stdout.writeln('${e.key}: ${e.value}px');
  }
}
