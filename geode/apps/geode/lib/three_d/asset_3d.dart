import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;

import '../scene/nature_geometry.dart';
import 'geode_materials.dart';
import 'geode_meshes.dart';
import 'scene_view.dart';
import 'three_d_support.dart';

/// Every decorative asset in the app, modelled in 3D.
enum Geode3DAsset {
  /// The app mark: a dew drop resting on a fern frond (was fern-dew.png).
  fernDew,
  /// A quartz cluster growing among ferns (was crystal-fern.png).
  crystalFern,
  /// A woodland pool diorama with stones, quartz and fern (was forest-sanctuary.png).
  forestSanctuary,
  /// The carved river-stone record face (was stone-dial.png).
  stoneDial,
  /// A river pebble wrapped in moss, river stone or bark (MaterialOrb).
  pebble,
  /// A lone curled fern frond (FernSprig).
  fernSprig,
}

/// Geometry shared by every asset scene; created on first use, after the scene
/// renderer has been preloaded by [GeodeMaterials.load].
abstract final class _Meshes {
  static final pebble = GeodeMeshes.pebble();
  static final pebbleSmall = GeodeMeshes.pebble(seed: 21, segments: 24, rings: 14);
  static final dial = GeodeMeshes.dial();
  static final fern = GeodeMeshes.fern();
  static final quartz = createQuartzGeometry();
  static final drop = fs.SphereGeometry(radius: .2, segments: 24, rings: 16);
  static final pool = fs.DiscGeometry(radius: 1.5, segments: 48);
}

/// A 3D model of [asset] that fills its box. Static unless [spin] is set and motion
/// is allowed; shows [fallback] (the original 2D artwork) in flat mode.
class Asset3D extends StatelessWidget {
  const Asset3D({
    super.key,
    required this.asset,
    required this.fallback,
    this.variant = 0,
    this.spin = false,
    this.semanticsLabel,
  });

  final Geode3DAsset asset;
  final Widget fallback;

  /// Material index for [Geode3DAsset.pebble] (moss, river stone, bark).
  final int variant;
  final bool spin;
  final String? semanticsLabel;

  /// A drop-in for an `Image.asset` of [asset]: the model in a [width] x [height] box,
  /// with the original image as the flat fallback.
  static Widget boxed({Key? key, required Geode3DAsset asset, required Widget fallback,
      double? width, double? height, int variant = 0, bool spin = false, String? semanticsLabel}) =>
    SizedBox(key: key, width: width, height: height, child: Asset3D(asset: asset, fallback: fallback,
      variant: variant, spin: spin, semanticsLabel: semanticsLabel));

  @override
  Widget build(BuildContext context) {
    final mode = threeDModeIn(context);
    if (spin && mode == ThreeDMode.live) {
      return ThreeDView<_AssetScene>(
        key: ValueKey((asset, variant)),
        mode: mode,
        create: () async => _AssetScene(asset, variant, spin, await GeodeMaterials.load()),
        fallback: fallback,
        semanticsLabel: semanticsLabel,
        pixelRatio: threeDPixelRatioIn(context),
      );
    }
    if (mode == ThreeDMode.flat) return fallback;
    // Still models render once per size and share the image across every copy.
    return LayoutBuilder(builder: (context, constraints) {
      if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) return fallback;
      final size = constraints.biggest;
      if (size.isEmpty) return const SizedBox.shrink();
      final image = _StillAsset(asset: asset, variant: variant, size: size,
        pixelRatio: threeDPixelRatioIn(context), fallback: fallback);
      final label = semanticsLabel;
      return label == null ? ExcludeSemantics(child: image) : Semantics(image: true, label: label, child: image);
    });
  }
}

/// Rendered stills keyed by asset, variant and pixel size. The cache owns each image;
/// widgets hold clones, so eviction never disposes an image that is still on screen.
abstract final class _Stills {
  static const _capacity = 40;
  static final _cache = <(Geode3DAsset, int, int, int), Future<ui.Image?>>{};

