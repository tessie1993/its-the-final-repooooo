import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;

/// Procedural nature geometry shared by every 3D surface. Each builder uploads once;
/// callers reuse the returned geometry across nodes and only change transforms.
abstract final class GeodeMeshes {
  /// A water-worn river pebble: a flattened sphere with low-frequency lumps, smooth
  /// normals and spherical UVs so moss / stone / bark textures wrap it.
  static fs.MeshGeometry pebble({int seed = 7, double lumpiness = .07, int segments = 40, int rings = 24}) {
    final random = math.Random(seed);
    final waves = [
      for (var i = 0; i < 4; i++)
        (vm.Vector3(random.nextDouble() - .5, random.nextDouble() - .5, random.nextDouble() - .5)..normalize(),
          1.5 + random.nextDouble() * 2.5, random.nextDouble() * math.pi * 2),
    ];
    double radius(vm.Vector3 direction) {
      var r = 1.0;
      for (final (axis, frequency, phase) in waves) {
        r += math.sin(direction.dot(axis) * frequency + phase) * lumpiness / waves.length * 2;
      }
      return r;
    }
    return _deformedSphere(segments, rings, radius, vm.Vector3(1, .62, .86));
  }

  /// A faceted river-stone disc: the record face of the player medallion and the
  /// stone dial fallback artwork. Top face carries planar UVs for artwork.
  static fs.MeshGeometry dial({double radius = 1, double thickness = .16, int segments = 64}) {
    final positions = <double>[], normals = <double>[], uvs = <double>[];
    final indices = <int>[];
    int vertex(vm.Vector3 p, vm.Vector3 n, double u, double v) {
      positions.addAll([p.x, p.y, p.z]);
      normals.addAll([n.x, n.y, n.z]);
      uvs.addAll([u, v]);
      return positions.length ~/ 3 - 1;
    }
    final half = thickness / 2;
    // Front (toward -z, the camera side) and back faces, each a fan around a centre.
    for (final front in [true, false]) {
      final z = front ? -half : half;
      final normal = vm.Vector3(0, 0, front ? -1 : 1);
      final centre = vertex(vm.Vector3(0, 0, z), normal, .5, .5);
      final ring = <int>[];
      for (var i = 0; i <= segments; i++) {
        final a = i * math.pi * 2 / segments;
        final x = math.cos(a), y = math.sin(a);
        // Artwork reads upright and unmirrored from the camera at -z.
        ring.add(vertex(vm.Vector3(x * radius, y * radius, z), normal, .5 - x * .5, .5 - y * .5));
      }
      for (var i = 0; i < segments; i++) {
        indices.addAll(front ? [centre, ring[i + 1], ring[i]] : [centre, ring[i], ring[i + 1]]);
      }
    }
    // Rounded rim.
    for (var i = 0; i < segments; i++) {
      final a0 = i * math.pi * 2 / segments, a1 = (i + 1) * math.pi * 2 / segments;
      final n0 = vm.Vector3(math.cos(a0), math.sin(a0), 0), n1 = vm.Vector3(math.cos(a1), math.sin(a1), 0);
      final a = vertex(n0 * radius + vm.Vector3(0, 0, -half), n0, i / segments, 0);
      final b = vertex(n1 * radius + vm.Vector3(0, 0, -half), n1, (i + 1) / segments, 0);
      final c = vertex(n0 * radius + vm.Vector3(0, 0, half), n0, i / segments, 1);
      final d = vertex(n1 * radius + vm.Vector3(0, 0, half), n1, (i + 1) / segments, 1);
      indices.addAll([a, b, c, b, d, c]);
    }
    return _geometry(positions, normals, uvs, indices);
  }

  /// A thick rounded slab for album tiles: the front face (toward -z) has 0..1 UVs for
  /// artwork; the edges share the stone material.
  static fs.MeshGeometry slab({double width = 1, double height = 1, double depth = .08}) =>
      fs.CuboidGeometry(vm.Vector3(width, height, depth));

  /// The front face of an album slab, sized to sit just proud of [slab].
  static fs.MeshGeometry slabFace({double width = 1, double height = 1}) {
    final w = width / 2, h = height / 2;
    final normal = vm.Vector3(0, 0, -1);
    final positions = <double>[], normals = <double>[], uvs = <double>[];
    for (final (x, y, u, v) in [(-w, -h, 0.0, 1.0), (w, -h, 1.0, 1.0), (w, h, 1.0, 0.0), (-w, h, 0.0, 0.0)]) {
      positions.addAll([x, y, 0]);
      normals.addAll([normal.x, normal.y, normal.z]);
      uvs.addAll([u, v]);
    }
    return _geometry(positions, normals, uvs, [0, 2, 1, 0, 3, 2]);
  }

