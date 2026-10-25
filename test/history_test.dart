import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/history.dart';

void main() {
  test('empty history has no samples and no synthetic 1.000', () {
    final h = SessionHistory();
    expect(h.of('A495BB80-C5B1-4B44-B512-1370F02D74DE'), isEmpty);
  });

  test('adds samples per uuid in order', () {
    final h = SessionHistory();
    const uuid = 'A495BB80-C5B1-4B44-B512-1370F02D74DE';
    final t0 = DateTime.utc(2026, 10, 24, 21, 30);
    h.add(
      uuid,
      SessionSample(at: t0, sg: 1.0000, tempF: 72.0),
    );
    h.add(
      uuid,
      SessionSample(at: t0.add(const Duration(seconds: 5)), sg: 1.0002, tempF: 72.4),
    );
    final samples = h.of(uuid);
    expect(samples, hasLength(2));
    expect(samples.first.sg, closeTo(1.0000, 1e-9));
    expect(samples.last.sg, closeTo(1.0002, 1e-9));
  });

  test('dedupes the same timestamp on one uuid', () {
    final h = SessionHistory();
    const uuid = 'A495BB80-C5B1-4B44-B512-1370F02D74DE';
    final t0 = DateTime.utc(2026, 10, 24, 21, 30);
    h.add(uuid, SessionSample(at: t0, sg: 1.0000, tempF: 72.0));
    h.add(uuid, SessionSample(at: t0, sg: 1.0000, tempF: 72.0));
    expect(h.of(uuid), hasLength(1));
  });
}
