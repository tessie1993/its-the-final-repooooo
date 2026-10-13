import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show HSVColor;
import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;

import '../three_d/geode_materials.dart';
import '../three_d/geode_meshes.dart';
import 'geode_scene_controller.dart';
import 'bioluminescent_world.dart';
import 'nature_geometry.dart';

/// The 3D nature world behind every screen, rendered by Flutter GPU over the
/// full-screen nature shader: a still pool ringed by moss, river and bark stones,
/// fern fronds, a quartz cluster, a jade ring and floating dew. Each shell
/// destination is a camera station; navigating glides the camera between them.
class NativeNatureScene {
  NativeNatureScene(this._materials) {
    scene
      ..environmentIntensity = .5
      ..exposure = 1.05
      ..toneMapping = fs.ToneMappingMode.pbrNeutral
      ..directionalLight = fs.DirectionalLight(
        direction: vm.Vector3(.5, -1, .8),
        color: vm.Vector3(.86, .96, 1),
        intensity: 1.25,
      );
    _buildGeometry();
    _livingWorld = BioluminescentWorld(scene, _materials);
  }

  final GeodeMaterials _materials;
  late final BioluminescentWorld _livingWorld;

  /// Shell destination (0 visuals, 1 music, 2 studio, 3 settings, -1 immersive).
  int destination = 0;
  double _lastTime = -1;

  // Camera stations: (eye, target) per destination.
  static final _stations = <int, (vm.Vector3, vm.Vector3)>{
    -1: (vm.Vector3(0, -.2, -7.2), vm.Vector3(0, -.1, 0)),
    0: (vm.Vector3(0, 0, -6.5), vm.Vector3.zero()),
    1: (vm.Vector3(1.25, .35, -6.1), vm.Vector3(.35, -.35, .2)),
    2: (vm.Vector3(-1.35, .85, -6.2), vm.Vector3(-.4, .05, .1)),
    3: (vm.Vector3(.2, 2.3, -5.6), vm.Vector3(0, -.85, .6)),
  };

  final _pool = fs.Node(name: 'Still pool');
  final _stones = <fs.Node>[];
  final _ferns = <fs.Node>[];

  final scene = fs.Scene();
  final camera = fs.PerspectiveCamera(
    position: vm.Vector3(0, 0, -6.5),
    target: vm.Vector3.zero(),
    fovNear: .5,
    fovFar: 16,
  );
  final _crystals = fs.Node(name: 'Quartz cluster');
  final _jade = fs.Node(name: 'Polished jade');
  final _dew = <fs.Node>[];
  final _lenses = <fs.Node>[];
  final _quartz = fs.PhysicallyBasedMaterial()
    ..roughnessFactor = .13
    ..metallicFactor = .03
    ..clearcoat = 1
    ..clearcoatRoughness = .08
    ..transmission = .32
    ..ior = 1.46
    ..thickness = .45
    ..attenuationDistance = 1.4
    ..attenuationColor = vm.Vector4(.32, .81, .73, 1)
    ..iridescence = .12;
  final _jadeMaterial = fs.PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(.045, .24, .18, 1)
    ..roughnessFactor = .26
    ..metallicFactor = .04
    ..clearcoat = 1
    ..clearcoatRoughness = .11;
  final _dewMaterial = fs.PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(.67, .94, .89, 1)
    ..roughnessFactor = .06
    ..metallicFactor = .06
    ..transmission = .58
    ..ior = 1.333
    ..thickness = .14
    ..clearcoat = 1;
  final _lensMaterial = fs.PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(.42, .78, .94, 1)
    ..roughnessFactor = .09
    ..metallicFactor = .025
    ..transmission = .68
    ..ior = 1.333
    ..thickness = .22
    ..clearcoat = 1
    ..clearcoatRoughness = .06
    ..iridescence = .18
    ..emissiveFactor = vm.Vector4(.015, .045, .055, 1);
  double _lastHue = -1;
  double _lastMaterial = -1;
  bool failed = false;

