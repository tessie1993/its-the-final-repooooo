import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;

import '../media/music_models.dart';

/// The app's nature palette as physically based materials. Textures load once and
/// are shared by every scene; GPU textures are reclaimed with their last reference.
class GeodeMaterials {
  GeodeMaterials._(this.moss, this.riverStone, this.bark, this.veins, this.stoneDial);

  static Future<GeodeMaterials>? _shared;

  /// Preloads the scene renderer and the four nature textures exactly once.
  static Future<GeodeMaterials> load() => _shared ??= _load().then((value) => value,
    onError: (Object error, StackTrace stack) {
      // A failed load (no Flutter GPU) must not poison later attempts on resume.
      _shared = null;
      return Future<GeodeMaterials>.error(error, stack);
    });

  static Future<GeodeMaterials> _load() async {
    await fs.Scene.preload();
    Future<fs.Texture2D> texture(String name) =>
        fs.Texture2D.fromAsset('assets/textures/$name.png', maxSize: 512);
    final loaded = await Future.wait([texture('moss'), texture('river-stone'), texture('bark'),
      texture('bioluminescent-veins'),
      fs.Texture2D.fromAsset('assets/images/stone-dial.png', maxSize: 512)]);
    return GeodeMaterials._(loaded[0], loaded[1], loaded[2], loaded[3], loaded[4]);
  }

  final fs.Texture2D moss, riverStone, bark, veins, stoneDial;

  /// Moss, river stone and bark, in [MaterialOrb.palettes] order.
  fs.Texture2D surface(int index) => switch (index) { 1 => riverStone, 2 => bark, _ => moss };

  fs.PhysicallyBasedMaterial stone(int index, {double glow = 0}) => fs.PhysicallyBasedMaterial(
    baseColorTexture: surface(index), emissiveTexture: glow > 0 ? veins : null)
    ..roughnessFactor = index == 1 ? .48 : .72
    ..metallicFactor = 0
    ..clearcoat = index == 1 ? .35 : .08
    ..clearcoatRoughness = .35
    ..emissiveFactor = vm.Vector4(.10 * glow, .34 * glow, .24 * glow, 1)
    ..doubleSided = true;

  /// Translucent quartz, tinted toward [tint] (linear RGB).
  static fs.PhysicallyBasedMaterial quartz([vm.Vector4? tint]) => fs.PhysicallyBasedMaterial()
    ..baseColorFactor = tint ?? vm.Vector4(.42, .82, .74, 1)
    ..roughnessFactor = .12
    ..metallicFactor = .03
    ..clearcoat = 1
    ..clearcoatRoughness = .08
    ..transmission = .34
    ..ior = 1.46
    ..thickness = .4
    ..iridescence = .14;

  static fs.PhysicallyBasedMaterial jade() => fs.PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(.05, .26, .19, 1)
    ..roughnessFactor = .26
    ..metallicFactor = .04
    ..clearcoat = 1
    ..clearcoatRoughness = .11
    ..doubleSided = true;

  static fs.PhysicallyBasedMaterial dew() => fs.PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(.67, .94, .89, 1)
    ..roughnessFactor = .06
    ..metallicFactor = .06
    ..transmission = .58
    ..ior = 1.333
    ..thickness = .14
    ..clearcoat = 1;

  /// Leaf tissue: vertex colours from [GeodeMeshes.fern] do the shading.
  static fs.PhysicallyBasedMaterial leaf() => fs.PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(1, 1, 1, 1)
    ..vertexColorWeight = 1
    ..roughnessFactor = .58
    ..metallicFactor = 0
    ..doubleSided = true;

  static fs.PhysicallyBasedMaterial water() => fs.PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(.03, .13, .15, 1)
    ..roughnessFactor = .05
    ..metallicFactor = .1
    ..clearcoat = 1
    ..clearcoatRoughness = .03
    ..doubleSided = true;
}

/// Album artwork as GPU textures, keyed by file path. A small LRU keeps the library
/// carousel, medallion and mini player sharing one upload per cover.
class ArtworkTextures {
  ArtworkTextures._();
  static final instance = ArtworkTextures._();

  static const _capacity = 24;
  // Map literals are insertion-ordered, which the LRU eviction relies on.
  final _cache = <String, Future<fs.Texture2D?>>{};

  /// The cover for [track], or null when it has none or it cannot be decoded
  /// (callers then use [GeodeMaterials.stoneDial]).
  Future<fs.Texture2D?> forTrack(MusicTrack? track) {
    final path = track?.artPath ?? '';
    if (path.isEmpty) return Future.value();
    final cached = _cache.remove(path);
    final future = cached ?? _decode(path);
    _cache[path] = future;
    while (_cache.length > _capacity) {
      _cache.remove(_cache.keys.first);
    }
    return future;
  }

  Future<fs.Texture2D?> _decode(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      await GeodeMaterials.load();
      return await fs.Texture2D.fromEncodedBytes(bytes, maxSize: 512);
    } catch (error) {
      _cache.remove(path);
      if (kDebugMode) debugPrint('Artwork texture unavailable for $path: $error');
      return null;
    }
  }
}
