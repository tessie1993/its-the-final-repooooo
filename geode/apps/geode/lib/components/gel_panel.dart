import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../scene/geode_scene_controller.dart';
import '../scene/nature_motion_scope.dart';

/// A translucent, tactile moss-and-stone surface with bioluminescent veins. The historical widget name and
/// sizing parameters are retained so every screen shares the nature material.
/// The textured skin preserves contrast while the landscape shows through.
class GelPanel extends StatelessWidget {
  const GelPanel({super.key, required this.child,
    this.padding = const EdgeInsets.all(20), this.radius = 28,
    this.opacity = .65, this.blur = 18, this.highlighted = false, this.pearl = false});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;
  final double blur;
  final bool highlighted;
  final bool pearl;

  @override
  Widget build(BuildContext context) {
    final depth = opacity.clamp(0.0, 1.0).toDouble();
    final scene = NatureMotionScope.maybeOf(context);
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(radius * .85), topRight: Radius.circular(radius * 1.1),
      bottomLeft: Radius.circular(radius * 1.05), bottomRight: Radius.circular(radius * .82));
    final top = Color.lerp(const Color(0xFF263D32),
      pearl ? const Color(0xFF65745B) : const Color(0xFF405C42), depth)!;
    final base = pearl ? const Color(0xFF303D30) : const Color(0xFF142A23);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: [
        const BoxShadow(color: Color(0x6604090A), blurRadius: 22, offset: Offset(0, 13)),
        // Stacked hard edges extrude the panel into a slab of stone.
        for (var layer = 1; layer <= (highlighted ? 6 : 4); layer++)
          BoxShadow(color: Color.lerp(const Color(0xFF2C3F31), const Color(0xFF0B1611),
            layer / 6)!.withValues(alpha: .9), blurRadius: 0, offset: Offset(0, layer.toDouble())),
      ]),
      child: ClipRRect(borderRadius: borderRadius,
        child: CustomPaint(foregroundPainter: _StoneRimPainter(radius, highlighted, scene),
          child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [top.withValues(alpha: .85), base.withValues(alpha: .82),
              Color.lerp(base, const Color(0xFF626343), .2)!.withValues(alpha: .86)],
            stops: const [0, .65, 1]),
            image: const DecorationImage(image: AssetImage('assets/textures/moss.png'),
              fit: BoxFit.cover, opacity: .075)),
            child: CustomPaint(painter: const _StoneGrainPainter(),
              child: DecoratedBox(decoration: const BoxDecoration(
                image: DecorationImage(image: AssetImage('assets/textures/bioluminescent-veins.png'),
                  fit: BoxFit.cover, opacity: .06)),
                child: Padding(padding: padding, child: child))),
          ),
        ),
      ),
    );
  }
}

class _StoneRimPainter extends CustomPainter {
  _StoneRimPainter(this.radius, this.highlighted, this.scene) : super(repaint: scene);
  final GeodeSceneController? scene;
  final double radius;
  final bool highlighted;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(.8);
    final glow = .05 + (scene?.lightEnvelope ?? .2) * .6;
    final edge = BorderRadius.only(
      topLeft: Radius.circular(radius * .85), topRight: Radius.circular(radius * 1.1),
      bottomLeft: Radius.circular(radius * 1.05), bottomRight: Radius.circular(radius * .82));
    canvas.drawRRect(edge.toRRect(rect.deflate(1)), Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 2
      ..color = const Color(0xFF72F4C5).withValues(alpha: glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawRRect(edge.toRRect(rect), Paint()
      ..style = PaintingStyle.stroke..strokeWidth = highlighted ? 1.5 : 1
      ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [highlighted ? const Color(0xFFB1BD88) : const Color(0xFF6B7A57),
          const Color(0xFF34482E), const Color(0xFF182D23), const Color(0xFF465139)],
        stops: const [0, .38, .65, 1]).createShader(rect));
  }
  @override
  bool shouldRepaint(_StoneRimPainter old) => old.radius != radius || old.highlighted != highlighted || old.scene != scene;
}

class _StoneGrainPainter extends CustomPainter {
  const _StoneGrainPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final grain = Paint()..color = const Color(0x096AA171);
    // Deterministic mineral flecks; no textures or backdrop blur per control.
    for (var i = 0; i < 92; i++) {
      final x = ((i * .61803398875) % 1) * size.width;
      final y = ((i * .41421356237) % 1) * size.height;
      canvas.drawCircle(Offset(x, y), .5 + (i % 3) * .3, grain);
    }
    final vein = Path()..moveTo(size.width * .75, 0);
    for (var i = 1; i <= 10; i++) {
      vein.lineTo(size.width * .75 + math.sin(i * .75) * 7, size.height * i / 10);
    }
    canvas.drawPath(vein, Paint()..style = PaintingStyle.stroke
      ..strokeWidth = .7..color = const Color(0x096CC089));
  }
  @override
  bool shouldRepaint(_StoneGrainPainter old) => false;
}
