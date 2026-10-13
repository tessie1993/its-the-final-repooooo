import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../three_d/asset_3d.dart';

/// An opaque, gently lit sample of moss, river stone or bark.
class MaterialOrb extends StatelessWidget {
  const MaterialOrb({super.key, this.materialIndex = 0, this.size = 36});
  final int materialIndex;
  final double size;
  static const palettes = [
    [Color(0xFF8EAA6A), Color(0xFF4F7044), Color(0xFF294936), Color(0xFF172A23)],
    [Color(0xFFB7B5A2), Color(0xFF838979), Color(0xFF515E54), Color(0xFF2A382F)],
    [Color(0xFFA98956), Color(0xFF795834), Color(0xFF4C3822), Color(0xFF2C2418)],
  ];
  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size,
    child: Asset3D(asset: Geode3DAsset.pebble, variant: materialIndex.clamp(0, 2).toInt(),
      fallback: CustomPaint(painter: _PebblePainter(materialIndex.clamp(0, 2).toInt()))));
}

class _PebblePainter extends CustomPainter {
  const _PebblePainter(this.materialIndex);
  final int materialIndex;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .46);
    final r = size.shortestSide * .43;
    final bounds = Rect.fromCircle(center: center, radius: r);
    final shape = Path();
    for (var i = 0; i <= 60; i++) {
      final a = i * math.pi * 2 / 60;
      final radius = r * (1 + math.sin(a * 3) * .055);
      final p = center + Offset(math.cos(a) * radius, math.sin(a) * radius * .89);
      if (i == 0) { shape.moveTo(p.dx, p.dy); } else { shape.lineTo(p.dx, p.dy); }
    }
    shape.close();
    canvas.drawShadow(shape, const Color(0xA606130A), r * .12, false);
    canvas.drawPath(shape, Paint()..shader = RadialGradient(
      center: const Alignment(-.4, -.5), radius: 1.2,
      colors: MaterialOrb.palettes[materialIndex], stops: const [0, .3, .72, 1]).createShader(bounds));
    canvas.save();
    canvas.clipPath(shape);
    final random = math.Random(42 + materialIndex);
    for (var i = 0; i < 55; i++) {
      final point = center + Offset((random.nextDouble() - .5) * r * 2,
        (random.nextDouble() - .5) * r * 2);
      canvas.drawCircle(point, math.max(.25, r * .018),
        Paint()..color = const Color(0x406A7950));
    }
    for (var i = 0; i < 3; i++) {
      final vein = Path()..moveTo(center.dx - r, center.dy - r * .5 + i * r * .47)
        ..cubicTo(center.dx - r * .2, center.dy - r * .4 + i * r * .46,
          center.dx + r * .1, center.dy + i * r * .3, center.dx + r, center.dy + r * .1 + i * r * .45);
      canvas.drawPath(vein, Paint()..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.5, r * .016)
        ..color = materialIndex == 2 ? const Color(0x99533C22) : const Color(0x337F9365));
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(_PebblePainter old) => old.materialIndex != materialIndex;
}
