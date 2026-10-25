import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/decode.dart';

void main() {
  const redPayload = <int>[
    0x02, 0x15,
    0xA4, 0x95, 0xBB, 0x10, 0xC5, 0xB1, 0x4B, 0x44,
    0xB5, 0x12, 0x13, 0x70, 0xF0, 0x2D, 0x74, 0xDE,
    0x00, 0x44, // major 68
    0x03, 0xF8, // minor 1016
    0xC5,
  ];

  test('kvurd Red standard Tilt', () {
    final r = decodeTilt(companyId: 0x004C, payload: redPayload)!;
    expect(r.color, 'Red');
    expect(r.uuid, 'A495BB10-C5B1-4B44-B512-1370F02D74DE');
    expect(r.isPro, isFalse);
    expect(r.tempF, 68.0);
    expect(r.sg, closeTo(1.016, 1e-9));
    expect(r.tempC, closeTo(20.0, 1e-9));
  });

  test('strips optional 4C 00 prefix', () {
    final r = decodeTilt(
      companyId: 0x004C,
      payload: [0x4C, 0x00, ...redPayload],
    )!;
    expect(r.sg, closeTo(1.016, 1e-9));
  });

  test('drops unknown UUID and wrong company', () {
    expect(decodeTilt(companyId: 0x004C, payload: [0x02, 0x15, ...List.filled(21, 0)]), isNull);
    expect(decodeTilt(companyId: 0x0075, payload: redPayload), isNull);
  });

  test('Pink Pro heuristic minor > 5000', () {
    // temp 72.0°F → major 720; SG 1.0000 → minor 10000
    final payload = <int>[
      0x02, 0x15,
      0xA4, 0x95, 0xBB, 0x80, 0xC5, 0xB1, 0x4B, 0x44,
      0xB5, 0x12, 0x13, 0x70, 0xF0, 0x2D, 0x74, 0xDE,
      0x02, 0xD0, // 720
      0x27, 0x10, // 10000
      0xC5,
    ];
    final r = decodeTilt(companyId: 0x004C, payload: payload)!;
    expect(r.color, 'Pink');
    expect(r.isPro, isTrue);
    expect(r.tempF, closeTo(72.0, 1e-9));
    expect(r.sg, closeTo(1.0000, 1e-9));
  });
}