  /// A curled fern frond: a tapering stem with alternating leaflets that fold
  /// slightly upward. Vertex colours shade from young tip to dark base.
  static fs.MeshGeometry fern({int leaflets = 14, double length = 1.6, double curl = .55}) {
    final positions = <double>[], normals = <double>[], uvs = <double>[], colors = <double>[];
    final indices = <int>[];
    int vertex(vm.Vector3 p, vm.Vector3 n, double t) {
      positions.addAll([p.x, p.y, p.z]);
      normals.addAll([n.x, n.y, n.z]);
      uvs.addAll([t, 0]);
      colors.addAll([.30 + t * .30, .48 + t * .28, .22 + t * .10, 1]);
      return positions.length ~/ 3 - 1;
    }
    vm.Vector3 spine(double t) {
      final angle = t * curl;
      return vm.Vector3(math.sin(angle) * length * .35, t * length - length / 2, -math.sin(t * math.pi) * .12);
    }
    final up = vm.Vector3(0, 0, -1);
    // Stem ribbon.
    const stemSteps = 16;
    for (var i = 0; i < stemSteps; i++) {
      final t0 = i / stemSteps, t1 = (i + 1) / stemSteps;
      final w0 = .022 * (1 - t0 * .7), w1 = .022 * (1 - t1 * .7);
      final a = vertex(spine(t0) + vm.Vector3(-w0, 0, 0), up, t0);
      final b = vertex(spine(t0) + vm.Vector3(w0, 0, 0), up, t0);
      final c = vertex(spine(t1) + vm.Vector3(-w1, 0, 0), up, t1);
      final d = vertex(spine(t1) + vm.Vector3(w1, 0, 0), up, t1);
      indices.addAll([a, c, b, b, c, d]);
    }
    // Leaflets: two triangles each, tilted out of the frond plane for depth.
    for (var i = 0; i < leaflets; i++) {
      final t = (i + .5) / leaflets;
      final base = spine(t);
      final size = math.sin((t * .88 + .1) * math.pi) * length * .26 + .03;
      for (final side in [-1.0, 1.0]) {
        final tip = base + vm.Vector3(side * size, size * .55, -size * .25);
        final shoulder = base + vm.Vector3(side * size * .45, size * .42, -size * .05);
        final heel = base + vm.Vector3(side * size * .40, -size * .02, -size * .16);
        final normal = (shoulder - base).cross(tip - base)..normalize();
        if (normal.z > 0) normal.negate();
        final b = vertex(base, normal, t), s = vertex(shoulder, normal, t);
        final p = vertex(tip, normal, t), h = vertex(heel, normal, t);
        indices.addAll([b, s, p, b, p, h]);
      }
    }
    return _geometry(positions, normals, uvs, indices, colors: colors);
  }

  static fs.MeshGeometry _deformedSphere(int segments, int rings,
      double Function(vm.Vector3 direction) radius, vm.Vector3 scale) {
    final columns = segments + 1;
    final points = <vm.Vector3>[];
    final uvs = <double>[];
    for (var r = 0; r <= rings; r++) {
      final polar = r * math.pi / rings;
      for (var s = 0; s <= segments; s++) {
        final azimuth = s * math.pi * 2 / segments;
        final direction = vm.Vector3(math.sin(polar) * math.cos(azimuth), math.cos(polar),
          math.sin(polar) * math.sin(azimuth));
        final p = direction * radius(direction);
        points.add(vm.Vector3(p.x * scale.x, p.y * scale.y, p.z * scale.z));
        uvs.addAll([s / segments, r / rings]);
      }
    }
    final indices = <int>[];
    for (var r = 0; r < rings; r++) {
      for (var s = 0; s < segments; s++) {
        final a = r * columns + s, b = a + 1, c = a + columns, d = c + 1;
        indices.addAll([a, b, c, b, d, c]);
      }
    }
    // Smooth normals: area-weighted face normals accumulated per vertex, then the
    // UV seam column is averaged with its twin so lighting has no visible crease.
    final accumulated = List.generate(points.length, (_) => vm.Vector3.zero());
    for (var i = 0; i < indices.length; i += 3) {
      final a = points[indices[i]], b = points[indices[i + 1]], c = points[indices[i + 2]];
      final face = (b - a).cross(c - a);
      accumulated[indices[i]].add(face);
      accumulated[indices[i + 1]].add(face);
      accumulated[indices[i + 2]].add(face);
    }
    for (var r = 0; r <= rings; r++) {
      final first = r * columns, last = first + segments;
      final sum = accumulated[first] + accumulated[last];
      accumulated[first].setFrom(sum);
      accumulated[last].setFrom(sum);
    }
    final positions = <double>[], normals = <double>[];
    for (var i = 0; i < points.length; i++) {
      final n = accumulated[i];
      if (n.length2 < 1e-12) {
        n.setFrom(points[i]);
      }
      n.normalize();
      // Faces wind toward the outside; flip any normal that ended up inward.
      if (n.dot(points[i]) < 0) n.negate();
      positions.addAll([points[i].x, points[i].y, points[i].z]);
      normals.addAll([n.x, n.y, n.z]);
    }
    return _geometry(positions, normals, uvs, indices);
  }

  static fs.MeshGeometry _geometry(List<double> positions, List<double> normals, List<double> uvs,
      List<int> indices, {List<double>? colors}) => fs.MeshGeometry.fromArrays(
    positions: Float32List.fromList(positions),
    normals: Float32List.fromList(normals),
    texCoords: Float32List.fromList(uvs),
    colors: colors == null ? null : Float32List.fromList(colors),
    indices: indices,
    retainCpuData: false,
  );
}
