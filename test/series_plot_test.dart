import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/history.dart';
import 'package:tiltawort/ui/series_plot.dart';

void main() {
  test('chartSpan is the data min/max, not 2 hours of blank', () {
    final t0 = DateTime.utc(2026, 10, 25, 10);
    final samples = [
      SessionSample(at: t0, sg: 1.010, tempF: 68),
      SessionSample(at: t0.add(const Duration(hours: 1)), sg: 1.011, tempF: 68),
      SessionSample(at: t0.add(const Duration(hours: 3)), sg: 1.012, tempF: 69),
    ];
    final span = chartSpan(samples);
    expect(span.start, t0);
    expect(span.end, t0.add(const Duration(hours: 3)));
    expect(span.end.difference(span.start), const Duration(hours: 3));
  });

  test('axisTime is HH:mm', () {
    final stamp = axisTime(DateTime(2026, 10, 25, 9, 5));
    expect(stamp, matches(RegExp(r'^\d{2}:\d{2}$')));
  });
}
