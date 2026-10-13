import 'package:flutter/widgets.dart';

import 'geode_scene_controller.dart';

/// Makes a component participate in the shared gel without rebuilding its body.
class GelFloat extends StatelessWidget {
  const GelFloat({
    super.key,
    required this.controller,
    required this.anchor,
    required this.child,
    this.weight = 1,
    this.phase = 0,
  });

  final GeodeSceneController controller;
  final Offset anchor;
  final double weight;
  final double phase;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: RepaintBoundary(child: child),
    builder: (context, child) {
      final offset = controller.offsetFor(anchor, weight: weight, phase: phase);
      final tilt = controller.effectiveReducedMotion ? Offset.zero : controller.tilt;
      final depth = 1 / weight.clamp(.5, 4.0).toDouble();
      return Transform(
        alignment: Alignment.center,
        transformHitTests: true,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0007)
          ..setEntry(0, 3, offset.dx)
          ..setEntry(1, 3, offset.dy)
          ..rotateX(-tilt.dy * .009 * depth)
          ..rotateY(tilt.dx * .009 * depth),
        child: child,
      );
    },
  );
}
