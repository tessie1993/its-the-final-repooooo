import 'dart:math' as math;

import 'package:flame/game.dart' show GameWidget;
import 'package:flame_3d/camera.dart';
import 'package:flame_3d/components.dart';
import 'package:flame_3d/game.dart';
import 'package:flame_3d/resources.dart' as resource;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

import 'three_d_support.dart';

/// One small Flame scene for all four navigation stones. Text, focus and taps
/// remain ordinary accessible Flutter controls above this decorative layer.
class PebbleDock extends StatefulWidget {
  const PebbleDock({super.key, required this.selected});
  final int selected;
  @override
  State<PebbleDock> createState() => _PebbleDockState();
}

class _PebbleDockState extends State<PebbleDock> {
  late final _game = _DockGame(_failed);
  bool _unavailable = false;

  void _failed() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _unavailable = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = threeDModeIn(context);
    if (_unavailable || mode == ThreeDMode.flat) return const SizedBox.expand();
    _game.select(widget.selected, live: mode == ThreeDMode.live);
    return IgnorePointer(child: ExcludeSemantics(child: GameWidget(game: _game,
      errorBuilder: (context, error) => const SizedBox.expand())));
  }
}

class _DockGame extends FlameGame3D<World3D, CameraComponent3D> {
  _DockGame(this.onFailure) : super(world: World3D(), camera: CameraComponent3D(
    position: Vector3(0, .8, 6), target: Vector3.zero(),
    projection: CameraProjection.orthographic, fovY: 2.2));

  final VoidCallback onFailure;
  final _stones = <MeshComponent>[];
  final _materials = <resource.SpatialMaterial>[];
  final _heights = List<double>.filled(4, 0);
  int _selected = 0;
  bool _live = true;
  bool _failed = false;
  double _remaining = .5;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    world.addAll([
      LightComponent.ambient(color: const Color(0xFFC0ECD6), intensity: .75),
      LightComponent.point(position: Vector3(-3, 4, 5),
        color: const Color(0xFFAAFFCE), intensity: 12),
    ]);
    for (var i = 0; i < 4; i++) {
      final material = resource.SpatialMaterial(albedoColor: const Color(0xFF355543),
        roughness: .65, metallic: .03);
      final stone = MeshComponent(mesh: resource.SphereMesh(radius: 1, segments: 16,
        material: material));
      _materials.add(material);
      _stones.add(stone);
      world.add(stone);
    }
  }

  void select(int index, {required bool live}) {
    if (_selected == index && _live == live) return;
    _selected = index;
    _live = live;
    _remaining = live ? .5 : .01;
    resumeEngine();
  }

  @override
  void onGameResize(v64.Vector2 size) {
    super.onGameResize(size);
    _remaining = .5;
    resumeEngine();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_stones.isEmpty || size.y <= 0) return;
    final slot = 2.2 * size.x / size.y / 4;
    final blend = _live ? 1 - math.exp(-dt.clamp(0.0, .05) * 18) : 1.0;
    for (var i = 0; i < 4; i++) {
      final target = i == _selected ? .14 : -.04;
      _heights[i] += (target - _heights[i]) * blend;
      _stones[i].position.setValues((i - 1.5) * slot, _heights[i], 0);
      _stones[i].scale.setValues(slot * .43, .77, .30);
      _materials[i].albedoColor = i == _selected
          ? const Color(0xFF54896A) : const Color(0xFF243D31);
    }
    _remaining -= dt;
    if (_remaining <= 0) pauseEngine();
  }

  @override
  void render(Canvas canvas) {
    if (_failed) return;
    canvas.save();
    try {
      super.render(canvas);
    } catch (_) {
      _failed = true;
      pauseEngine();
      onFailure();
    } finally {
      canvas.restore();
    }
  }
}
