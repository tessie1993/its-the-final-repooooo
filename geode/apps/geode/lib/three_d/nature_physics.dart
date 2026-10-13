import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;

/// A circular pool surface simulated with the discrete 2D wave equation on a height
/// grid. Disturbances (touches, beats, falling drops) spread as interfering ripples,
/// reflect softly off the rim and decay. The mesh is updated in place and the
/// simulation sleeps once the surface is calm, so an idle pool costs nothing.
class WaterSurface {
  WaterSurface({this.radius = 3.2, this.resolution = 56, this.amplitude = .16})
    : _cell = radius * 2 / (resolution - 1) {
    final n = resolution;
    _height = Float32List(n * n);
    _previous = Float32List(n * n);
    _next = Float32List(n * n);
    _inside = Uint8List(n * n);
    _positions = Float32List(n * n * 3);
    _normals = Float32List(n * n * 3);
    final uvs = Float32List(n * n * 2);
    final indices = <int>[];
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        final k = j * n + i;
        final x = -radius + i * _cell, z = -radius + j * _cell;
        _inside[k] = x * x + z * z < radius * radius * .98 ? 1 : 0;
        _positions..[k * 3] = x..[k * 3 + 1] = 0..[k * 3 + 2] = z;
        _normals[k * 3 + 1] = 1;
        uvs..[k * 2] = i / (n - 1)..[k * 2 + 1] = j / (n - 1);
      }
    }
    // Only quads whose centre lies in the disc, so the grid reads as a round pool.
    for (var j = 0; j < n - 1; j++) {
      for (var i = 0; i < n - 1; i++) {
        final cx = -radius + (i + .5) * _cell, cz = -radius + (j + .5) * _cell;
        if (cx * cx + cz * cz > radius * radius) continue;
        final a = j * n + i, b = a + 1, c = a + n, d = c + 1;
        indices.addAll([a, c, b, b, c, d]);
      }
    }
    geometry = fs.MeshGeometry.fromArrays(
      positions: Float32List.fromList(_positions),
      normals: Float32List.fromList(_normals),
      texCoords: uvs,
      indices: indices,
      storage: fs.GeometryStorage.updatable,
    );
  }

  final double radius;
  final int resolution;

  /// World-space height of a unit disturbance.
  final double amplitude;
  final double _cell;
  late final fs.MeshGeometry geometry;
  late Float32List _height, _previous, _next;
  late final Uint8List _inside;
  late final Float32List _positions, _normals;
  double _accumulator = 0;
  double _energy = 0;

  /// True while ripples are still travelling; false once the pool is flat.
  bool get active => _energy > 1e-5;

  /// Drops a Gaussian dent of [strength] at pool-local ([x], [z]).
  void disturb(double x, double z, double strength, {double spread = .32}) {
    final n = resolution;
    final ci = ((x + radius) / _cell).round(), cj = ((z + radius) / _cell).round();
    final reach = (spread * 2.5 / _cell).ceil();
    for (var j = math.max(1, cj - reach); j <= math.min(n - 2, cj + reach); j++) {
      for (var i = math.max(1, ci - reach); i <= math.min(n - 2, ci + reach); i++) {
        final k = j * n + i;
        if (_inside[k] == 0) continue;
        final dx = (i - ci) * _cell, dz = (j - cj) * _cell;
        _height[k] -= strength * math.exp(-(dx * dx + dz * dz) / (2 * spread * spread));
      }
    }
    _energy = math.max(_energy, strength.abs());
  }

  /// Surface height (world units) at pool-local ([x], [z]), bilinearly sampled.
  double heightAt(double x, double z) {
    final n = resolution;
    final fx = ((x + radius) / _cell).clamp(0.0, n - 1.001), fz = ((z + radius) / _cell).clamp(0.0, n - 1.001);
    final i = fx.floor(), j = fz.floor();
    final tx = fx - i, tz = fz - j;
    double h(int a, int b) => _height[b * n + a];
    final top = h(i, j) * (1 - tx) + h(i + 1, j) * tx;
    final bottom = h(i, j + 1) * (1 - tx) + h(i + 1, j + 1) * tx;
    return (top * (1 - tz) + bottom * tz) * amplitude;
  }

  /// Surface slope at ([x], [z]) as (d height/dx, d height/dz).
  (double, double) slopeAt(double x, double z) {
    const e = .08;
    return ((heightAt(x + e, z) - heightAt(x - e, z)) / (2 * e),
      (heightAt(x, z + e) - heightAt(x, z - e)) / (2 * e));
  }

  /// Advances the simulation in fixed 1/60 s steps (at most four per frame, so a
  /// stalled frame never triggers a catch-up spiral) and uploads the new surface.
  void step(double dt) {
    if (!active) return;
    _accumulator = math.min(_accumulator + dt, 4 / 60);
    var stepped = false;
    while (_accumulator >= 1 / 60) {
      _accumulator -= 1 / 60;
      _solve();
      stepped = true;
    }
    if (stepped) _upload();
  }

  void _solve() {
    final n = resolution;
    var energy = 0.0;
    for (var j = 1; j < n - 1; j++) {
      for (var i = 1; i < n - 1; i++) {
        final k = j * n + i;
        if (_inside[k] == 0) {
          _next[k] = 0;
          continue;
        }
        // Discrete wave equation at Courant number 1/sqrt(2), with mild damping.
        final value = (_height[k - 1] + _height[k + 1] + _height[k - n] + _height[k + n]) * .5 - _previous[k];
        final damped = value * .985;
        _next[k] = damped;
        energy = math.max(energy, damped.abs());
      }
    }
    final recycled = _previous;
    _previous = _height;
    _height = _next;
    _next = recycled;
    _energy = energy;
    if (!active) {
      _height.fillRange(0, _height.length, 0);
      _previous.fillRange(0, _previous.length, 0);
    }
  }

  void _upload() {
    final n = resolution;
    final scale = amplitude / (2 * _cell);
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        final k = j * n + i;
        _positions[k * 3 + 1] = _height[k] * amplitude;
        final left = i > 0 ? _height[k - 1] : _height[k], right = i < n - 1 ? _height[k + 1] : _height[k];
        final down = j > 0 ? _height[k - n] : _height[k], up = j < n - 1 ? _height[k + n] : _height[k];
        final nx = -(right - left) * scale, nz = -(up - down) * scale;
        final length = math.sqrt(nx * nx + 1 + nz * nz);
        _normals..[k * 3] = nx / length..[k * 3 + 1] = 1 / length..[k * 3 + 2] = nz / length;
      }
    }
    geometry
      ..updatePositions(_positions)
      ..updateNormals(_normals);
  }
}

