import 'dart:math' as math;

import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;

import 'geode_scene_controller.dart';

/// An opaque moss and jade medallion and seeds sharing one depth buffer.
/// Flutter paints the water below this bounded GPU view.
class PlayerOrbScene {
  PlayerOrbScene._(fs.Texture2D artwork, fs.Texture2D moss, fs.Texture2D emission) {
    _jade..baseColorTexture = moss..emissiveTexture = emission;
    scene
      ..environmentIntensity = .75
      ..exposure = 1.05
      ..directionalLight = fs.DirectionalLight(
        direction: vm.Vector3(.5, -1, .8),
        color: vm.Vector3(1, .93, .78),
        intensity: 1.35,
      );

    final tileMaterial = fs.PhysicallyBasedMaterial(baseColorTexture: artwork)
      ..roughnessFactor = .65
      ..metallicFactor = 0
      ..alphaMode = fs.AlphaMode.mask
      ..alphaCutoff = .05;
    _tile.add(fs.Node(
      name: 'Moss stone record face',
      mesh: fs.Mesh(fs.PlaneGeometry(width: 1.65, depth: 1.65), tileMaterial),
    )..localTransform = (vm.Matrix4.identity()..rotateX(-math.pi / 2)));
    _tile.position = vm.Vector3(0, 0, -.23);
    _medallion.add(fs.Node(
      name: 'Solid river jade',
      mesh: fs.Mesh(fs.SphereGeometry(radius: .94, segments: 48, rings: 28), _jade),
    )..localTransform = (vm.Matrix4.identity()..scaleByDouble(1, 1, .20, 1)));
    _medallion.add(_tile);
    final dropletMesh = fs.Mesh(
      fs.SphereGeometry(radius: .085, segments: 20, rings: 12),
      _seedMaterial,
    );
    for (var i = 0; i < 7; i++) {
      final drop = fs.Node(name: 'Floating seed $i', mesh: dropletMesh);
      _droplets.add(drop);
      scene.add(drop);
    }
    scene.add(_medallion);
  }

  static Future<PlayerOrbScene> create() async {
    await fs.Scene.preload();
    final artwork = await fs.Texture2D.fromAsset(
      'assets/images/stone-dial.png',
      maxSize: 512,
    );
    final moss = await fs.Texture2D.fromAsset('assets/textures/moss.png', maxSize: 512);
    final emission = await fs.Texture2D.fromAsset('assets/textures/bioluminescent-veins.png', maxSize: 512);
    return PlayerOrbScene._(artwork, moss, emission);
  }

  final scene = fs.Scene();
  final camera = fs.PerspectiveCamera(
    position: vm.Vector3(0, .15, -3.6),
    target: vm.Vector3(0, .15, 0),
    fovNear: .2,
    fovFar: 10,
  );
  final _medallion = fs.Node(name: 'Moss and jade music medallion');
  final _tile = fs.Node(name: 'Stone record face');
  final _droplets = <fs.Node>[];
  final _jade = fs.PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(.65, .84, .62, 1)
    ..transmission = .30
    ..thickness = .18
    ..ior = 1.38
    ..emissiveFactor = vm.Vector4(.12, .35, .20, 1)
    ..roughnessFactor = .44
    ..metallicFactor = 0
    ..clearcoat = .14
    ..clearcoatRoughness = .3;
  final _seedMaterial = fs.PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(.19, .14, .065, 1)
    ..roughnessFactor = .72
    ..metallicFactor = 0;

  bool failed = false;

  void update(GeodeSceneController controller, double time, {required bool reducedMotion}) {
    final t = reducedMotion ? 0.0 : time;
    final bob = math.sin(t * .65) * .025;
    final tilt = reducedMotion ? 0.0 : controller.tilt.dx * .055;
    _medallion.mutateLocalTransform((matrix) => matrix
      ..setIdentity()
      ..translateByDouble(tilt, .15 + bob, 0, 1)
      ..rotateX(-.12 + math.sin(t * .21) * .04)
      ..rotateY(-.30 + math.sin(t * .18) * .46 + tilt)
      ..rotateZ(-.16 + math.sin(t * .14) * .07));
    for (var i = 0; i < _droplets.length; i++) {
      _droplets[i].visible = controller.particlesEnabled &&
          i < (controller.particleDensity * _droplets.length).ceil();
      final phase = i * math.pi * 2 / _droplets.length + t * .22;
      final radius = 1.16 + (i % 3) * .045;
      final size = .65 + (i % 3) * .21;
      _droplets[i].mutateLocalTransform((matrix) => matrix
        ..setIdentity()
        ..translateByDouble(
          math.cos(phase) * radius,
          .15 + math.sin(phase) * .40 + math.cos(phase) * .16,
          math.sin(phase) * .70,
          1,
        )
        ..scaleByDouble(size * .75, size * 1.4, size * .60, 1));
    }
    final material = controller.displayMaterial.clamp(0.0, 2.0).toDouble();
    _jade.roughnessFactor = .44 + material * .08;
    final envelope = controller.lightEnvelope;
    _jade.emissiveFactor = vm.Vector4(envelope * .3, envelope, envelope * .65, 1);
    scene.renderScale = controller.highQuality ? .85 : .65;
    // The app owns time; the scene must not create an independent animation.
    scene.update(0);
  }

  void dispose() => scene.dispose();
}
