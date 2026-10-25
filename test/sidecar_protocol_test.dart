import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/sidecar_protocol.dart';

void main() {
  test('sidecar JSON Apple 0x004C Pink Pro decodes', () {
    const line =
        '{"type":"ad","companyId":76,"payload":[2,21,164,149,187,128,197,177,75,68,181,18,19,112,240,45,116,222,2,208,39,16,197],"rssi":-97,"address":"EC:95:FA:E0:74:DE"}';
    final parsed = parseSidecarLine(line);
    expect(parsed, isA<SidecarAdLine>());
    final ad = parsed as SidecarAdLine;
    expect(ad.companyId, 0x004C);
    final event = eventFromSidecarAd(ad, now: DateTime.utc(2026, 10, 24))!;
    expect(event.advertisement.color, 'Pink');
    expect(event.advertisement.isPro, isTrue);
    expect(event.advertisement.sg, closeTo(1.0000, 1e-9));
    expect(event.advertisement.tempF, closeTo(72.0, 1e-9));
    expect(event.rssiDbm, -97);
  });

  test('adapter PoweredOff', () {
    final parsed = parseSidecarLine('{"type":"adapter","state":"PoweredOff"}');
    expect(parsed, isA<SidecarAdapterLine>());
    expect((parsed as SidecarAdapterLine).isOn, isFalse);
  });

  test('non-Tilt 0x004C is dropped', () {
    const line = '{"type":"ad","companyId":76,"payload":[2,21,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"rssi":-40}';
    final ad = parseSidecarLine(line) as SidecarAdLine;
    expect(eventFromSidecarAd(ad), isNull);
  });
}
