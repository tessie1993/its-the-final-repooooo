import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' as fs;
import 'geode_scene_controller.dart';
import 'native_nature_scene.dart';

/// An optional transparent GPU pass; the underlying glass shader is retained
/// when the platform cannot initialize Flutter GPU.
class NativeNatureLayer extends StatefulWidget {
  const NativeNatureLayer({super.key, required this.controller});
  final GeodeSceneController controller;
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
      await fs.Scene.preload();
      if (!mounted) return;
      nature = NativeNatureScene();
      setState(() => _nature = nature);
    } catch (error) {
      nature?.dispose();
      if (kDebugMode) debugPrint('Geode GPU accents unavailable: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nature = _nature;
    if (nature == null) return const SizedBox.expand();
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
    : super(repaint: controller);
  final NativeNatureScene nature;
  final GeodeSceneController controller;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || nature.failed) return;
    canvas.save();
    try {
      nature.update(controller);
      nature.scene.render(nature.camera, canvas,
        viewport: Offset.zero & size, pixelRatio: pixelRatio);
    } catch (error) {
      nature.failed = true;
      if (kDebugMode) debugPrint('Geode GPU accents stopped: $error');
    } finally { canvas.restore(); }
  }

  @override
  bool shouldRepaint(_NativeNaturePainter old) => old.nature != nature ||
    old.controller != controller || old.pixelRatio != pixelRatio;
}
