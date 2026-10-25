import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/ui/chamfer.dart';
import 'package:tiltawort/ui/theme.dart';

void main() {
  test('clipper cuts all four corners, keeps interior', () {
    final path = ChamferClipper(chamfer: 10).getClip(const Size(100, 80));
    expect(path.contains(const Offset(50, 40)), isTrue);
    expect(path.contains(const Offset(1, 1)), isFalse); // top-left cut
    expect(path.contains(const Offset(99, 1)), isFalse); // top-right cut
    expect(path.contains(const Offset(99, 79)), isFalse); // bottom-right cut
    expect(path.contains(const Offset(1, 79)), isFalse); // bottom-left cut
  });

  test('chamfer does not use a radius', () {
    expect(ChamferClipper.radius, Radius.zero);
  });

  test('dark scaffold is opaque navy mesh, light scaffold is paper', () {
    expect(tiltDarkTheme().scaffoldBackgroundColor, TiltPalette.dark.mesh);
    expect(tiltDarkTheme().canvasColor, TiltPalette.dark.mesh);
    expect(tiltDarkTheme().appBarTheme.backgroundColor, TiltPalette.dark.mesh);
    expect(TiltPalette.dark.mesh, const Color(0xFF0B1A2E));
    expect(tiltLightTheme().scaffoldBackgroundColor, TiltPalette.light.neutral);
  });

  test('FacetedMeshPainter with paper base is not navy', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const painter = FacetedMeshPainter(
      base: Color(0xFFF3EFE4),
      line: Color(0x336B5010),
    );
    painter.paint(canvas, const Size(48, 48));
    final image = await recorder.endRecording().toImage(48, 48);
    final bd = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = bd!.buffer.asUint8List();
    var paperish = 0;
    var navyish = 0;
    final pixels = bytes.length ~/ 4;
    for (var i = 0; i < bytes.length; i += 4) {
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      expect(r == 0x05 && g == 0x08 && b == 0x14, isFalse);
      final lum = 0.299 * r + 0.587 * g + 0.114 * b;
      if (lum > 160) paperish++;
      if (r < 40 && g < 70 && b < 100) navyish++;
    }
    expect(paperish, greaterThan(navyish));
    expect(paperish, greaterThan(pixels ~/ 2));
  });
}
