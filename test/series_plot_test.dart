import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/history.dart';
import 'package:tiltawort/ui/series_plot.dart';

void main() {
  test('window keeps last 2 hours, not the whole session', () {
    final t0 = DateTime.utc(2026, 10, 25, 10);
    final samples = [
      SessionSample(at: t0, sg: 1.010, tempF: 68),
      SessionSample(at: t0.add(const Duration(hours: 1)), sg: 1.011, tempF: 68),
      SessionSample(at: t0.add(const Duration(hours: 3)), sg: 1.012, tempF: 69),
    ];
    final now = t0.add(const Duration(hours: 3));
    final visible = samplesInWindow(samples, end: now, window: const Duration(hours: 2));
    expect(visible, hasLength(2));
    expect(visible.first.sg, closeTo(1.011, 1e-9));
    expect(visible.last.sg, closeTo(1.012, 1e-9));
  });

  test('axisTime is HH:mm', () {
    final stamp = axisTime(DateTime(2026, 10, 25, 9, 5));
    expect(stamp, matches(RegExp(r'^\d{2}:\d{2}$')));
  });
}
