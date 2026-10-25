import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:tiltawort/ui/theme.dart';

/// Elongated octagon. Radius stays zero.
class ChamferClipper extends CustomClipper<Path> {
  const ChamferClipper({this.chamfer = 16});

  final double chamfer;

  static const radius = Radius.zero;

  @override
  Path getClip(Size size) => octagonPath(size, chamfer);

  @override
  bool shouldReclip(ChamferClipper oldClipper) => oldClipper.chamfer != chamfer;
}

Path octagonPath(Size size, double chamfer) {
  final w = size.width;
  final h = size.height;
  final c = math.min(chamfer, math.min(w, h) / 2);
  return Path()
    ..moveTo(c, 0)
    ..lineTo(w - c, 0)
    ..lineTo(w, c)
    ..lineTo(w, h - c)
    ..lineTo(w - c, h)
    ..lineTo(c, h)
    ..lineTo(0, h - c)
    ..lineTo(0, c)
    ..close();
}

List<Offset> octagonPoints(Size size, double chamfer) {
  final w = size.width;
  final h = size.height;
  final c = math.min(chamfer, math.min(w, h) / 2);
  return [
    Offset(c, 0),
    Offset(w - c, 0),
    Offset(w, c),
    Offset(w, h - c),
    Offset(w - c, h),
    Offset(c, h),
    Offset(0, h - c),
    Offset(0, c),
  ];
}

/// Beveled metal plate. 4–6px rim, specular top-left, drop shadow.
class ChamferPlate extends StatelessWidget {
  const ChamferPlate({
    super.key,
    required this.child,
    this.chamfer = 16,
    this.bevel = 5,
    required this.fill,
    required this.edge,
    this.padding = const EdgeInsets.all(16),
    this.strip,
    this.stripFactor = 0.15,
    this.inset = false,
    this.shadow = true,
    this.accentTl,
    this.accentTr,
  });

  final Widget child;
  final double chamfer;
  final double bevel;
  final Color fill;
  final Color edge;
  final EdgeInsets padding;
  final Color? strip;
  final double stripFactor;
  final bool inset;
  final bool shadow;
  final Color? accentTl;
  final Color? accentTr;

