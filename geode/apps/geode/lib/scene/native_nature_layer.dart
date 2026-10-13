import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../three_d/geode_materials.dart';
import 'geode_scene_controller.dart';
import 'native_nature_scene.dart';

/// The 3D nature world behind every screen. The underlying nature shader is retained
/// when the platform cannot initialize Flutter GPU.
class NativeNatureLayer extends StatefulWidget {
  const NativeNatureLayer({super.key, required this.controller, this.destination = 0});
  final GeodeSceneController controller;

  /// Shell destination (0 visuals, 1 music, 2 studio, 3 settings, -1 immersive).
  final int destination;
  @override
  State<NativeNatureLayer> createState() => _NativeNatureLayerState();
}

class _NativeNatureLayerState extends State<NativeNatureLayer> {
  NativeNatureScene? _nature;
  @override
  void initState() { super.initState(); _initialize(); }

  Future<void> _initialize() async {
    NativeNatureScene? nature;
    try {
      final materials = await GeodeMaterials.load();
      if (!mounted) return;
      nature = NativeNatureScene(materials);
      setState(() => _nature = nature);
    } catch (error) {
      nature?.dispose();
      if (kDebugMode) debugPrint('Geode 3D world unavailable: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nature = _nature;
    if (nature == null) return const SizedBox.expand();
    nature.destination = widget.destination;
    return IgnorePointer(child: RepaintBoundary(child: CustomPaint(
      isComplex: true,
      painter: _NativeNaturePainter(nature, widget.controller,
        MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0).toDouble()),
      child: const SizedBox.expand(),
    )));
  }

  @override
  void dispose() { _nature?.dispose(); super.dispose(); }
}

class _NativeNaturePainter extends CustomPainter {
  _NativeNaturePainter(this.nature, this.controller, this.pixelRatio)
    : super(repaint: Listenable.merge([controller, nature.scene.repaintRequested]));
  final NativeNatureScene nature;
  final GeodeSceneController controller;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || nature.failed) return;
    canvas.save();
    try {
      nature.update(controller, aspect: size.width / size.height);
      nature.scene.render(nature.camera, canvas,
        viewport: Offset.zero & size, pixelRatio: pixelRatio);
    } catch (error) {
      nature.failed = true;
      if (kDebugMode) debugPrint('Geode 3D world stopped: $error');
    } finally { canvas.restore(); }
  }

  @override
  bool shouldRepaint(_NativeNaturePainter old) => old.nature != nature ||
    old.controller != controller || old.pixelRatio != pixelRatio;
}
