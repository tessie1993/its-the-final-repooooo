import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geode_engine/geode_engine.dart';
import 'package:geode_native/geode_native.dart';
import '../state/geode_app_state.dart';
import '../three_d/three_d_support.dart';
import 'scene_surface.dart';
import 'nature_motion_scope.dart';

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
  final _nativePointers = <int, ({Offset position, Duration time})>{};
  void _nativeTouch(int pointer, Offset position, Duration time, {bool release = false}) {
    final previous = _nativePointers[pointer];
    final elapsed = previous == null ? .016 : (time - previous.time).inMicroseconds / 1000000;
    if (!release && previous != null && elapsed < 1 / 60) return;
    if (release) { _nativePointers.remove(pointer); }
    else { _nativePointers[pointer] = (position: position, time: time); }
    if (!widget.state.nativeVisuals.enabled || widget.state.scene.motionDisabled) return;
    final delta = previous == null || release ? Offset.zero : position - previous.position;
    unawaited(GeodeNative.instance.touch(x: position.dx, y: position.dy,
      dx: delta.dx, dy: delta.dy, dt: elapsed.clamp(.001, .1).toDouble(),
      strength: release ? 0 : widget.state.scene.rippleStrength).catchError((Object _) {}));
  }
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
        (point.dx / (constraints.maxWidth > 0 ? constraints.maxWidth : 1)).clamp(0.0, 1.0).toDouble(),
        (point.dy / (constraints.maxHeight > 0 ? constraints.maxHeight : 1)).clamp(0.0, 1.0).toDouble());
      return Listener(behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          _pointers.add(event.pointer);
          final position = normalize(event.localPosition);
          state.scene.touch(position);
          _nativeTouch(event.pointer, position, event.timeStamp);
          if (state.haptics && state.enableDeviceServices && !state.scene.motionDisabled) {
            HapticFeedback.selectionClick();
          }
        },
        onPointerMove: (event) {
          final position = normalize(event.localPosition);
          state.scene.interact(position);
          _nativeTouch(event.pointer, position, event.timeStamp);
        },
        onPointerUp: (event) {
          _nativeTouch(event.pointer, normalize(event.localPosition), event.timeStamp, release: true);
          _release(event.pointer);
        },
        onPointerCancel: (event) {
          _nativeTouch(event.pointer, normalize(event.localPosition), event.timeStamp, release: true);
          _release(event.pointer);
        },
        child: Stack(fit: StackFit.expand, children: [
          SceneSurface(controller: state.scene, interactive: false,
            enableNativeScene: state.enableDeviceServices && state.natureDetails && !state.nativeVisuals.enabled,
            orbAlignment: state.immersive ? Alignment.center
              : (wide ? const Alignment(-.40, -.08) : const Alignment(0, -.15)),
            orbScale: wide ? .8 : .96,
            destination: state.immersive ? -1 : state.destination),
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
            MediaQuery.disableAnimationsOf(context) || state.scene.reducedMotion),
              child: GeodeStateScope(state: state,
                enabled: state.enableDeviceServices && state.natureDetails,
                highQuality: state.scene.highQuality,
                child: NatureMotionScope(controller: state.scene, child: child!))),
        ]));
    }),
  );
}