  void _buildGeometry() {
    final crystalMesh = fs.Mesh(createQuartzGeometry(), _quartz);
    _crystals
      ..add(fs.Node(name: 'Main quartz', mesh: crystalMesh))
      ..add(fs.Node(name: 'Left quartz', mesh: crystalMesh)
        ..localTransform = (vm.Matrix4.identity()
          ..translateByDouble(-.28, -.22, -.05, 1)
          ..rotateZ(.39)
          ..scaleByDouble(.60, .67, .65, 1)))
      ..add(fs.Node(name: 'Right quartz', mesh: crystalMesh)
        ..localTransform = (vm.Matrix4.identity()
          ..translateByDouble(.25, -.26, .12, 1)
          ..rotateZ(-.32)
          ..scaleByDouble(.48, .53, .48, 1)));
    _jade.add(fs.Node(
      name: 'Jade ring',
      mesh: fs.Mesh(fs.TorusGeometry(
        radius: .34, tubeRadius: .115,
        radialSegments: 48, tubularSegments: 20,
      ), _jadeMaterial),
    ));
    final dewMesh = fs.Mesh(
      fs.SphereGeometry(radius: .07, segments: 20, rings: 12),
      _dewMaterial,
    );
    for (var i = 0; i < 3; i++) {
      final node = fs.Node(name: 'Dew ${i + 1}', mesh: dewMesh);
      _dew.add(node);
      scene.add(node);
    }
    final lensMesh = fs.Mesh(
      fs.SphereGeometry(radius: .16, segments: 28, rings: 18), _lensMaterial);
    for (var i = 0; i < 4; i++) {
      final node = fs.Node(name: 'Floating sap pebble ${i + 1}', mesh: lensMesh);
      _lenses.add(node);
      scene.add(node);
    }
    scene..add(_crystals)..add(_jade);

    _pool.add(fs.Node(name: 'Water', mesh: fs.Mesh(fs.DiscGeometry(radius: 3.2, segments: 64),
      GeodeMaterials.water())));
    _pool.position = vm.Vector3(0, -2.55, 1.2);
    scene.add(_pool);
    final pebble = GeodeMeshes.pebble();
    final smallPebble = GeodeMeshes.pebble(seed: 21, segments: 24, rings: 14);
    // (x, y, z, scale, material, yaw): stones around the pool's near rim.
    const stones = [
      (-1.55, -2.30, -.10, .48, 0, .4), (-.85, -2.42, .45, .30, 1, 1.2), (1.35, -2.32, .05, .42, 2, 2.1),
      (.55, -2.45, -.35, .24, 1, .7), (2.05, -2.20, .85, .36, 0, 2.8), (-2.15, -2.18, 1.0, .34, 2, 1.6),
    ];
    for (final (x, y, z, size, material, yaw) in stones) {
      final node = fs.Node(name: 'River stone', mesh: fs.Mesh(size > .35 ? pebble : smallPebble,
        _materials.stone(material, glow: material == 0 ? .25 : 0)))
        ..localTransform = (vm.Matrix4.identity()
          ..translateByDouble(x, y, z, 1)
          ..rotateY(yaw)
          ..scaleByDouble(size, size, size, 1));
      _stones.add(node);
      scene.add(node);
    }
    final fern = GeodeMeshes.fern();
    final leaf = GeodeMaterials.leaf();
    // (x, y, z, scale, lean, yaw): fronds rising behind the stones.
    const ferns = [(-1.85, -1.55, .35, 1.05, .35, .3), (-1.25, -1.75, .75, .8, .15, 1.1),
      (1.75, -1.6, .45, .95, -.4, 2.6), (2.25, -1.4, 1.1, .85, -.25, 2.2)];
    for (final (x, y, z, size, lean, yaw) in ferns) {
      final node = fs.Node(name: 'Fern frond', mesh: fs.Mesh(fern, leaf))
        ..localTransform = (vm.Matrix4.identity()
          ..translateByDouble(x, y, z, 1)
          ..rotateY(yaw)
          ..rotateZ(lean)
          ..scaleByDouble(size, size, size, 1));
      _ferns.add(node);
      scene.add(node);
    }
  }

  void _glideCamera(GeodeSceneController controller, double aspect) {
    final station = _stations[destination] ?? _stations[0]!;
    // Narrow portrait screens pull back so the stations keep their framing.
    final pullBack = aspect < .75 ? (.75 - aspect) * 3.2 : 0.0;
    final eye = station.$1 + vm.Vector3(0, 0, -pullBack);
    final target = station.$2;
    final time = controller.time;
    final dt = _lastTime < 0 ? 1.0 : (time - _lastTime).clamp(0.0, .1).toDouble();
    _lastTime = time;
    // Reduced motion jumps straight to the station; otherwise ease in ~0.6 s.
    final blend = controller.motionDisabled ? 1.0 : 1 - math.exp(-dt * 5);
    final tilt = controller.effectiveReducedMotion ? Offset.zero : controller.tilt;
    camera.position.setFrom(camera.position + (eye + vm.Vector3(tilt.dx * .18, -tilt.dy * .12, 0)
      - camera.position) * blend);
    camera.target.setFrom(camera.target + (target - camera.target) * blend);
  }

