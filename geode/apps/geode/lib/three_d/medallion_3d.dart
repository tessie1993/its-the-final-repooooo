import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;

import '../media/music_controller.dart';
import '../scene/geode_scene_controller.dart';
import 'geode_materials.dart';
import 'geode_meshes.dart';
import 'scene_view.dart';
import 'three_d_support.dart';

/// The now-playing record: a jade-rimmed river-stone disc carrying the track's cover,
/// spinning while it plays, ringed by pebble beads that light up with progress.
class MedallionScene extends ThreeDScene {
  MedallionScene(this._materials, this.music, this.nature, {this.compact = false}) {
    scene
      ..environmentIntensity = .85
      ..exposure = 1.05
      ..toneMapping = fs.ToneMappingMode.pbrNeutral
      ..directionalLight = fs.DirectionalLight(
        direction: vm.Vector3(.5, -1, .8), color: vm.Vector3(1, .94, .80), intensity: 1.5);
    _face.baseColorTexture = _materials.stoneDial;
    _record
      ..add(fs.Node(name: 'Record face', mesh: fs.Mesh(_dialMesh, _face)))
      ..add(fs.Node(name: 'Jade rim', mesh: fs.Mesh(
        fs.TorusGeometry(radius: 1.0, tubeRadius: .07, radialSegments: 64, tubularSegments: 14),
        GeodeMaterials.jade())));
    _tilted.add(_record);
    if (!compact) {
      final bead = GeodeMeshes.pebble(seed: 3, segments: 16, rings: 10);
      final lit = _materials.stone(0, glow: 1)..emissiveFactor = vm.Vector4(.35, .95, .62, 1);
      final dim = _materials.stone(1);
      for (var i = 0; i < _beadCount; i++) {
        final angle = -math.pi / 2 + i * math.pi * 2 / _beadCount;
        final at = vm.Vector3(math.cos(angle) * 1.3, -math.sin(angle) * 1.3, 0);
        final holder = fs.Node(name: 'Seek bead $i')
          ..localTransform = (vm.Matrix4.identity()
            ..translateByVector3(at)
            ..rotateZ(angle)
            ..scaleByDouble(.075, .075, .075, 1));
        final on = fs.Node(name: 'Played', mesh: fs.Mesh(bead, lit));
        final off = fs.Node(name: 'Ahead', mesh: fs.Mesh(bead, dim));
        holder..add(on)..add(off);
        _beads.add((on, off));
        _tilted.add(holder);
      }
      final dewMesh = fs.SphereGeometry(radius: .07, segments: 16, rings: 10);
      final dew = GeodeMaterials.dew();
      for (var i = 0; i < 5; i++) {
        final node = fs.Node(name: 'Dew $i', mesh: fs.Mesh(dewMesh, dew));
        _seeds.add(node);
        scene.add(node);
      }
    }
    scene.add(_tilted);
  }

  static const _beadCount = 40;
  static final _dialMesh = GeodeMeshes.dial(radius: .96, thickness: .14);

  final GeodeMaterials _materials;
  final MusicController music;
  final GeodeSceneController nature;
  final bool compact;

  final _tilted = fs.Node(name: 'Medallion');
  final _record = fs.Node(name: 'Spinning record');
  final _beads = <(fs.Node, fs.Node)>[];
  final _seeds = <fs.Node>[];
  final _face = fs.PhysicallyBasedMaterial()
    ..roughnessFactor = .55
    ..metallicFactor = 0
    ..clearcoat = .5
    ..clearcoatRoughness = .25
    ..doubleSided = true;

  @override
  final scene = fs.Scene();

  @override
  late final fs.PerspectiveCamera camera = fs.PerspectiveCamera(
    position: vm.Vector3(0, 0, compact ? -2.9 : -4.1), target: vm.Vector3.zero(), fovNear: .2, fovFar: 12);

  String? _trackId;
  int _artRequest = 0;
  double _angle = 0, _speed = 0, _time = 0;
  int _litBeads = -1;

  /// Drag tilt (radians) set by the widget; eases back to rest on release.
  Offset dragTilt = Offset.zero;
  Offset _tilt = Offset.zero;
  bool dragging = false;

  /// While seeking along the ring, the beads follow the finger instead of playback.
  double? seekPreview;

  void _syncArtwork() {
    final track = music.currentTrack;
    if (track?.id == _trackId) return;
    _trackId = track?.id;
    final request = ++_artRequest;
    _face.baseColorTexture = _materials.stoneDial;
    unawaited(ArtworkTextures.instance.forTrack(track).then((texture) {
      if (request != _artRequest || texture == null) return;
      _face.baseColorTexture = texture;
      scene.update(0);
    }));
  }

  double get progress {
    final total = music.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (music.position.value.inMilliseconds / total).clamp(0.0, 1.0).toDouble();
  }

