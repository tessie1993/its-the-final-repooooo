import 'dart:math' as math;

import 'package:flame/game.dart' show GameWidget;
import 'package:flame_3d/camera.dart';
import 'package:flame_3d/components.dart';
import 'package:flame_3d/game.dart';
import 'package:flame_3d/resources.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'three_d_support.dart';

/// The navigation dock's pebbles, rendered by flame_3d: one lit river pebble under
/// each tab. The selected pebble rises and glows, a pressed one sinks, and all of
/// them bob on the water. Tab hit targets and labels stay Flutter widgets on top.
class DockGame extends FlameGame3D<World3D, CameraComponent3D> {
  DockGame({required this.count})
    : super(world: World3D(), camera: CameraComponent3D(
        fovY: 32, position: Vector3(0, 2.4, 7.2), target: Vector3(0, -.15, 0)));

  final int count;
  int selected = 0;
  int? pressed;
  bool live = true;
  double _time = 0;
  final _pebbles = <MeshComponent>[];
  final _lift = <double>[];

  static const _palette = [Color(0xFF7FA163), Color(0xFF9DA294), Color(0xFF9C7B4E), Color(0xFF6F8E80)];

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    world.addAll([
      LightComponent.ambient(intensity: .9),
      LightComponent.point(position: Vector3(-2.5, 4, 4), color: const Color(0xFFFFF1D6), intensity: 18),
      LightComponent.point(position: Vector3(3, 2, 3), color: const Color(0xFF9FE6C4), intensity: 6),
    ]);
    for (var i = 0; i < count; i++) {
      final pebble = MeshComponent(
        mesh: SphereMesh(radius: .5, segments: 40,
          material: SpatialMaterial(albedoColor: _palette[i % _palette.length], metallic: .04, roughness: .5)),
        position: Vector3.zero(),
        scale: Vector3(1, .58, .86),
      );
      _pebbles.add(pebble);
      _lift.add(i == selected ? 1 : 0);
    }
    world.addAll(_pebbles);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_pebbles.isEmpty || size.x <= 0 || size.y <= 0) return;
    if (live) _time += dt;
    // Place each pebble under its tab: the visible half-width at the pebbles' depth.
    final distance = camera.position.length;
    final halfHeight = distance * math.tan(camera.fovY * math.pi / 360);
    final halfWidth = halfHeight * size.x / size.y;
    for (var i = 0; i < _pebbles.length; i++) {
      final goal = i == pressed ? -.6 : (i == selected ? 1.0 : 0.0);
      _lift[i] = live ? _lift[i] + (goal - _lift[i]) * (1 - math.exp(-dt * 10)) : goal;
      final bob = live ? math.sin(_time * 1.3 + i * 1.7) * .035 : 0.0;
      final x = ((i + .5) / _pebbles.length * 2 - 1) * halfWidth;
      final pebble = _pebbles[i];
      pebble.position.setValues(x, -.25 + _lift[i] * .32 + bob, 0);
      final grow = 1 + _lift[i] * .14;
      pebble.scale.setValues(grow, .58 * grow, .86 * grow);
      pebble.rotation.setFromRotation(Matrix3.rotationY(live ? _time * .25 + i : i.toDouble()));
    }
  }
}

/// Hosts [DockGame] behind the dock's tab buttons. Flat mode (tests, no device
/// services, Flutter GPU unavailable) renders nothing and the 2D dock stands alone.
class Dock3D extends StatefulWidget {
  const Dock3D({super.key, required this.count, required this.selected, this.pressed});
  final int count;
  final int selected;
  final int? pressed;

  @override
  State<Dock3D> createState() => _Dock3DState();
}

class _Dock3DState extends State<Dock3D> {
  DockGame? _game;
  bool _failed = false;

  DockGame _ensureGame() => _game ??= DockGame(count: widget.count)..selected = widget.selected;

  @override
  Widget build(BuildContext context) {
    final mode = threeDModeIn(context);
    if (mode == ThreeDMode.flat || _failed) return const SizedBox.shrink();
    final game = _ensureGame()
      ..selected = widget.selected
      ..pressed = widget.pressed
      ..live = mode == ThreeDMode.live;
    return ExcludeSemantics(child: IgnorePointer(child: GameWidget<DockGame>(
      game: game,
      errorBuilder: (context, error) {
        if (kDebugMode) debugPrint('3D dock uses its flat look: $error');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_failed) setState(() => _failed = true);
        });
        return const SizedBox.shrink();
      },
    )));
  }
}
