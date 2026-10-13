import 'dart:math' as math;

import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;

import '../three_d/geode_materials.dart';
import 'geode_scene_controller.dart';

/// Living organisms built from shared GPU meshes, not animated image frames.
/// The owning scene disposes all nodes; this world has no ticker or audio stream.
class BioluminescentWorld {
  BioluminescentWorld(fs.Scene scene, GeodeMaterials materials) {
    _gel = fs.PhysicallyBasedMaterial(emissiveTexture: materials.veins)
      ..baseColorFactor = vm.Vector4(.075, .42, .29, 1)
      ..roughnessFactor = .21
      ..transmission = .4
      ..thickness = .24
      ..ior = 1.36
      ..clearcoat = .7
      ..clearcoatRoughness = .15
      ..doubleSided = true;
    _gills = fs.PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(.14, .72, .48, 1)
      ..roughnessFactor = .48
      ..doubleSided = true;
    _sporeMaterial = fs.PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(.45, .85, .61, 1)
      ..roughnessFactor = .3;
    final capMesh = fs.Mesh(fs.SphereGeometry(radius: 1, segments: 24, rings: 12), _gel);
    final gillMesh = fs.Mesh(fs.TorusGeometry(radius: .62, tubeRadius: .024,
      radialSegments: 24, tubularSegments: 6), _gills);
    final stemMesh = fs.Mesh(fs.SphereGeometry(radius: 1, segments: 10, rings: 8), _gills);
    // Small colonies anchor the foreground; their centre stays clear for UI.
    for (var i = 0; i < 9; i++) {
      final organism = fs.Node(name: 'Luminous fungus $i');
      organism.add(fs.Node(name: 'Sap cap', mesh: capMesh)
        ..localTransform = (vm.Matrix4.identity()
          ..translateByDouble(0, .65, 0, 1)
          ..scaleByDouble(.65, .24, .65, 1)));
      organism.add(fs.Node(name: 'Gills', mesh: gillMesh)
        ..localTransform = (vm.Matrix4.identity()
          ..translateByDouble(0, .58, 0, 1)
          ..rotateX(math.pi / 2)));
      organism.add(fs.Node(name: 'Stem', mesh: stemMesh)
        ..localTransform = (vm.Matrix4.identity()
          ..translateByDouble(0, .16, 0, 1)
          ..rotateZ(.1)
          ..scaleByDouble(.055, .46, .055, 1)));
      _fungi.add(organism);
      scene.add(organism);
    }
    final sporeMesh = fs.Mesh(fs.SphereGeometry(radius: .018, segments: 8, rings: 6), _sporeMaterial);
    for (var i = 0; i < 24; i++) {
      final node = fs.Node(name: 'Luminous spore $i', mesh: sporeMesh);
      _spores.add(node);
      scene.add(node);
    }
    final seedMesh = fs.Mesh(fs.SphereGeometry(radius: .18, segments: 20, rings: 12), _gel);
    for (var i = 0; i < 3; i++) {
      final seed = fs.Node(name: 'Floating gel seed $i', mesh: seedMesh);
      _seeds.add(seed);
      scene.add(seed);
    }
  }

  late final fs.PhysicallyBasedMaterial _gel, _gills, _sporeMaterial;
  final _fungi = <fs.Node>[];
  final _spores = <fs.Node>[];
  final _seeds = <fs.Node>[];

  void update(GeodeSceneController controller) {
    final still = controller.motionDisabled;
    final t = controller.effectiveReducedMotion ? 0.0 : controller.time;
    final bass = still ? 0.0 : controller.audioBass;
    final light = controller.lightEnvelope;
    final hue = (controller.hue - .5) * math.pi * 2;
    final tint = vm.Vector3(.22 + .12 * math.sin(hue),
      .75 + .18 * math.cos(hue), .6 + .28 * math.sin(hue + .6));
    _gel.emissiveFactor = vm.Vector4(tint.x * light, tint.y * light, tint.z * light, 1);
    _gills.emissiveFactor = vm.Vector4(tint.x * light * .8, tint.y * light * 1.8, tint.z * light * 1.6, 1);
    _sporeMaterial.emissiveFactor = vm.Vector4(.5 * light, 1.6 * light, 1.15 * light, 1);
    for (var i = 0; i < _fungi.length; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final size = .22 + (i % 3) * .1;
      final breathe = 1 + (still ? 0 : math.sin(t * .85 + i) * .025 + bass * .07);
      _fungi[i].mutateLocalTransform((matrix) => matrix
        ..setIdentity()
        ..translateByDouble(side * (1.0 + (i % 5) * .25), -2.18 + (i % 3) * .08, -.45 + (i % 4) * .35, 1)
        ..rotateZ(side * .12 + (still ? 0 : math.sin(t * .4 + i) * .025))
        ..scaleByDouble(size * breathe, size / breathe, size * breathe, 1));
    }
    final count = controller.particlesEnabled
        ? (controller.particleDensity * (controller.highQuality ? 24 : 10)).round() : 0;
    for (var i = 0; i < _spores.length; i++) {
      final phase = i * 2.399963;
      // Use a shared scene clock for freeze/resume and deterministic trajectories.
      final x = math.sin(phase) * 2.25 + math.sin(t * .17 + phase) * .12;
      final y = -2.1 + ((i * .31 + t * .055) % 3.9);
      final z = .3 + math.cos(phase) * .9;
      final scale = i < count ? .65 + (i % 3) * .25 : 0.0;
      _spores[i].mutateLocalTransform((matrix) => matrix
        ..setIdentity()
        ..translateByDouble(x, y, z, 1)
        ..scaleByDouble(scale, scale, scale, 1));
    }
    for (var i = 0; i < _seeds.length; i++) {
      final phase = i * 2.1;
      final side = i.isEven ? -1.0 : 1.0;
      final squash = 1 + math.sin(t * .8 + phase) * .1 + bass * .12;
      _seeds[i].mutateLocalTransform((matrix) => matrix
        ..setIdentity()
        ..translateByDouble(side * (1.2 + i * .2) + controller.tilt.dx * .12,
          .8 - i * .6 + math.sin(t * .4 + phase) * .12,
          -.4 + math.cos(t * .3 + phase) * .18, 1)
        ..rotateZ(math.sin(t * .24 + phase) * .2)
        ..scaleByDouble(squash, 1.25 / squash, .85, 1));
    }
  }
}
