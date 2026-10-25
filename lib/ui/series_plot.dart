import 'package:flutter/material.dart';
import 'package:tiltawort/tilt/history.dart';
import 'package:tiltawort/tilt/units.dart';

const chartWindow = Duration(hours: 2);

({DateTime start, DateTime end}) chartSpan(
  List<SessionSample> samples, {
  DateTime? now,
}) {
  if (samples.isEmpty) {
    final end = now ?? DateTime.now();
    return (start: end, end: end.add(const Duration(milliseconds: 1)));
  }
  var start = samples.first.at;
  var end = samples.first.at;
  for (final s in samples) {
    if (s.at.isBefore(start)) start = s.at;
    if (s.at.isAfter(end)) end = s.at;
  }
  if (!end.isAfter(start)) {
    end = start.add(const Duration(milliseconds: 1));
  }
  return (start: start, end: end);
}

List<SessionSample> samplesInWindow(
  List<SessionSample> samples, {
  required DateTime end,
  Duration window = chartWindow,
}) {
  final start = end.subtract(window);
  return [
    for (final s in samples)
      if (!s.at.isBefore(start) && !s.at.isAfter(end)) s,
  ];
}

String axisTime(DateTime at) {
  final l = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.hour)}:${two(l.minute)}';
}

/// Hairline polyline in a 2-hour window. Empty list paints nothing — never a fake 1.000.
class SeriesPlot extends StatefulWidget {
  const SeriesPlot({
    super.key,
    required this.samples,
    required this.line,
    required this.yOf,
    required this.now,
    this.yFormat,
    this.height = 140,
    this.window = chartWindow,
    this.pan = Duration.zero,
    this.onPan,
  });

  final List<SessionSample> samples;
  final Color line;
  final double Function(SessionSample) yOf;
  final DateTime now;
  final String Function(double y)? yFormat;
  final double height;
  final Duration window;
  final Duration pan;
  final ValueChanged<Duration>? onPan;

  @override
  State<SeriesPlot> createState() => _SeriesPlotState();
}

class _SeriesPlotState extends State<SeriesPlot> {
  double? _hoverX;
  double _plotWidth = 240;

  DateTime get _end {
    final span = chartSpan(widget.samples, now: widget.now);
    return span.end.subtract(widget.pan);
  }

  DateTime get _start {
    final span = chartSpan(widget.samples, now: widget.now);
    return _end.subtract(span.end.difference(span.start));
  }

  Duration get _window => _end.difference(_start);

  String _fmt(double y) => widget.yFormat?.call(y) ?? y.toStringAsFixed(3);

  SessionSample? _nearest(double x, double width) {
    final visible = samplesInWindow(widget.samples, end: _end, window: _window);
    if (visible.isEmpty || width <= 0) return null;
    final span = _window.inMilliseconds.toDouble();
    SessionSample? best;
    var bestDx = double.infinity;
    for (final s in visible) {
      final sx = s.at.difference(_start).inMilliseconds / span * width;
      final dx = (sx - x).abs();
      if (dx < bestDx) {
        bestDx = dx;
        best = s;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final visible = samplesInWindow(widget.samples, end: _end, window: _window);
    var minY = 0.0;
    var maxY = 1.0;
    if (visible.isNotEmpty) {
      minY = widget.yOf(visible.first);
      maxY = minY;
      for (final s in visible) {
        final y = widget.yOf(s);
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
      if (minY == maxY) {
        minY -= 0.001;
        maxY += 0.001;
      }
    }
    final midY = (minY + maxY) / 2;
    final hover = _hoverX == null ? null : _nearest(_hoverX!, _plotWidth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hover != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${_fmt(widget.yOf(hover))} · ${localStamp(hover.at)}',
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 11,
                color: widget.line,
              ),
            ),
          ),
        SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 52,
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 10,
                    color: widget.line.withValues(alpha: 0.85),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_fmt(maxY)),
                      const Spacer(),
                      Text(_fmt(midY)),
                      const Spacer(),
                      Text(_fmt(minY)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _plotWidth = constraints.maxWidth;
                    return MouseRegion(
                      onExit: (_) => setState(() => _hoverX = null),
                      child: Listener(
                  onPointerHover: (e) => setState(() => _hoverX = e.localPosition.dx),
                  onPointerDown: (e) => setState(() => _hoverX = e.localPosition.dx),
                  onPointerMove: (e) => setState(() => _hoverX = e.localPosition.dx),
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) {
                      final box = context.findRenderObject() as RenderBox?;
                      final width = box?.size.width ?? 1;
                      final ms = _window.inMilliseconds;
                      final shift = (d.delta.dx / width * ms).round();
                      var next = widget.pan + Duration(milliseconds: shift);
                      if (next.isNegative) next = Duration.zero;
                      widget.onPan?.call(next);
                    },
                    child: CustomPaint(
                      painter: SeriesPainter(
                        samples: widget.samples,
                        line: widget.line,
                        yOf: widget.yOf,
                        start: _start,
                        end: _end,
                        hoverX: _hoverX,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                    ),
                );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 58),
          child: DefaultTextStyle(
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 10,
              color: widget.line.withValues(alpha: 0.85),
            ),
            child: Row(
              children: [
                Text(axisTime(_start)),
                const Spacer(),
                Text(axisTime(_start.add(Duration(milliseconds: _window.inMilliseconds ~/ 2)))),
                const Spacer(),
                Text(axisTime(_end)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SeriesPainter extends CustomPainter {
  SeriesPainter({
    required this.samples,
    required this.line,
    required this.yOf,
    required this.start,
    required this.end,
    this.hoverX,
  });

  final List<SessionSample> samples;
  final Color line;
  final double Function(SessionSample) yOf;
  final DateTime start;
  final DateTime end;
  final double? hoverX;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final visible = samplesInWindow(samples, end: end, window: end.difference(start));
    final spanX = end.difference(start).inMilliseconds.toDouble().clamp(1, double.infinity);

    var minY = visible.isEmpty ? 0.0 : yOf(visible.first);
    var maxY = minY;
    for (final s in visible) {
      final y = yOf(s);
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    if (minY == maxY) {
      minY -= 0.001;
      maxY += 0.001;
    }
    final spanY = maxY - minY;

    final grid = Paint()
      ..color = line.withValues(alpha: 0.22)
      ..strokeWidth = 0.7;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (visible.isEmpty) return;

    double xOf(SessionSample s) =>
        s.at.difference(start).inMilliseconds / spanX * size.width;
    double py(SessionSample s) =>
        size.height - ((yOf(s) - minY) / spanY * size.height);

    final path = Path();
    Offset? last;
    for (var i = 0; i < visible.length; i++) {
      final s = visible[i];
      final pt = Offset(xOf(s), py(s));
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

    if (visible.length == 1 && last != null) {
      canvas.drawCircle(last, 3, Paint()..color = line);
    } else {
      canvas.drawPath(path, paint);
    }

    if (hoverX != null) {
      final hx = hoverX!.clamp(0, size.width).toDouble();
      canvas.drawLine(
        Offset(hx, 0),
        Offset(hx, size.height),
        Paint()
          ..color = line.withValues(alpha: 0.45)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(SeriesPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.line != line ||
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.hoverX != hoverX;
}
