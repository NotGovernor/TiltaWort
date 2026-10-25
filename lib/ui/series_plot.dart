import 'package:flutter/material.dart';
import 'package:tiltawort/tilt/history.dart';

/// Hairline polyline. Empty list paints nothing — never a fake 1.000.
class SeriesPlot extends StatelessWidget {
  const SeriesPlot({
    super.key,
    required this.samples,
    required this.line,
    required this.yOf,
    this.height = 140,
  });

  final List<SessionSample> samples;
  final Color line;
  final double Function(SessionSample) yOf;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: SeriesPainter(samples: samples, line: line, yOf: yOf),
      ),
    );
  }
}

class SeriesPainter extends CustomPainter {
  SeriesPainter({
    required this.samples,
    required this.line,
    required this.yOf,
  });

  final List<SessionSample> samples;
  final Color line;
  final double Function(SessionSample) yOf;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.width <= 0 || size.height <= 0) return;

    var minY = yOf(samples.first);
    var maxY = minY;
    for (final s in samples) {
      final y = yOf(s);
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    if (minY == maxY) {
      minY -= 0.001;
      maxY += 0.001;
    }

    final minX = samples.first.at.millisecondsSinceEpoch.toDouble();
    final maxX = samples.last.at.millisecondsSinceEpoch.toDouble();
    final spanX = maxX == minX ? 1.0 : maxX - minX;
    final spanY = maxY - minY;

    final path = Path();
    Offset? last;
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      final x = (s.at.millisecondsSinceEpoch - minX) / spanX * size.width;
      final y = size.height - ((yOf(s) - minY) / spanY * size.height);
      final pt = Offset(x, y);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
      last = pt;
    }

    final paint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    if (samples.length == 1 && last != null) {
      canvas.drawCircle(last, 3, Paint()..color = line);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(SeriesPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.line != line;
}
