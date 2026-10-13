import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart' as scene;
import 'package:vector_math/vector_math.dart' as vm;

/// A closed quartz habit with separate face vertices for crisp facet normals.
/// This mesh is uploaded once; only its node transforms change during motion.
scene.MeshGeometry createQuartzGeometry() {
  final positions = <double>[];
  final normals = <double>[];
  final colors = <double>[];

  void triangle(vm.Vector3 a, vm.Vector3 b, vm.Vector3 c, double tint) {
    final normal = (b - a).cross(c - a)..normalize();
    for (final vertex in [a, b, c]) {
      positions.addAll([vertex.x, vertex.y, vertex.z]);
      normals.addAll([normal.x, normal.y, normal.z]);
      colors.addAll([tint, .96 + tint * .04, 1, 1]);
    }
  }

  vm.Vector3 ring(int index, double y, double radius) {
    final angle = index * math.pi / 3;
    return vm.Vector3(math.cos(angle) * radius, y, math.sin(angle) * radius);
  }

  final tip = vm.Vector3(.025, .86, -.015);
  final base = vm.Vector3(0, -.69, 0);
  for (var face = 0; face < 6; face++) {
    final a = ring(face, -.55, .20);
    final b = ring(face + 1, -.55, .20);
    final c = ring(face, .35, .245);
    final d = ring(face + 1, .35, .245);
    final tint = .88 + (face % 3) * .04;
    triangle(a, c, b, tint);
    triangle(b, c, d, tint);
    triangle(c, tip, d, tint);
    triangle(a, b, base, tint);
  }

  return scene.MeshGeometry.fromArrays(
    positions: Float32List.fromList(positions),
    normals: Float32List.fromList(normals),
    colors: Float32List.fromList(colors),
    retainCpuData: false,
  );
}
