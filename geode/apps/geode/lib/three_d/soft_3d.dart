import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// A small indexed triangle mesh in object space, for the software 3D renderer
/// behind the 3D controls (switches, checkboxes, progress vials, spinners).
///
/// Controls are too small and too numerous for a Flutter GPU scene each, so they are
/// lit and projected with vector_math on the CPU and drawn with one
/// [Canvas.drawVertices] call per mesh: a few hundred triangles, no textures, and
/// it works everywhere a canvas does, including widget tests.
class SoftMesh {
  SoftMesh._(this.positions, this.normals, this.indices);

  /// Object-space positions and unit normals, three floats per vertex.
  final Float32List positions, normals;
  final Uint16List indices;

  int get vertexCount => positions.length ~/ 3;

  /// An ellipsoid with radii [rx] (along x), [ry] and [rz].
  factory SoftMesh.ellipsoid({double rx = 1, double ry = 1, double rz = 1,
      int segments = 18, int rings = 12}) =>
    SoftMesh._lathe([for (var i = 0; i < rings; i++) (math.pi * i / (rings - 1), 0.0)],
      segments: segments, rx: rx, ry: ry, rz: rz);

  /// A capsule along x: a cylinder of [radius] whose cap centres sit at ±[halfLength].
  /// [capDepth] (as a fraction of the radius) flattens the end caps; [depthScale]
  /// squashes the capsule along z.
  factory SoftMesh.capsule({required double halfLength, required double radius,
      double capDepth = 1, double depthScale = 1, int segments = 20, int capRings = 6}) =>
    SoftMesh._lathe([
      for (var i = 0; i <= capRings; i++) (math.pi / 2 * i / capRings, halfLength),
      for (var i = 0; i <= capRings; i++) (math.pi / 2 + math.pi / 2 * i / capRings, -halfLength),
    ], segments: segments, rx: radius * capDepth, ry: radius, rz: radius * depthScale);

  /// A superellipsoid cube with half extent 1. [roundness] near 0 gives sharp edges,
  /// 1 gives a sphere.
  factory SoftMesh.roundedCube({double roundness = .26, int segments = 28, int rings = 16}) {
    double c(double w, double m) { final v = math.cos(w); return v.sign * math.pow(v.abs(), m); }
    double s(double w, double m) { final v = math.sin(w); return v.sign * math.pow(v.abs(), m); }
    final count = segments * rings;
    final positions = Float32List(count * 3), normals = Float32List(count * 3);
    for (var r = 0; r < rings; r++) {
      final eta = -math.pi / 2 + math.pi * r / (rings - 1);
      for (var j = 0; j < segments; j++) {
        final omega = -math.pi + 2 * math.pi * j / segments;
        final k = (r * segments + j) * 3;
        positions
          ..[k] = c(eta, roundness) * c(omega, roundness)
          ..[k + 1] = s(eta, roundness)
          ..[k + 2] = c(eta, roundness) * s(omega, roundness);
        final m = 2 - roundness;
        final nx = c(eta, m) * c(omega, m), ny = s(eta, m), nz = c(eta, m) * s(omega, m);
        final length = math.max(math.sqrt(nx * nx + ny * ny + nz * nz), 1e-6);
        normals..[k] = nx / length..[k + 1] = ny / length..[k + 2] = nz / length;
      }
    }
    return SoftMesh._(positions, normals, _gridIndices(rings, segments));
  }

  /// A surface of revolution around x: each ring is (polar angle from +x, x shift).
  static SoftMesh _lathe(List<(double, double)> rings, {required int segments,
      required double rx, required double ry, required double rz}) {
    final count = rings.length * segments;
    final positions = Float32List(count * 3), normals = Float32List(count * 3);
    for (var r = 0; r < rings.length; r++) {
      final (theta, shift) = rings[r];
      final st = math.sin(theta), ct = math.cos(theta);
      for (var j = 0; j < segments; j++) {
        final phi = 2 * math.pi * j / segments;
        final k = (r * segments + j) * 3;
        positions
          ..[k] = ct * rx + shift
          ..[k + 1] = st * math.cos(phi) * ry
          ..[k + 2] = st * math.sin(phi) * rz;
        // The gradient of the implicit ellipsoid gives its true normal.
        final nx = ct / rx, ny = st * math.cos(phi) / ry, nz = st * math.sin(phi) / rz;
        final length = math.max(math.sqrt(nx * nx + ny * ny + nz * nz), 1e-6);
        normals..[k] = nx / length..[k + 1] = ny / length..[k + 2] = nz / length;
      }
    }
    return SoftMesh._(positions, normals, _gridIndices(rings.length, segments));
  }