/// A round, soft-edged dot for sprite particles (dew, pollen, spray).
fs.Texture2D softDotTexture({int size = 32}) {
  final pixels = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = (x + .5) / size * 2 - 1, dy = (y + .5) / size * 2 - 1;
      final falloff = (1 - math.sqrt(dx * dx + dy * dy)).clamp(0.0, 1.0);
      final k = (y * size + x) * 4;
      pixels..[k] = 255..[k + 1] = 255..[k + 2] = 255..[k + 3] = (falloff * falloff * 255).round();
    }
  }
  return fs.Texture2D.fromPixels(pixels, size, size);
}

/// Particle physics for the world: drifting pollen and fireflies carried by curl-like
/// turbulence, and pooled splash emitters whose droplets arc under gravity and drag
/// when the water is touched or the music hits a beat.
class NatureParticles {
  NatureParticles(fs.Texture2D dot) {
    final glow = fs.SpriteMaterial(colorTexture: dot)..blendMode = fs.SpriteBlendMode.additive;
    final drops = fs.SpriteMaterial(colorTexture: dot)..blendMode = fs.SpriteBlendMode.additive;
    pollen = fs.ParticleSystem(
      maxParticles: 140,
      shape: fs.BoxEmitterShape(halfExtents: vm.Vector3(3.2, 1.6, 1.6)),
      spawner: fs.Spawner(rate: 14),
      lifetime: const fs.UniformFloat(6, 10),
      startSpeed: const fs.UniformFloat(.02, .12),
      startSize: const fs.UniformFloat(.025, .065),
      startColor: fs.UniformColor(vm.Vector4(.55, .95, .62, .8), vm.Vector4(1, .92, .55, .9)),
      gravity: vm.Vector3(0, .04, 0),
      modules: [
        fs.TurbulenceModule(strength: .35, frequency: .55, scroll: vm.Vector3(.05, .02, 0)),
        fs.LinearDragModule(.6),
        fs.SizeOverLifeModule(fs.CurveFloat(fs.ParticleCurve(const [
          fs.ParticleKeyframe(0, 0), fs.ParticleKeyframe(.15, 1), fs.ParticleKeyframe(.8, 1), fs.ParticleKeyframe(1, 0),
        ]))),
      ],
      prewarm: 4,
      seed: 11,
    );
    pollenNode = fs.Node(name: 'Pollen and fireflies')
      ..addComponent(fs.ParticleEmitterComponent(system: pollen, material: glow));
    for (var i = 0; i < _splashCount; i++) {
      final system = fs.ParticleSystem(
        maxParticles: 90,
        shape: const fs.ConeEmitterShape(angle: .55, radius: .08),
        spawner: fs.Spawner(),
        lifetime: const fs.UniformFloat(.45, .9),
        startSpeed: const fs.UniformFloat(1.1, 2.3),
        startSize: const fs.UniformFloat(.022, .05),
        startColor: fs.UniformColor(vm.Vector4(.70, .92, 1, .9), vm.Vector4(.85, 1, .95, 1)),
        gravity: vm.Vector3(0, -5.2, 0),
        modules: [
          fs.LinearDragModule(.8),
          fs.SizeOverLifeModule(fs.CurveFloat(fs.ParticleCurve(const [
            fs.ParticleKeyframe(0, 1), fs.ParticleKeyframe(1, .3)]))),
        ],
        seed: 100 + i,
      );
      _splashes.add(system);
      final node = fs.Node(name: 'Splash $i')
        ..addComponent(fs.ParticleEmitterComponent(system: system, material: drops));
      _splashNodes.add(node);
    }
  }

