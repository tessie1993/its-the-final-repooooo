import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geode_engine/geode_engine.dart';
import '../state/geode_app_state.dart';
import 'scene_surface.dart';

/// One live field shared by the shell and every Navigator route.
class SceneHost extends StatefulWidget {
  const SceneHost({super.key, required this.state, required this.child});
  final GeodeAppState state;
  final Widget child;
  @override
  State<SceneHost> createState() => _SceneHostState();
}
class _SceneHostState extends State<SceneHost> {
  final _pointers = <int>{};
  void _release(int pointer) {
    _pointers.remove(pointer);
    if (_pointers.isEmpty) widget.state.scene.release();
  }
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state, child: widget.child,
    builder: (context, child) => LayoutBuilder(builder: (context, constraints) {
      final state = widget.state;
      final wide = constraints.maxWidth >= 900;
      Offset normalize(Offset point) => Offset(
        (point.dx / constraints.maxWidth).clamp(0.0, 1.0).toDouble(),
        (point.dy / constraints.maxHeight).clamp(0.0, 1.0).toDouble());
      return Listener(behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          _pointers.add(event.pointer);
          state.scene.touch(normalize(event.localPosition));
          if (state.haptics && state.enableDeviceServices && !state.scene.motionDisabled) {
            HapticFeedback.selectionClick();
          }
        },
        onPointerMove: (event) => state.scene.interact(normalize(event.localPosition)),
        onPointerUp: (event) => _release(event.pointer),
        onPointerCancel: (event) => _release(event.pointer),
        child: Stack(fit: StackFit.expand, children: [
          SceneSurface(controller: state.scene, interactive: false,
            enableNativeScene: state.enableDeviceServices && state.natureDetails && !state.nativeVisuals.enabled,
            orbAlignment: state.immersive ? Alignment.center
              : (wide ? const Alignment(-.40, -.08) : const Alignment(0, -.15)),
            orbScale: wide ? .8 : .96),
          ListenableBuilder(listenable: state.nativeVisuals, builder: (context, _) =>
            state.nativeVisuals.enabled
              ? NativeVisualizerTexture(controller: state.nativeVisuals)
              : const SizedBox.expand()),
          const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0x57000000), Colors.transparent, Color(0xCC031F25)], stops: [0, .4, 1])))),
          if (state.destination != 0)
            const IgnorePointer(child: ColoredBox(color: Color(0x4D102438))),
          MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations:
            MediaQuery.disableAnimationsOf(context) || state.scene.reducedMotion), child: child!),
        ]));
    }),
  );
}
