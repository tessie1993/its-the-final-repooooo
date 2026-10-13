import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;

import '../media/music_models.dart';
import 'geode_materials.dart';
import 'geode_meshes.dart';
import 'scene_view.dart';
import 'three_d_support.dart';

/// One cover in the carousel: the track whose artwork it shows, its caption and
/// what opening it does (play a track, open an album, ...).
typedef CarouselItem = ({MusicTrack? cover, String title, VoidCallback open});

/// Album covers as thick stone slabs on a curved cover-flow arc over a still pool.
/// A window of slots is reused as the focus moves, so the scene stays small for
/// libraries of any size.
class CarouselScene extends ThreeDScene {
  CarouselScene(this._materials) {
    scene
      ..environmentIntensity = .9
      ..exposure = 1.05
      ..toneMapping = fs.ToneMappingMode.pbrNeutral
      ..directionalLight = fs.DirectionalLight(
        direction: vm.Vector3(.35, -1, .9), color: vm.Vector3(1, .95, .84), intensity: 1.6);
    final slab = GeodeMeshes.slab(width: 1.24, height: 1.24, depth: .1);
    final face = GeodeMeshes.slabFace(width: 1.16, height: 1.16);
    final edge = _materials.stone(1);
    for (var i = 0; i < _window; i++) {
      final material = fs.PhysicallyBasedMaterial(baseColorTexture: _materials.stoneDial)
        ..roughnessFactor = .5..metallicFactor = 0..clearcoat = .6..clearcoatRoughness = .2
        ..doubleSided = true;
      final node = fs.Node(name: 'Cover slot $i')
        ..add(fs.Node(name: 'Slab', mesh: fs.Mesh(slab, edge)))
        ..add(fs.Node(name: 'Cover', mesh: fs.Mesh(face, material))
          ..localTransform = (vm.Matrix4.identity()..translateByDouble(0, 0, -.052, 1)));
      _slots.add((node: node, face: material, key: null, request: 0));
      scene.add(node);
    }
    scene.add(fs.Node(name: 'Pool', mesh: fs.Mesh(fs.DiscGeometry(radius: 4, segments: 64),
      GeodeMaterials.water()))..position = vm.Vector3(0, -.86, 1.2));
  }

  static const _window = 11;
  final GeodeMaterials _materials;
  final _slots = <({fs.Node node, fs.PhysicallyBasedMaterial face, String? key, int request})>[];

  @override
  final scene = fs.Scene();

  @override
  final camera = fs.PerspectiveCamera(position: vm.Vector3(0, .32, -4.3),
    target: vm.Vector3(0, -.05, 0), fovNear: .2, fovFar: 14);

  List<CarouselItem> _items = const [];
  double position = 0, velocity = 0;
  bool dragging = false;

  int get focused => _items.isEmpty ? -1 : position.round().clamp(0, _items.length - 1);

  set items(List<CarouselItem> value) {
    final previous = focused >= 0 ? _items[focused].cover?.id : null;
    _items = value;
    if (value.isEmpty) {
      position = 0;
    } else {
      // Keep the same cover in front when the list is re-sorted or filtered.
      final keep = previous == null ? -1 : value.indexWhere((item) => item.cover?.id == previous);
      position = (keep >= 0 ? keep : position.round()).clamp(0, value.length - 1).toDouble();
    }
  }

  void _assign(int slot, int index) {
    final current = _slots[slot];
    // Keyed by cover, so rebuilding the list with the same tracks reloads nothing.
    final key = _items[index].cover?.id ?? 'none:$index';
    if (current.key == key) return;
    final request = current.request + 1;
    _slots[slot] = (node: current.node, face: current.face, key: key, request: request);
    current.face.baseColorTexture = _materials.stoneDial;
    unawaited(ArtworkTextures.instance.forTrack(_items[index].cover).then((texture) {
      if (texture == null || _slots[slot].request != request) return;
      current.face.baseColorTexture = texture;
      scene.update(0);
    }));
  }

