import 'package:flutter/widgets.dart';

/// Cut top-right and bottom-left. Radius stays zero.
class ChamferClipper extends CustomClipper<Path> {
  const ChamferClipper({this.chamfer = 12});

  final double chamfer;

  static const radius = Radius.zero;

  @override
  Path getClip(Size size) {
    final c = chamfer;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - c, 0)
      ..lineTo(size.width, c)
      ..lineTo(size.width, size.height)
      ..lineTo(c, size.height)
      ..lineTo(0, size.height - c)
      ..close();
  }

  @override
  bool shouldReclip(ChamferClipper oldClipper) => oldClipper.chamfer != chamfer;
}

class ChamferPlate extends StatelessWidget {
  const ChamferPlate({
    super.key,
    required this.child,
    this.chamfer = 12,
    required this.fill,
    required this.edge,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final double chamfer;
  final Color fill;
  final Color edge;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: ChamferClipper(chamfer: chamfer),
      child: CustomPaint(
        painter: ChamferEdgePainter(chamfer: chamfer, edge: edge),
        child: ColoredBox(
          color: fill,
          child: Padding(padding: padding, child: child),
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
    final path = ChamferClipper(chamfer: chamfer).getClip(size);
    canvas.drawPath(
      path,
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