  static Future<ui.Image?> obtain(Geode3DAsset asset, int variant, Size size, double ratio) {
    final width = (size.width * ratio).round().clamp(1, 1024);
    final height = (size.height * ratio).round().clamp(1, 1024);
    final key = (asset, variant, width, height);
    final cached = _cache.remove(key);
    final future = cached ?? _render(asset, variant, width, height);
    _cache[key] = future;
    while (_cache.length > _capacity) {
      final evicted = _cache.remove(_cache.keys.first);
      unawaited(evicted?.then((image) => image?.dispose()));
    }
    return future;
  }

  static Future<ui.Image?> _render(Geode3DAsset asset, int variant, int width, int height) async {
    _AssetScene? model;
    try {
      model = _AssetScene(asset, variant, false, await GeodeMaterials.load());
      model.advance(0, live: false);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      model.scene.render(model.camera, canvas,
        viewport: ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), pixelRatio: 1);
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(width, height);
      } finally {
        picture.dispose();
      }
    } catch (error) {
      if (kDebugMode) debugPrint('3D still for $asset unavailable: $error');
      return null;
    } finally {
      model?.dispose();
    }
  }
}

class _StillAsset extends StatefulWidget {
  const _StillAsset({required this.asset, required this.variant, required this.size,
    required this.pixelRatio, required this.fallback});
  final Geode3DAsset asset;
  final int variant;
  final Size size;
  final double pixelRatio;
  final Widget fallback;
  @override
  State<_StillAsset> createState() => _StillAssetState();
}

