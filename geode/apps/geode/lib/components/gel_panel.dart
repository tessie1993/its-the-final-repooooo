import 'dart:ui';
import 'package:flutter/material.dart';

/// An ice-blue gel shell. Text stays outside the scene's refraction pass.
class GelPanel extends StatelessWidget {
  const GelPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.opacity = .65,
    this.blur = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final alpha = opacity.clamp(0.0, 1.0).toDouble();
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: Color(0x45020914), blurRadius: 30, offset: Offset(0, 15)),
          BoxShadow(color: Color(0x087CBFD1), blurRadius: 18, spreadRadius: 1),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: CustomPaint(
            foregroundPainter: _GelRimPainter(radius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0, .38, .8, 1],
                  colors: [
                    const Color(0xFF426774).withValues(alpha: alpha),
                    const Color(0xFF173E4D).withValues(alpha: alpha),
                    const Color(0xFF0A2631).withValues(alpha: alpha),
                    const Color(0xFF284A57).withValues(alpha: alpha),
                  ],
                ),
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _GelRimPainter extends CustomPainter {
  const _GelRimPainter(this.radius);
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(.65);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xA8E7F9FF), Color(0x207FAEBE), Color(0x145A9CAC), Color(0x76C2EAF5)],
          stops: [0, .36, .7, 1],
        ).createShader(rect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(2), Radius.circular((radius - 2).clamp(0.0, double.infinity).toDouble())),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x24FFFFFF), Color(0x00FFFFFF), Color(0x109BD9F0)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GelRimPainter oldDelegate) => oldDelegate.radius != radius;
}
