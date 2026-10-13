import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show HSVColor;
import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;

import 'geode_scene_controller.dart';
import 'nature_geometry.dart';

/// Small, genuinely three-dimensional nature accents rendered by Flutter GPU.
/// The existing fragment shader remains the full-screen environment; this
/// transparent pass adds depth-tested meshes and physically based materials.
class NativeNatureScene {
  NativeNatureScene() {
    scene
      ..environmentIntensity = .85
      ..exposure = 1.05
      ..toneMapping = fs.ToneMappingMode.pbrNeutral
      ..directionalLight = fs.DirectionalLight(
        direction: vm.Vector3(.5, -1, .8),
        color: vm.Vector3(.86, .96, 1),
        intensity: 1.7,
      );
    _buildGeometry();
  }

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
    scene..add(_crystals)..add(_jade);
  }

  void update(GeodeSceneController controller) {
    final t = controller.effectiveReducedMotion ? 0.0 : controller.time;
    final tilt = controller.effectiveReducedMotion ? Offset.zero : controller.tilt;
    final wake = controller.effectiveReducedMotion ? 0.0 : controller.pulse;
    _crystals.updateTransform((matrix) => matrix
      ..setIdentity()
      ..translateByDouble(1.52 + tilt.dx * .05,
          1.28 + math.sin(t * .38) * .035 - tilt.dy * .04, .1, 1)
      ..rotateX(-.13 + tilt.dy * .025)
      ..rotateY(-.35 + math.sin(t * .21) * .12 + tilt.dx * .035)
      ..rotateZ(-.23 + wake * .025)
      ..scaleByDouble(.80, .80, .80, 1));
    _jade.updateTransform((matrix) => matrix
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
    _updateMaterials(controller);
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
