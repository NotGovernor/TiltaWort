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

  test('inserts out-of-order samples by at', () {
    final h = SessionHistory();
    const uuid = 'A495BB80-C5B1-4B44-B512-1370F02D74DE';
    final t0 = DateTime.utc(2026, 10, 25, 12);
    final later = t0.add(const Duration(minutes: 10));
    h.add(uuid, SessionSample(at: later, sg: 1.012, tempF: 69));
    h.add(uuid, SessionSample(at: t0, sg: 1.010, tempF: 68));
    final samples = h.of(uuid);
    expect(samples, hasLength(2));
    expect(samples.first.at, t0);
    expect(samples.last.at, later);
  });

  test('dedupes a matching at even when it is not last', () {
    final h = SessionHistory();
    const uuid = 'A495BB80-C5B1-4B44-B512-1370F02D74DE';
    final t0 = DateTime.utc(2026, 10, 25, 12);
    final t1 = t0.add(const Duration(minutes: 5));
    final t2 = t0.add(const Duration(minutes: 10));
    h.add(uuid, SessionSample(at: t0, sg: 1.010, tempF: 68));
    h.add(uuid, SessionSample(at: t1, sg: 1.011, tempF: 68));
    h.add(uuid, SessionSample(at: t2, sg: 1.012, tempF: 69));
    h.add(uuid, SessionSample(at: t1, sg: 1.099, tempF: 99));
    final samples = h.of(uuid);
    expect(samples, hasLength(3));
    expect(samples[1].sg, closeTo(1.011, 1e-9));
  });

  test('mergeAll interleaves CSV and live without duplicate timestamps', () {
    final h = SessionHistory();
    const uuid = 'A495BB80-C5B1-4B44-B512-1370F02D74DE';
    final t0 = DateTime.utc(2026, 10, 25, 12);
    final t1 = t0.add(const Duration(minutes: 5));
    final t2 = t0.add(const Duration(minutes: 10));
    h.add(uuid, SessionSample(at: t1, sg: 1.011, tempF: 68));
    h.mergeAll(uuid, [
      SessionSample(at: t0, sg: 1.010, tempF: 68),
      SessionSample(at: t1, sg: 1.099, tempF: 99),
      SessionSample(at: t2, sg: 1.012, tempF: 69),
    ]);
    final samples = h.of(uuid);
    expect(samples, hasLength(3));
    expect(samples.map((s) => s.at).toList(), [t0, t1, t2]);
    expect(samples[1].sg, closeTo(1.011, 1e-9));
  });
}
