import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A small botanical mark drawn as leaves and stems, without a surrounding orb.
class FernSprig extends StatelessWidget {
  const FernSprig({super.key, this.size = 80});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: SizedBox.square(
    dimension: size, child: CustomPaint(painter: const _FernPainter())));
}

class _FernPainter extends CustomPainter {
  const _FernPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final stem = Path()..moveTo(24, 93)..quadraticBezierTo(59, 55, 70, 7);
    canvas.drawPath(stem, Paint()..color = const Color(0xFF9BB579)
      ..style = PaintingStyle.stroke..strokeWidth = 1.7..strokeCap = StrokeCap.round);
    for (var i = 0; i < 10; i++) {
      final t = i / 10;
      final origin = Offset(28 + t * 41, 86 - t * 72);
      final length = 25 * math.sin((t + .12) * math.pi) + 3;
      for (final side in [-1.0, 1.0]) {
        final tip = origin + Offset(side * length, -length * .76);
        final path = Path()..moveTo(origin.dx, origin.dy)
          ..quadraticBezierTo(origin.dx + side * length * .85, origin.dy - length * .05, tip.dx, tip.dy)
          ..quadraticBezierTo(origin.dx + side * length * .25, origin.dy - length * .85, origin.dx, origin.dy);
        canvas.drawShadow(path, const Color(0x9906100A), 1, false);
        canvas.drawPath(path, Paint()..shader = LinearGradient(
          colors: side < 0 ? const [Color(0xFF829B55), Color(0xFF3D613A)]
            : const [Color(0xFF63884A), Color(0xFF243F2C)])
          .createShader(Rect.fromPoints(origin, tip).inflate(1)));
        canvas.drawLine(origin, tip, Paint()..color = const Color(0x559AAF71)..strokeWidth = .6);
      }
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(_FernPainter old) => false;
}
