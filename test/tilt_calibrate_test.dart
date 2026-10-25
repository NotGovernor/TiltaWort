import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/calibrate.dart';

void main() {
  test('no points is identity', () {
    expect(applyCal(1.012, const []), closeTo(1.012, 1e-9));
  });
  test('one point offsets', () {
    expect(applyCal(1.010, [CalPoint(uncalSg: 1.000, actualSg: 1.002)]), closeTo(1.012, 1e-9));
  });
  test('two points interpolate', () {
    final pts = [CalPoint(uncalSg: 1.000, actualSg: 1.000), CalPoint(uncalSg: 1.020, actualSg: 1.016)];
    expect(applyCal(1.010, pts), closeTo(1.008, 1e-9));
  });

  test('clamps to nearest end actual beyond range', () {
    final pts = [CalPoint(uncalSg: 1.000, actualSg: 1.000), CalPoint(uncalSg: 1.020, actualSg: 1.016)];
    expect(applyCal(0.990, pts), closeTo(1.000, 1e-9));
    expect(applyCal(1.040, pts), closeTo(1.016, 1e-9));
  });
}
