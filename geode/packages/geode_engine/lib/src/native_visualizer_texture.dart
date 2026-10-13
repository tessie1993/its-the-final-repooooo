import 'dart:async';

import 'package:flutter/material.dart';

import 'geode_visual_controller.dart';

/// A GPU texture from the original C++ renderer, with no pixel copies to Dart.
class NativeVisualizerTexture extends StatefulWidget {
  const NativeVisualizerTexture({super.key, required this.controller});
  final GeodeVisualController controller;

  @override
  State<NativeVisualizerTexture> createState() => _NativeVisualizerTextureState();
}

class _NativeVisualizerTextureState extends State<NativeVisualizerTexture>
    with WidgetsBindingObserver {
  final _owner = Object();
  int? _texture;
  Size? _surfaceSize;
  (Size, int)? _attempt;
  Future<void> _surfaceWork = Future<void>.value();
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(widget.controller.setAppActive(state == AppLifecycleState.resumed));
  }

  @override
  void didUpdateWidget(NativeVisualizerTexture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    ++_generation;
    unawaited(oldWidget.controller.releaseTexture(_texture, owner: _owner));
    _texture = null;
    _surfaceSize = null;
    _attempt = null;
  }

  void _schedule(Size logicalSize, double pixelRatio) {
    final controller = widget.controller;
    // Bound fill-rate and texture memory on large and high-density displays.
    final scale = (1080 / (logicalSize.longestSide * pixelRatio)).clamp(0.0, 1.0);
    final size = Size(
      (logicalSize.width * pixelRatio * scale).round().clamp(1, 2048).toDouble(),
      (logicalSize.height * pixelRatio * scale).round().clamp(1, 2048).toDouble(),
    );
    if (_texture != null && size == _surfaceSize) return;
    final attempt = (size, controller.surfaceRevision);
    if (_attempt == attempt) return;
    _attempt = attempt;
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _surfaceWork = _surfaceWork.then((_) async {
        if (!mounted || generation != _generation) return;
        final previous = _texture;
        if (previous != null) {
          setState(() => _texture = null);
          await controller.releaseTexture(previous, owner: _owner);
        }
        final texture = await controller.acquireTexture(
          width: size.width.toInt(), height: size.height.toInt(), owner: _owner,
        );
        if (!mounted || generation != _generation || widget.controller != controller) {
          await controller.releaseTexture(texture, owner: _owner);
          return;
        }
        setState(() { _texture = texture; _surfaceSize = size; });
      });
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => LayoutBuilder(builder: (context, bounds) {
      if (bounds.biggest.isFinite && !bounds.biggest.isEmpty) {
        _schedule(bounds.biggest, MediaQuery.devicePixelRatioOf(context));
      }
      final texture = _texture;
      if (texture == null) return const SizedBox.expand();
      return RepaintBoundary(child: Texture(textureId: texture, filterQuality: FilterQuality.low));
    }),
  );

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.controller.releaseTexture(_texture, owner: _owner));
    super.dispose();
  }
}