  static Uint16List _gridIndices(int rings, int segments) {
    final indices = Uint16List((rings - 1) * segments * 6);
    var n = 0;
    for (var r = 0; r < rings - 1; r++) {
      for (var j = 0; j < segments; j++) {
        final a = r * segments + j, b = r * segments + (j + 1) % segments;
        final c = a + segments, d = b + segments;
        indices..[n++] = a..[n++] = c..[n++] = b..[n++] = b..[n++] = c..[n++] = d;
      }
    }
    return indices;
  }
}

/// How a mesh responds to the renderer's single key light.
class SoftMaterial {
  const SoftMaterial({required this.color, this.ambient = .3, this.diffuse = .8,
    this.specular = .32, this.shininess = 26, this.rim = .16,
    this.rimColor = const Color(0xFFBDF2D2), this.emissive = 0, this.opacity = 1});

  final Color color;
  final double ambient, diffuse, specular, shininess, rim, emissive;
  final Color rimColor;

  /// Overall alpha. Specular highlights add to it, so glass stays visible where it
  /// catches the light.
  final double opacity;
}

/// Projects, lights and draws [SoftMesh]es onto a canvas.
///
/// The camera looks down -z from [distance] (world units; infinity gives an
/// orthographic view) after the view rotation [pitch] (about x; positive looks
/// from above) and [yaw] (about y). One world unit is [unit] logical pixels at
/// z = 0, centred on [center].
class SoftRenderer {
  SoftRenderer({required this.center, required this.unit, this.distance = 8,
    double pitch = 0, double yaw = 0, vm.Vector3? light})
    : view = vm.Matrix4.rotationX(pitch)..rotateY(yaw),
      light = (light ?? vm.Vector3(-.45, .7, .75))..normalize();

  final Offset center;
  final double unit, distance;
  final vm.Matrix4 view;

  /// Direction toward the key light, in view space.
  final vm.Vector3 light;

  static final _halfway = vm.Vector3.zero();
  final _point = vm.Vector3.zero();
  final _normal = vm.Vector3.zero();
  final _combined = vm.Matrix4.zero();

  /// Projects a view-space point to the canvas.
  Offset project(double x, double y, double z) {
    final s = distance.isInfinite ? 1.0 : distance / math.max(distance - z, .05);
    return Offset(center.dx + x * unit * s, center.dy - y * unit * s);
  }

  /// Projects an object-space point under [model]; the view-space depth goes to [depth].
  Offset projectModel(vm.Matrix4 model, double x, double y, double z, {List<double>? depth}) {
    _combined..setFrom(view)..multiply(model);
    _point.setValues(x, y, z);
    _combined.transform3(_point);
    if (depth != null && depth.isNotEmpty) depth[0] = _point.z;
    return project(_point.x, _point.y, _point.z);
  }

  /// The view-space direction of object-space vector ([x], [y], [z]) under [model].
  vm.Vector3 rotateModel(vm.Matrix4 model, double x, double y, double z) {
    _combined..setFrom(view)..multiply(model);
    final out = vm.Vector3(x, y, z);
    _combined.rotate3(out);
    return out..normalize();
  }

