import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A deterministic miniature material study with reflected environment bands.
class MaterialOrb extends StatelessWidget {
  const MaterialOrb({super.key, this.materialIndex = 0, this.size = 36});
  final int materialIndex;
  final double size;

  static const palettes = [
    [Color(0xFFE7FBFF), Color(0xFF9ACADB), Color(0xFF406C80), Color(0xFF16313F)],
    [Color(0xFFFFF2E5), Color(0xFFD0B7D1), Color(0xFF91BDC6), Color(0xFF4B556E)],
    [Color(0xFFFFFFFF), Color(0xFFAEBCC3), Color(0xFF303E4A), Color(0xFF090F18)],
  ];

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _OrbPainter(materialIndex.clamp(0, 2).toInt())),
      );
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter(this.materialIndex);
  final int materialIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .46);
    final r = size.shortestSide * .43;
    final bounds = Rect.fromCircle(center: center, radius: r);
    final colors = MaterialOrb.palettes[materialIndex];
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, size.height * .92), width: r * 1.6, height: r * .2),
      Paint()..color = const Color(0x60020B15)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .12),
    );
    canvas.drawCircle(center, r, Paint()..shader = RadialGradient(
      center: const Alignment(-.35, -.5),
      radius: 1.05,
      colors: [colors[0], colors[1], colors[2], colors[3]],
      stops: const [0, .22, .62, 1],
    ).createShader(bounds));
    canvas.save();
    canvas.clipPath(Path()..addOval(bounds));
    final reflection = Path()
      ..moveTo(center.dx - r, center.dy - r * .12)
      ..cubicTo(center.dx - r * .2, center.dy - r * .5, center.dx + r * .45, center.dy + r * .55, center.dx + r, center.dy - r * .1)
      ..lineTo(center.dx + r, center.dy + r * .26)
      ..cubicTo(center.dx + r * .2, center.dy + r * .8, center.dx - r * .5, center.dy - r * .18, center.dx - r, center.dy + r * .32)
      ..close();
    canvas.drawPath(reflection, Paint()..color = Colors.white.withValues(alpha: materialIndex == 2 ? .68 : .23));
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(-r * .35, -r * .52), width: r * .62, height: r * .22),
      Paint()..color = const Color(0xBFFFFFFF)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .07),
    );
    canvas.restore();
    canvas.drawCircle(center, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.65, r * .028)
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xDDFFFFFF), Color(0x2075AFC4), Color(0xC8D8F5FF)],
      ).createShader(bounds));
    canvas.drawArc(bounds.deflate(r * .12), math.pi * .15, math.pi * .4, false,
      Paint()..color = const Color(0x66DCF8FF)..strokeWidth = math.max(.7, r * .035)..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_OrbPainter oldDelegate) => oldDelegate.materialIndex != materialIndex;
}