  @override
  bool advance(double dt, {required bool live}) {
    _syncArtwork();
    final playing = music.playing;
    // ~10 rpm while playing, easing to a stop on pause; still under reduced motion.
    final target = playing && live ? math.pi * 2 / 6 : 0.0;
    _speed += (target - _speed) * (1 - math.exp(-dt * 2.2));
    if (live) {
      _angle = (_angle + _speed * dt) % (math.pi * 2);
      _time += dt;
    }
    final goal = dragging ? dragTilt : Offset.zero;
    _tilt = live ? Offset.lerp(_tilt, goal, 1 - math.exp(-dt * 9))! : goal;
    final quiet = !live || nature.effectiveReducedMotion;
    final pulse = quiet ? 0.0 : nature.audioRms * .7 + nature.audioBass * .4;
    final bob = quiet ? 0.0 : math.sin(_time * .7) * .03;

    _tilted.mutateLocalTransform((m) => m
      ..setIdentity()
      ..translateByDouble(0, bob, 0, 1)
      ..rotateX(-.16 + _tilt.dy)
      ..rotateY(-.22 + _tilt.dx));
    final breathe = 1 + pulse * .025;
    _record.mutateLocalTransform((m) => m
      ..setIdentity()
      ..rotateZ(-_angle)
      ..scaleByDouble(breathe, breathe, 1, 1));
    final lit = ((seekPreview ?? progress) * _beads.length).round();
    if (lit != _litBeads) {
      _litBeads = lit;
      for (var i = 0; i < _beads.length; i++) {
        _beads[i].$1.visible = i < lit;
        _beads[i].$2.visible = i >= lit;
      }
    }
    for (var i = 0; i < _seeds.length; i++) {
      final phase = i * math.pi * 2 / _seeds.length + _time * .25;
      _seeds[i].position = vm.Vector3(math.cos(phase) * 1.7, math.sin(phase) * .55 + .1,
        math.sin(phase) * .9 - .2);
    }
    scene.renderScale = nature.highQuality ? .9 : .7;
    scene.update(0);
    final settling = (_speed - target).abs() > .01 || (_tilt - goal).distance > .002;
    return live && (playing || settling || dragging || pulse > .01);
  }
}

/// The medallion as a widget: drag across the disc to tilt it, drag along the bead
/// ring to seek. [fallback] (the flat player orb) shows in flat mode.
class Medallion3D extends StatefulWidget {
  const Medallion3D({super.key, required this.music, required this.nature,
    required this.fallback, this.compact = false, this.semanticsLabel});
  final MusicController music;
  final GeodeSceneController nature;
  final Widget fallback;
  final bool compact;
  final String? semanticsLabel;

  @override
  State<Medallion3D> createState() => _Medallion3DState();
}

class _Medallion3DState extends State<Medallion3D> {
  final _view = GlobalKey<ThreeDViewState<MedallionScene>>();
  bool _seeking = false;

  MedallionScene? get _scene => _view.currentState?.scene;

  double _ringAngle(Offset local, Size size) {
    final v = local - size.center(Offset.zero);
    // 0 at twelve o'clock, increasing clockwise, like the bead ring.
    return ((math.atan2(v.dx, -v.dy) / (math.pi * 2)) + 1) % 1;
  }

  void _start(DragStartDetails details, Size size) {
    final scene = _scene;
    if (scene == null) return;
    final v = details.localPosition - size.center(Offset.zero);
    _seeking = !widget.compact && widget.music.duration > Duration.zero &&
      v.distance > size.shortestSide * .34;
    scene.dragging = !_seeking;
    if (_seeking) scene.seekPreview = _ringAngle(details.localPosition, size);
    _view.currentState?.wake();
  }

  void _update(DragUpdateDetails details, Size size) {
    final scene = _scene;
    if (scene == null) return;
    if (_seeking) {
      scene.seekPreview = _ringAngle(details.localPosition, size);
    } else {
      final v = details.localPosition - size.center(Offset.zero);
      scene.dragTilt = Offset((v.dx / size.width).clamp(-.5, .5) * .9, (v.dy / size.height).clamp(-.5, .5) * .9);
    }
    _view.currentState?.wake();
  }

  void _end() {
    final scene = _scene;
    if (scene == null) return;
    final preview = scene.seekPreview;
    if (_seeking && preview != null) {
      unawaited(widget.music.seek(Duration(
        milliseconds: (widget.music.duration.inMilliseconds * preview).round())));
    }
    scene..dragging = false..seekPreview = null;
    _seeking = false;
    _view.currentState?.wake();
  }

  @override
  Widget build(BuildContext context) {
    final mode = threeDModeIn(context);
    final view = ThreeDView<MedallionScene>(
      key: _view,
      mode: mode,
      fallback: widget.fallback,
      semanticsLabel: widget.semanticsLabel,
      pixelRatio: threeDPixelRatioIn(context),
      // Not the nature clock: it ticks every frame, and the record only needs frames
      // while playing, settling, dragging or when playback state changes.
      listenable: Listenable.merge([widget.music, widget.music.position]),
      create: () async => MedallionScene(await GeodeMaterials.load(), widget.music, widget.nature,
        compact: widget.compact),
    );
    if (mode == ThreeDMode.flat || widget.compact) return view;
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => _start(details, size),
        onPanUpdate: (details) => _update(details, size),
        onPanEnd: (_) => _end(),
        onPanCancel: _end,
        child: view,
      );
    });
  }
}
