class CalPoint {
  const CalPoint({required this.uncalSg, required this.actualSg});
  final double uncalSg;
  final double actualSg;
}

/// App-side SG calibration. Does not write to the float.
double applyCal(double uncalSg, List<CalPoint> points) {
  if (points.isEmpty) return uncalSg;
  if (points.length == 1) {
    final p = points.first;
    return uncalSg + (p.actualSg - p.uncalSg);
  }
  final pts = [...points]..sort((a, b) => a.uncalSg.compareTo(b.uncalSg));
  if (uncalSg <= pts.first.uncalSg) return pts.first.actualSg;
  if (uncalSg >= pts.last.uncalSg) return pts.last.actualSg;
  for (var i = 0; i < pts.length - 1; i++) {
    final a = pts[i];
    final b = pts[i + 1];
    if (uncalSg >= a.uncalSg && uncalSg <= b.uncalSg) {
      final span = b.uncalSg - a.uncalSg;
      if (span == 0) return a.actualSg;
      final t = (uncalSg - a.uncalSg) / span;
      return a.actualSg + t * (b.actualSg - a.actualSg);
    }
  }
  return uncalSg;
}

/// App-side water shortcut. Does not tare the float.
CalPoint waterCal({required double currentRaw}) =>
    CalPoint(uncalSg: currentRaw, actualSg: 1.000);