  void _swayFerns(double t, double wind) {
    for (var i = 0; i < _ferns.length; i++) {
      final sway = math.sin(t * (.55 + i * .07) + i * 1.7) * (.035 + wind * .06);
      _ferns[i].mutateLocalTransform((matrix) => matrix.rotateZ(sway - (_fernSway[i])));
      _fernSway[i] = sway;
    }
  }

  late final List<double> _fernSway = List.filled(_ferns.length, 0);

  void update(GeodeSceneController controller, {double aspect = .5}) {
    _glideCamera(controller, aspect);
    final t = controller.effectiveReducedMotion ? 0.0 : controller.time;
    final tilt = controller.effectiveReducedMotion ? Offset.zero : controller.tilt;
    final wake = controller.effectiveReducedMotion ? 0.0 : controller.pulse;
    _crystals.mutateLocalTransform((matrix) => matrix
      ..setIdentity()
      ..translateByDouble(1.52 + tilt.dx * .05,
          1.28 + math.sin(t * .38) * .035 - tilt.dy * .04, .1, 1)
      ..rotateX(-.13 + tilt.dy * .025)
      ..rotateY(-.35 + math.sin(t * .21) * .12 + tilt.dx * .035)
      ..rotateZ(-.23 + wake * .025)
      ..scaleByDouble(.80, .80, .80, 1));
    _jade.mutateLocalTransform((matrix) => matrix
      ..setIdentity()
      ..translateByDouble(-1.70 + tilt.dx * .045,
          -.90 + math.sin(t * .42 + 1) * .045 - tilt.dy * .045, -.12, 1)
      ..rotateX(.82 + math.sin(t * .17) * .12 + tilt.dy * .035)
      ..rotateY(.25 + tilt.dx * .035)
      ..rotateZ(t * .035));
    for (var i = 0; i < _dew.length; i++) {
      final phase = i * 2.1;
      _dew[i].position = vm.Vector3(
        i == 0 ? 1.05 : (i == 1 ? -1.42 : 1.8),
        (i == 0 ? 2.02 : (i == 1 ? -.2 : .55)) + math.sin(t * .45 + phase) * .055,
        -.35 + math.cos(t * .22 + phase) * .08,
      );
    }
    for (var i = 0; i < _lenses.length; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final phase = i * 1.8;
      _lenses[i].mutateLocalTransform((matrix) => matrix
        ..setIdentity()
        ..translateByDouble(side * (1.45 + i * .05) + tilt.dx * .06,
          1.50 - i * .78 + math.sin(t * .42 + phase) * .055,
          .2 + math.sin(t * .20 + phase) * .08, 1)
        ..rotateX(.14 + tilt.dy * .05)
        ..rotateY(side * .35 + math.sin(t * .19 + phase) * .12)
        ..rotateZ(side * .12)
        ..scaleByDouble(1.8, .85, .72, 1));
    }
    _swayFerns(t, controller.audioBass);
    _updateMaterials(controller);
    _livingWorld.update(controller);
    scene.renderScale = controller.highQuality ? .85 : .65;
    // All movement uses the shared, bounded gel clock. Explicitly prevent
    // Scene's implicit wall clock from advancing behind paused/reduced UI.
    scene.update(0);
  }

  void _updateMaterials(GeodeSceneController controller) {
    final material = controller.displayMaterial;
    final hue = controller.hue;
    if ((material - _lastMaterial).abs() < .002 && hue == _lastHue) return;
    _lastMaterial = material;
    _lastHue = hue;
    final opal = material.clamp(0.0, 1.0).toDouble();
    final metal = (material - 1).clamp(0.0, 1.0).toDouble();
    var tint = _mix(vm.Vector4(.35, .78, .70, 1), vm.Vector4(.81, .69, .86, 1), opal);
    tint = _mix(tint, vm.Vector4(.73, .85, .87, 1), metal);
    if ((hue - .5).abs() > .005) {
      final shifted = HSVColor.fromAHSV(1, (hue * 360 + 180) % 360, .45, .93).toColor();
      tint = _mix(tint, vm.Vector4(_linear(shifted.r), _linear(shifted.g), _linear(shifted.b), 1), .32);
    }
    _quartz
      ..baseColorFactor = tint
      ..metallicFactor = .03 + metal * .86
      ..roughnessFactor = .13 + opal * .05 - metal * .08
      ..transmission = .32 * (1 - metal)
      ..iridescence = .12 + opal * .15 - metal * .20;
  }

  static vm.Vector4 _mix(vm.Vector4 a, vm.Vector4 b, double t) => a * (1 - t) + b * t;
  static double _linear(double value) => value <= .04045
      ? value / 12.92 : math.pow((value + .055) / 1.055, 2.4).toDouble();

  void dispose() => scene.dispose();
}