  @override
  bool advance(double dt, {required bool live}) {
    final count = _items.length;
    if (count == 0) {
      for (final slot in _slots) { slot.node.visible = false; }
      scene.update(0);
      return false;
    }
    if (!dragging) {
      if (!live) {
        position = position.roundToDouble().clamp(0, count - 1);
        velocity = 0;
      } else {
        position += velocity * dt;
        velocity *= math.exp(-dt * 3.2);
        // Rubber band past the ends, then a spring onto the nearest cover.
        final target = position.roundToDouble().clamp(0, count - 1).toDouble();
        if (velocity.abs() < 2.5) {
          final pull = (target - position) * (1 - math.exp(-dt * 10));
          position += pull;
          velocity *= math.exp(-dt * 6);
        }
        if (position < -.5 || position > count - .5) {
          position = position.clamp(-.5, count - .5).toDouble();
          velocity = 0;
        }
      }
    }
    final centre = position.round();
    for (var slot = 0; slot < _slots.length; slot++) {
      // Slot k shows the item whose index is congruent to it within the window.
      final index = centre - _window ~/ 2 + ((slot - (centre - _window ~/ 2)) % _window);
      final node = _slots[slot].node;
      if (index < 0 || index >= count) {
        node.visible = false;
        continue;
      }
      node.visible = true;
      _assign(slot, index);
      final k = index - position;
      final side = k.clamp(-1.0, 1.0);
      final spread = k.abs() <= 1 ? k * .95 : side * (.95 + (k.abs() - 1) * .52);
      final depth = side.abs() * .75 + math.max(0, k.abs() - 1) * .12;
      final scale = 1 - math.min(k.abs(), 3) * .06;
      node.mutateLocalTransform((m) => m
        ..setIdentity()
        ..translateByDouble(spread, math.sin(index * 1.3) * .015, depth, 1)
        ..rotateY(side * .95)
        ..scaleByDouble(scale, scale, scale, 1));
    }
    scene.update(0);
    final settled = (position - position.roundToDouble()).abs() < .002 && velocity.abs() < .01;
    return live && (dragging || !settled);
  }
}

/// The library's 3D cover flow. Drag or fling to browse, tap the front cover to open
/// it, tap a side cover to bring it forward. Hidden in flat mode; the list below it
/// always offers every item.
class Carousel3D extends StatefulWidget {
  const Carousel3D({super.key, required this.items, this.height = 230});
  final List<CarouselItem> items;
  final double height;

  @override
  State<Carousel3D> createState() => _Carousel3DState();
}

class _Carousel3DState extends State<Carousel3D> {
  final _view = GlobalKey<ThreeDViewState<CarouselScene>>();
  final _focus = ValueNotifier<int>(0);

  CarouselScene? get _scene => _view.currentState?.scene;

  void _move(int delta) {
    final scene = _scene;
    if (scene == null || widget.items.isEmpty) return;
    scene.position = (scene.focused + delta).clamp(0, widget.items.length - 1).toDouble();
    scene.velocity = 0;
    _focus.value = scene.focused;
    _view.currentState?.wake();
  }

  void _tap(TapUpDetails details, double width) {
    final scene = _scene;
    if (scene == null || widget.items.isEmpty) return;
    final x = details.localPosition.dx / width;
    if (x < .3) {
      _move(-1);
    } else if (x > .7) {
      _move(1);
    } else {
      widget.items[scene.focused].open();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = threeDModeIn(context);
    if (mode == ThreeDMode.flat || widget.items.isEmpty) return const SizedBox.shrink();
    return SizedBox(height: widget.height, child: LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return ValueListenableBuilder<int>(valueListenable: _focus, builder: (context, focus, view) {
        final index = focus.clamp(0, widget.items.length - 1);
        return Semantics(
          label: 'Cover flow, ${index + 1} of ${widget.items.length}: ${widget.items[index].title}',
          hint: 'Double tap to open',
          onTap: () => widget.items[index].open(),
          onIncrease: index < widget.items.length - 1 ? () => _move(1) : null,
          onDecrease: index > 0 ? () => _move(-1) : null,
          child: view,
        );
      }, child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          _scene?.dragging = true;
          _view.currentState?.wake();
        },
        onHorizontalDragUpdate: (details) {
          final scene = _scene;
          if (scene == null) return;
          scene.position -= details.delta.dx / (width * .32);
          _focus.value = scene.focused;
          _view.currentState?.wake();
        },
        onHorizontalDragEnd: (details) {
          final scene = _scene;
          if (scene == null) return;
          scene
            ..dragging = false
            ..velocity = -details.velocity.pixelsPerSecond.dx / (width * .32);
          _view.currentState?.wake();
          // The focus label settles with the spring; update it once motion ends.
          Future<void>.delayed(const Duration(milliseconds: 700), () {
            if (mounted && _scene != null) _focus.value = _scene!.focused;
          });
        },
        onTapUp: (details) => _tap(details, width),
        child: ExcludeSemantics(child: ThreeDView<CarouselScene>(
          key: _view,
          mode: mode,
          fallback: const SizedBox.shrink(),
          pixelRatio: threeDPixelRatioIn(context),
          create: () async => CarouselScene(await GeodeMaterials.load()),
          onScene: (scene) {
            if (!identical(scene._items, widget.items)) scene.items = widget.items;
          },
        )),
      ));
    }));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }
}