  @override
  Widget build(BuildContext context) {
    final b = bevel.clamp(4.0, 6.0).toDouble();
    return Padding(
      padding: shadow
          ? const EdgeInsets.fromLTRB(2, 2, 12, 16)
          : EdgeInsets.zero,
      child: CustomPaint(
        painter: MetalPlatePainter(
          chamfer: chamfer,
          bevel: b,
          fill: fill,
          edge: edge,
          inset: inset,
          shadow: shadow,
          strip: strip,
          stripFactor: stripFactor,
          accentTl: accentTl,
          accentTr: accentTr,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stripPad = strip == null
                ? 0.0
                : math.max(0.0, constraints.maxWidth * stripFactor);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                b + stripPad + padding.left,
                b + padding.top,
                b + padding.right,
                b + padding.bottom,
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class MetalPlatePainter extends CustomPainter {
  const MetalPlatePainter({
    required this.chamfer,
    required this.bevel,
    required this.fill,
    required this.edge,
    required this.inset,
    required this.shadow,
    this.strip,
    this.stripFactor = 0.15,
    this.accentTl,
    this.accentTr,
  });

  final double chamfer;
  final double bevel;
  final Color fill;
  final Color edge;
  final bool inset;
  final bool shadow;
  final Color? strip;
  final double stripFactor;
  final Color? accentTl;
  final Color? accentTr;

  static const _toLight = Offset(-0.52, -0.78);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final outer = octagonPath(size, chamfer);

    if (shadow && !inset) {
      canvas.drawPath(
        outer.shift(const Offset(2, 9)),
        Paint()
          ..color = const Color(0xCC000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawPath(
        outer.shift(const Offset(0, 3)),
        Paint()
          ..color = const Color(0x66000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    canvas.drawPath(outer, Paint()..color = fill);

    final innerSize = Size(
      math.max(0, size.width - 2 * bevel),
      math.max(0, size.height - 2 * bevel),
    );
    final innerChamfer = math.max(0.0, chamfer - bevel * 0.7);
    final outerPts = octagonPoints(size, chamfer);
    final innerPts = octagonPoints(innerSize, innerChamfer)
        .map((p) => p + Offset(bevel, bevel))
        .toList();

    for (var i = 0; i < 8; i++) {
      final a = outerPts[i];
      final b = outerPts[(i + 1) % 8];
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(innerPts[(i + 1) % 8].dx, innerPts[(i + 1) % 8].dy)
        ..lineTo(innerPts[i].dx, innerPts[i].dy)
        ..close();
      var ndotl = _ndotl(a, b);
      if (inset) ndotl = -ndotl;
      var rim = _rimColor(fill, ndotl);
      if (i == 7 && accentTl != null) {
        rim = Color.lerp(rim, accentTl, 0.72)!;
      } else if (i == 1 && accentTr != null) {
        rim = Color.lerp(rim, accentTr, 0.72)!;
      }
      canvas.drawPath(path, Paint()..color = rim);
    }

    final inner =
        octagonPath(innerSize, innerChamfer).shift(Offset(bevel, bevel));
    canvas.save();
    canvas.clipPath(inner);

    final lightFill = fill.computeLuminance() > 0.42;
    final face = Paint()
      ..shader = ui.Gradient.linear(
        Offset(bevel, bevel),
        Offset(size.width - bevel, size.height - bevel),
        [
          Color.lerp(fill, const Color(0xFFFFFFFF), lightFill ? 0.18 : 0.10)!,
          fill,
          Color.lerp(fill, const Color(0xFF000000), lightFill ? 0.10 : 0.20)!,
        ],
        const [0.0, 0.38, 1.0],
      );
    canvas.drawPath(inner, face);

    canvas.drawPath(
      inner,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(bevel, bevel),
          Offset(size.width * 0.55, size.height * 0.55),
          const [Color(0x33FFFFFF), Color(0x00FFFFFF)],
        ),
    );

    if (strip != null && stripFactor > 0) {
      final sw = innerSize.width * stripFactor;
      canvas.save();
      canvas.translate(bevel, bevel);
      canvas.clipRect(Rect.fromLTWH(0, 0, sw, innerSize.height));
      FacetedStripPainter(color: strip!).paint(
        canvas,
        Size(sw, innerSize.height),
      );
      canvas.restore();
      canvas.drawRect(
        Rect.fromLTWH(bevel + sw - 1.4, bevel, 1.4, innerSize.height),
        Paint()..color = const Color(0x88000000),
      );
    }

    canvas.drawPath(
      inner,
      Paint()
        ..color = const Color(0x55000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.restore();

    canvas.drawPath(
      outer,
      Paint()
        ..color = edge.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15,
    );
  }

  static double _ndotl(Offset a, Offset b) {
    final d = b - a;
    final len = d.distance;
    if (len < 0.001) return 0;
    final nx = d.dy / len;
    final ny = -d.dx / len;
    return nx * _toLight.dx + ny * _toLight.dy;
  }

  static Color _rimColor(Color fill, double ndotl) {
    final t = ((ndotl + 1) / 2).clamp(0.0, 1.0);
    final dark = Color.lerp(fill, const Color(0xFF050505), 0.78)!;
    final bright = Color.lerp(fill, const Color(0xFFF7F3E8), 0.88)!;
    return Color.lerp(dark, bright, t * t * (3 - 2 * t))!;
  }

  @override
  bool shouldRepaint(MetalPlatePainter old) =>
      old.chamfer != chamfer ||
      old.bevel != bevel ||
      old.fill != fill ||
      old.edge != edge ||
      old.inset != inset ||
      old.shadow != shadow ||
      old.strip != strip ||
      old.stripFactor != stripFactor ||
      old.accentTl != accentTl ||
      old.accentTr != accentTr;
}

class FacetedStripPainter extends CustomPainter {
  const FacetedStripPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    const cols = 3;
    const rows = 9;
    final cw = size.width / cols;
    final ch = size.height / rows;
    final light = Color.lerp(color, const Color(0xFFFFFFFF), 0.38)!;
    final dark = Color.lerp(color, const Color(0xFF000000), 0.48)!;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final x = c * cw;
        final y = r * ch;
        final a = Offset(x, y);
        final b = Offset(x + cw, y);
        final d = Offset(x, y + ch);
        final e = Offset(x + cw, y + ch);
        final flip = (r + c).isEven;
        final t1 = Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(flip ? e.dx : d.dx, flip ? e.dy : d.dy)
          ..close();
        final t2 = Path()
          ..moveTo(flip ? a.dx : b.dx, flip ? a.dy : b.dy)
          ..lineTo(e.dx, e.dy)
          ..lineTo(d.dx, d.dy)
          ..close();
        final k = ((r * 3 + c * 5) % 7) / 6;
        canvas.drawPath(
          t1,
          Paint()..color = Color.lerp(dark, light, 0.22 + k * 0.65)!,
        );
        canvas.drawPath(
          t2,
          Paint()..color = Color.lerp(dark, light, 0.72 - k * 0.5)!,
        );
      }
    }
  }

  @override
  bool shouldRepaint(FacetedStripPainter old) => old.color != color;
}

/// Subtle triangular mesh. Not empty #000.
class FacetedMesh extends StatelessWidget {
  const FacetedMesh({super.key});

  @override
  Widget build(BuildContext context) {
    final p = TiltPalette.of(context);
    return CustomPaint(
      painter: FacetedMeshPainter(base: p.neutral, line: p.mesh),
      child: const SizedBox.expand(),
    );
  }
}

class FacetedMeshPainter extends CustomPainter {
  const FacetedMeshPainter({required this.base, required this.line});

  final Color base;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    const cell = 74.0;
    final cols = (size.width / cell).ceil() + 2;
    final rows = (size.height / cell).ceil() + 2;

    Offset pt(int c, int r) {
      final jx = ((c * 73 + r * 41) % 13 - 6) * 2.1;
      final jy = ((c * 19 + r * 87) % 13 - 6) * 2.1;
      final stagger = r.isOdd ? cell * 0.46 : 0.0;
      return Offset(c * cell + stagger + jx, r * cell + jy);
    }

    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final a = pt(c, r);
        final b = pt(c + 1, r);
        final d = pt(c, r + 1);
        final e = pt(c + 1, r + 1);
        _facet(canvas, a, b, d, r, c, 0, stroke);
        _facet(canvas, b, e, d, r, c, 1, stroke);
      }
    }
  }

  void _facet(
    Canvas canvas,
    Offset a,
    Offset b,
    Offset c,
    int r,
    int col,
    int k,
    Paint stroke,
  ) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..close();
    final h = (r * 13 + col * 7 + k * 3) % 9;
    final t = ((h - 4) / 8).clamp(-1.0, 1.0);
    final fill = Color.lerp(
      const Color(0xFF050814),
      const Color(0xFF1A3A58),
      (t + 1) / 2,
    )!;
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(FacetedMeshPainter old) =>
      old.base != base || old.line != line;
}

class MetalButton extends StatelessWidget {
  const MetalButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = MetalButtonKind.steel,
  });

  final String label;
  final VoidCallback onTap;
  final MetalButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final p = TiltPalette.of(context);
    late final Color edge;
    switch (kind) {
      case MetalButtonKind.gold:
        edge = p.primary;
      case MetalButtonKind.blue:
        edge = p.tertiary;
      case MetalButtonKind.steel:
        edge = p.secondary;
    }
    return GestureDetector(
      onTap: onTap,
      child: ChamferPlate(
        chamfer: 8,
        bevel: 4,
        fill: p.aluminum,
        edge: edge,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shadow: true,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Sora',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: p.stampInk,
          ),
        ),
      ),
    );
  }
}

enum MetalButtonKind { gold, steel, blue }

class BackChevron extends StatelessWidget {
  const BackChevron({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = TiltPalette.of(context);
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
        child: Stack(
          children: [
            Text(
              '<',
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 26,
                fontWeight: FontWeight.w600,
                height: 1,
                color: p.primary,
              ),
            ),
            const SizedBox(
              width: 0,
              height: 0,
              child: Text('Back', style: TextStyle(fontSize: 0.1)),
            ),
          ],
        ),
      ),
    );
  }
}

class ChamferEdgePainter extends CustomPainter {
  const ChamferEdgePainter({required this.chamfer, required this.edge});

  final double chamfer;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      octagonPath(size, chamfer),
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(ChamferEdgePainter oldDelegate) =>
      oldDelegate.chamfer != chamfer || oldDelegate.edge != edge;
}