  static const _splashCount = 4;
  late final fs.ParticleSystem pollen;
  late final fs.Node pollenNode;
  final _splashes = <fs.ParticleSystem>[];
  final _splashNodes = <fs.Node>[];
  final _splashTimers = List<double>.filled(_splashCount, 0);
  int _nextSplash = 0;

  List<fs.Node> get splashNodes => List.unmodifiable(_splashNodes);

  /// Fires a burst of about [count] droplets from world point [at].
  void splash(vm.Vector3 at, {int count = 40}) {
    final i = _nextSplash;
    _nextSplash = (_nextSplash + 1) % _splashCount;
    _splashNodes[i].position = at;
    // A short, high emission rate makes a burst without per-call allocation.
    const window = .06;
    _splashes[i].spawner.rate = count / window;
    _splashTimers[i] = window;
  }

  /// Steps every system by [dt]; [density] (0..1) scales the ambient pollen.
  bool step(double dt, {required double density}) {
    pollen.spawner.rate = 14 * density.clamp(0.0, 1.0);
    pollen.step(dt);
    var busy = pollen.storage.aliveCount > 0;
    for (var i = 0; i < _splashCount; i++) {
      if (_splashTimers[i] > 0) {
        _splashTimers[i] -= dt;
        if (_splashTimers[i] <= 0) _splashes[i].spawner.rate = 0;
      }
      _splashes[i].step(dt);
      busy = busy || _splashes[i].storage.aliveCount > 0;
    }
    return busy;
  }
}