  /// Draws [mesh] under [model]. Only faces turned toward the camera are drawn, so a
  /// convex mesh needs no depth sorting. With [inside], the mesh is seen from within:
  /// normals flip and the far wall is drawn, which reads as a hollow carved into the
  /// surface. [tint] overrides the material colour per vertex.
  void drawMesh(Canvas canvas, SoftMesh mesh, vm.Matrix4 model, SoftMaterial material,
      {Color Function(int vertex)? tint, bool inside = false}) {
    final n = mesh.vertexCount;
    if (n == 0 || material.opacity <= 0) return;
    _combined..setFrom(view)..multiply(model);
    final view3 = Float32List(n * 3), normals3 = Float32List(n * 3);
    final screen = Float32List(n * 2);
    final colors = Int32List(n);
    final flip = inside ? -1.0 : 1.0;
    _halfway..setValues(light.x, light.y, light.z + 1)..normalize();
    for (var i = 0; i < n; i++) {
      final k = i * 3;
      _point.setValues(mesh.positions[k], mesh.positions[k + 1], mesh.positions[k + 2]);
      _combined.transform3(_point);
      view3..[k] = _point.x..[k + 1] = _point.y..[k + 2] = _point.z;
      final p = project(_point.x, _point.y, _point.z);
      screen..[i * 2] = p.dx..[i * 2 + 1] = p.dy;
      _normal.setValues(mesh.normals[k] * flip, mesh.normals[k + 1] * flip, mesh.normals[k + 2] * flip);
      _combined.rotate3(_normal);
      _normal.normalize();
      normals3..[k] = _normal.x..[k + 1] = _normal.y..[k + 2] = _normal.z;
      colors[i] = _shade(tint?.call(i) ?? material.color, material, _normal);
    }
    final source = mesh.indices;
    final visible = Uint16List(source.length);
    var count = 0;
    for (var t = 0; t < source.length; t += 3) {
      final a = source[t] * 3, b = source[t + 1] * 3, c = source[t + 2] * 3;
      final e1x = view3[b] - view3[a], e1y = view3[b + 1] - view3[a + 1], e1z = view3[b + 2] - view3[a + 2];
      final e2x = view3[c] - view3[a], e2y = view3[c + 1] - view3[a + 1], e2z = view3[c + 2] - view3[a + 2];
      var fx = e1y * e2z - e1z * e2y, fy = e1z * e2x - e1x * e2z, fz = e1x * e2y - e1y * e2x;
      if (fx * fx + fy * fy + fz * fz < 1e-14) continue;
      // Orient the face by its (already flipped) vertex normals, so winding never matters.
      final sx = normals3[a] + normals3[b] + normals3[c];
      final sy = normals3[a + 1] + normals3[b + 1] + normals3[c + 1];
      final sz = normals3[a + 2] + normals3[b + 2] + normals3[c + 2];
      if (fx * sx + fy * sy + fz * sz < 0) { fx = -fx; fy = -fy; fz = -fz; }
      final double toEye;
      if (distance.isInfinite) {
        toEye = fz;
      } else {
        toEye = -fx * view3[a] - fy * view3[a + 1] + fz * (distance - view3[a + 2]);
      }
      if (toEye <= 0) continue;
      visible..[count++] = source[t]..[count++] = source[t + 1]..[count++] = source[t + 2];
    }
    if (count == 0) return;
    final vertices = ui.Vertices.raw(ui.VertexMode.triangles, screen,
      colors: colors, indices: Uint16List.sublistView(visible, 0, count));
    canvas.drawVertices(vertices, BlendMode.dst, Paint());
    vertices.dispose();
  }

  int _shade(Color base, SoftMaterial m, vm.Vector3 normal) {
    final diffuse = math.max(0.0, normal.dot(light));
    final specular = math.pow(math.max(0.0, normal.dot(_halfway)), m.shininess) * m.specular;
    final rim = math.pow(1 - math.max(0.0, normal.z), 3) * m.rim;
    final light01 = m.ambient + m.diffuse * diffuse + m.emissive;
    int channel(double c, double rimC) =>
      ((c * light01 + specular + rimC * rim) * 255).round().clamp(0, 255);
    final alpha = ((base.a * m.opacity + specular * .6) * 255).round().clamp(0, 255);
    return alpha << 24 | channel(base.r, m.rimColor.r) << 16 |
      channel(base.g, m.rimColor.g) << 8 | channel(base.b, m.rimColor.b);
  }
}
