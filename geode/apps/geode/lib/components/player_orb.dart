import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../scene/geode_scene_controller.dart';
import '../scene/player_orb_scene.dart';

/// Bounded player artwork with a solid 3D jade medallion and floating seeds.
/// It follows the scene's clock, pauses with playback, and retains a Canvas
/// rendering when Flutter GPU cannot initialize on the current device.
class PlayerOrb extends StatefulWidget {
  const PlayerOrb({
    super.key,
    required this.controller,
    required this.playing,
    required this.enableNativeScene,
  });

  final GeodeSceneController controller;
  final bool playing;
  final bool enableNativeScene;

  @override
  State<PlayerOrb> createState() => _PlayerOrbState();
}

class _PlayerOrbState extends State<PlayerOrb> {
  final _clock = _OrbClock();
  PlayerOrbScene? _native;
  ui.Image? _artwork;
  int _nativeGeneration = 0;
  bool _systemReducedMotion = false;

  @override
  void initState() {
    super.initState();
    _clock.previous = widget.controller.time;
    widget.controller.addListener(_advanceClock);
    _loadArtwork();
    if (widget.enableNativeScene) _initializeNative();
  }

  void _advanceClock() {
    final now = widget.controller.time;
    if (widget.playing && !widget.controller.motionDisabled && !_systemReducedMotion) {
      _clock.time += (now - _clock.previous).clamp(0.0, .1);
    }
    _clock.previous = now;
  }

  Future<void> _loadArtwork() async {
    try {
      final bytes = await rootBundle.load('assets/images/stone-dial.png');
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        targetWidth: 512,
      );
      late ui.Image image;
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _artwork = image);
    } catch (error) {
      if (kDebugMode) debugPrint('Player artwork unavailable: $error');
    }
  }

  Future<void> _initializeNative() async {
    final generation = ++_nativeGeneration;
    PlayerOrbScene? native;
    try {
      native = await PlayerOrbScene.create();
      if (!mounted || generation != _nativeGeneration || !widget.enableNativeScene) {
        native.dispose();
        return;
      }
      setState(() => _native = native);
    } catch (error) {
      native?.dispose();
      if (kDebugMode) debugPrint('Player orb uses Canvas: $error');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _systemReducedMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(PlayerOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_advanceClock);
      _clock.previous = widget.controller.time;
      widget.controller.addListener(_advanceClock);
    }
    if (oldWidget.enableNativeScene != widget.enableNativeScene) {
      if (widget.enableNativeScene) {
        _initializeNative();
      } else {
        _nativeGeneration++;
        _native?.dispose();
        _native = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth.clamp(0.0, 360.0).toDouble()
        : 320.0;
    return Semantics(
      image: true,
      label: 'A solid moss and jade music medallion floating above water',
      child: IgnorePointer(child: RepaintBoundary(child: SizedBox(
        width: width,
        height: width * .94,
        child: CustomPaint(
          isComplex: true,
          painter: _PlayerOrbPainter(
            controller: widget.controller,
            clock: _clock,
            native: _native,
            artwork: _artwork,
            reducedMotion: _systemReducedMotion,
            pixelRatio: MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0).toDouble(),
          ),
        ),
      ))),
    );
  });

  @override
  void dispose() {
    _nativeGeneration++;
    widget.controller.removeListener(_advanceClock);
    _native?.dispose();
    _artwork?.dispose();
    super.dispose();
  }
}

class _OrbClock {
  double previous = 0;
  double time = 0;
}

class _PlayerOrbPainter extends CustomPainter {
  _PlayerOrbPainter({
    required this.controller,
    required this.clock,
    required this.native,
    required this.artwork,
    required this.reducedMotion,
    required this.pixelRatio,
  }) : super(repaint: Listenable.merge([controller, if (native != null) native.scene.repaintRequested]));