class _StillAssetState extends State<_StillAsset> {
  ui.Image? _image;
  bool _failed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_StillAsset old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset || old.variant != widget.variant ||
        old.size != widget.size || old.pixelRatio != widget.pixelRatio) {
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    final image = await _Stills.obtain(widget.asset, widget.variant, widget.size, widget.pixelRatio);
    if (!mounted || request != _request) return;
    setState(() {
      _image?.dispose();
      _image = image?.clone();
      _failed = image == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return _failed ? widget.fallback : const SizedBox.expand();
    return RawImage(image: image, width: widget.size.width, height: widget.size.height,
      fit: BoxFit.contain, filterQuality: FilterQuality.medium);
  }

  @override
  void dispose() {
    _request++;
    _image?.dispose();
    super.dispose();
  }
}

class _AssetScene extends ThreeDScene {
  _AssetScene(this.asset, int variant, this.spin, GeodeMaterials materials) {
    scene
      ..environmentIntensity = .9
      ..exposure = 1.08
      ..toneMapping = fs.ToneMappingMode.pbrNeutral
      ..directionalLight = fs.DirectionalLight(
        direction: vm.Vector3(.45, -1, .7), color: vm.Vector3(1, .95, .84), intensity: 1.6);
    _build(materials, variant);
    scene.add(_root);
    _pose(0);
  }

  final Geode3DAsset asset;
  final bool spin;
  final _root = fs.Node(name: 'Asset');
  double _time = 0;

  @override
  final scene = fs.Scene();

  @override
  late final fs.PerspectiveCamera camera = switch (asset) {
    Geode3DAsset.forestSanctuary => fs.PerspectiveCamera(position: vm.Vector3(0, 1.6, -3.4),
      target: vm.Vector3(0, -.2, 0), fovNear: .2, fovFar: 12),
    Geode3DAsset.stoneDial => fs.PerspectiveCamera(position: vm.Vector3(0, 0, -2.9),
      target: vm.Vector3.zero(), fovNear: .2, fovFar: 10),
    _ => fs.PerspectiveCamera(position: vm.Vector3(0, .1, -3.2),
      target: vm.Vector3(0, 0, 0), fovNear: .2, fovFar: 10),
  };

  void _build(GeodeMaterials materials, int variant) {
    fs.Node node(String name, fs.MeshGeometry geometry, fs.Material material,
        {vm.Vector3? at, vm.Vector3? scale, double rx = 0, double ry = 0, double rz = 0}) =>
      fs.Node(name: name, mesh: fs.Mesh(geometry, material))
        ..localTransform = (vm.Matrix4.identity()
          ..translateByVector3(at ?? vm.Vector3.zero())
          ..rotateY(ry)..rotateX(rx)..rotateZ(rz)
          ..scaleByVector3(scale ?? vm.Vector3.all(1)));
    final leaf = GeodeMaterials.leaf();
    switch (asset) {
      case Geode3DAsset.fernDew:
        _root
          ..add(node('Fern', _Meshes.fern, leaf, rz: -.35, scale: vm.Vector3.all(1.15)))
          ..add(node('Dew drop', _Meshes.drop, GeodeMaterials.dew(), at: vm.Vector3(.38, .42, -.22),
            scale: vm.Vector3(1, 1.15, 1)));
      case Geode3DAsset.crystalFern:
        final quartz = GeodeMaterials.quartz();
        _root
          ..add(node('Quartz', _Meshes.quartz, quartz, scale: vm.Vector3.all(1.25)))
          ..add(node('Quartz left', _Meshes.quartz, quartz, at: vm.Vector3(-.36, -.30, .05),
            rz: .42, scale: vm.Vector3.all(.75)))
          ..add(node('Quartz right', _Meshes.quartz, quartz, at: vm.Vector3(.34, -.34, -.05),
            rz: -.36, scale: vm.Vector3.all(.62)))
          ..add(node('Fern left', _Meshes.fern, leaf, at: vm.Vector3(-.55, -.2, .2), rz: .5,
            scale: vm.Vector3.all(.8)))
          ..add(node('Fern right', _Meshes.fern, leaf, at: vm.Vector3(.6, -.25, .25), rz: -.6,
            ry: math.pi, scale: vm.Vector3.all(.7)));
      case Geode3DAsset.forestSanctuary:
        _root
          ..add(node('Pool', _Meshes.pool, GeodeMaterials.water(), at: vm.Vector3(0, -.62, 0)))
          ..add(node('Moss stone', _Meshes.pebble, materials.stone(0), at: vm.Vector3(-.75, -.48, .25),
            scale: vm.Vector3.all(.42)))
          ..add(node('River stone', _Meshes.pebbleSmall, materials.stone(1), at: vm.Vector3(.55, -.52, -.25),
            scale: vm.Vector3.all(.3)))
          ..add(node('Bark stone', _Meshes.pebbleSmall, materials.stone(2), at: vm.Vector3(.95, -.5, .45),
            scale: vm.Vector3.all(.26)))
          ..add(node('Quartz', _Meshes.quartz, GeodeMaterials.quartz(), at: vm.Vector3(.1, -.1, .45),
            scale: vm.Vector3.all(.9)))
          ..add(node('Fern', _Meshes.fern, leaf, at: vm.Vector3(-.4, .05, .7), rz: .25))
          ..add(node('Jade ring', fs.TorusGeometry(radius: .22, tubeRadius: .07), GeodeMaterials.jade(),
            at: vm.Vector3(.75, -.05, .1), rx: .9));
      case Geode3DAsset.stoneDial:
        _root.add(node('Stone dial', _Meshes.dial,
          fs.PhysicallyBasedMaterial(baseColorTexture: materials.stoneDial)
            ..roughnessFactor = .6..metallicFactor = 0..doubleSided = true));
      case Geode3DAsset.pebble:
        _root.add(node('Pebble', _Meshes.pebble, materials.stone(variant.clamp(0, 2), glow: .2)));
      case Geode3DAsset.fernSprig:
        _root.add(node('Fern', _Meshes.fern, leaf, rz: -.3, scale: vm.Vector3.all(1.2)));
    }
  }

  void _pose(double t) {
    final sway = spin ? t * .45 : 0.0;
    final rest = switch (asset) {
      Geode3DAsset.stoneDial => (-.18, .22),
      Geode3DAsset.forestSanctuary => (0.0, .35),
      _ => (-.12, -.45),
    };
    _root.mutateLocalTransform((matrix) => matrix
      ..setIdentity()
      ..translateByDouble(0, math.sin(t * .8) * .03, 0, 1)
      ..rotateX(rest.$1)
      ..rotateY(rest.$2 + sway + math.sin(t * .5) * .08));
  }

  @override
  bool advance(double dt, {required bool live}) {
    if (live) _time += dt;
    _pose(live ? _time : 0);
    scene.update(0);
    return live && spin;
  }
}
