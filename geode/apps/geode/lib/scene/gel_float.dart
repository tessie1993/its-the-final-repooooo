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
    builder: (context, child) => Transform.translate(
      offset: controller.offsetFor(anchor, weight: weight, phase: phase),
      transformHitTests: true,
      child: child,
    ),
  );
}