  final GeodeSceneController controller;
  final _OrbClock clock;
  final PlayerOrbScene? native;
  final ui.Image? artwork;
  final bool reducedMotion;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final quiet = reducedMotion || controller.effectiveReducedMotion;
    final time = quiet ? 0.0 : clock.time;
    _paintWater(canvas, size, time);
    final scene = native;
    var rendered = false;
    if (scene != null && !scene.failed) {
      canvas.save();
      try {
        scene.update(controller, time, reducedMotion: quiet);
        scene.scene.render(scene.camera, canvas,
          viewport: Rect.fromLTWH(0, 0, size.width, size.height * .90),
          pixelRatio: pixelRatio);
        rendered = true;
      } catch (error) {
        scene.failed = true;
        if (kDebugMode) debugPrint('Player orb rendering stopped: $error');
      } finally {
        canvas.restore();
      }
    }
    if (!rendered) _paintCanvasOrb(canvas, size, time);
  }

  void _paintWater(Canvas canvas, Size size, double time) {
    final center = Offset(size.width * .5, size.height * .85);
    final shadow = Rect.fromCenter(center: center,
      width: size.width * .56, height: size.height * .095);
    canvas.drawOval(shadow, Paint()
      ..color = const Color(0x660D160E)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawOval(shadow.deflate(6), Paint()
      ..shader = const RadialGradient(colors: [Color(0x37598561), Color(0x00598561)])
          .createShader(shadow));
    final strength = controller.rippleStrength;
    for (var i = 0; i < 4; i++) {
      final phase = (time * .14 + i / 4) % 1;
      final radius = size.width * (.17 + phase * .28);
      canvas.drawOval(Rect.fromCenter(center: center,
        width: radius * 2, height: radius * .25), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8 + (1 - phase) * .45
          ..color = const Color(0xFFB8C9A2).withValues(alpha: (1 - phase) * .28 * strength));
    }
  }

  void _paintCanvasOrb(Canvas canvas, Size size, double time) {
    final width = size.width;
    final center = Offset(width * .5, size.height * .45 + math.sin(time * .65) * 2);
    final radius = width * .285;
    final bounds = Rect.fromCircle(center: center, radius: radius);

    void droplet(int i, {required bool front}) {
      if (!controller.particlesEnabled || i >= (controller.particleDensity * 7).ceil()) return;
      final phase = i * math.pi * 2 / 7 + time * .22;
      if ((math.sin(phase) < 0) != front) return;
      final point = center + Offset(math.cos(phase) * width * .39,
        math.sin(phase) * width * .105 + math.cos(phase) * width * .055);
      final r = width * (.016 + (i % 3) * .005);
      final rect = Rect.fromCircle(center: point, radius: r);
      canvas.drawOval(Rect.fromCenter(center: point, width: r * 1.4, height: r * 2.2), Paint()..shader = const RadialGradient(
        center: Alignment(-.45, -.6), radius: 1,
        colors: [Color(0xFFAFAD73), Color(0xFF59623B), Color(0xFF253D26)],
      ).createShader(rect));
    }

    for (var i = 0; i < 7; i++) { droplet(i, front: false); }
    canvas.drawCircle(center, radius + 3, Paint()
      ..color = const Color(0x550B1D12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
    canvas.drawCircle(center, radius, Paint()..shader = const RadialGradient(
      center: Alignment(-.38, -.48), radius: 1.1,
      colors: [Color(0xFF8C9C6F), Color(0xFF45674C), Color(0xFF152B21)],
      stops: [0, .55, 1],
    ).createShader(bounds));

    canvas.save();
    canvas.clipPath(Path()..addOval(bounds));
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.16 + math.sin(time * .14) * .07);
    canvas.scale(.90 + math.cos(time * .18) * .08, 1);
    final tile = Rect.fromCenter(center: Offset.zero, width: radius * 1.8, height: radius * 1.8);
    canvas.drawOval(tile.shift(const Offset(4, 5)),
      Paint()..color = const Color(0xB6001721));
    canvas.clipPath(Path()..addOval(tile));
    final image = artwork;
    if (image != null) {
      final shortest = math.min(image.width, image.height).toDouble();
      canvas.drawImageRect(image, Rect.fromCenter(
        center: Offset(image.width / 2, image.height / 2), width: shortest, height: shortest),
        tile, Paint()..filterQuality = FilterQuality.medium);
    } else {
      canvas.drawRect(tile, Paint()..color = const Color(0xFF183F42));
      for (var i = 0; i < 7; i++) {
        final x = (i - 3) * radius * .12;
        final h = radius * (.25 + math.sin(i * .9).abs() * .46);
        canvas.drawLine(Offset(x, h / 2), Offset(x, -h / 2), Paint()
          ..color = const Color(0xFFA5DDD0)..strokeWidth = 3..strokeCap = StrokeCap.round);
      }
    }
    canvas.restore();

    for (var ring = 0; ring < 4; ring++) {
      canvas.drawArc(bounds.deflate(radius * (.04 + ring * .045)),
        .3 + ring * .5, math.pi * 1.1, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = radius * .012
          ..color = const Color(0xFFADB68E).withValues(alpha: .18 - ring * .025));
    }
    canvas.drawCircle(center, radius, Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 2..color = const Color(0xFF344E36));
    for (var i = 0; i < 7; i++) { droplet(i, front: true); }
  }

  @override
  bool shouldRepaint(_PlayerOrbPainter old) => old.controller != controller ||
    old.clock != clock || old.native != native || old.artwork != artwork ||
    old.reducedMotion != reducedMotion || old.pixelRatio != pixelRatio;
}
