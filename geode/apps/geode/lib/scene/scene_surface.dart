import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'geode_scene_controller.dart';

export 'geode_scene_controller.dart';
export 'gel_float.dart';

/// A photographic environment plus a true raymarched 3D glass sculpture.
///
/// The shader uses screen-space environment refraction and Fresnel reflection;
/// it is a designed liquid material, not a full fluid-volume simulation.
class SceneSurface extends StatefulWidget {
  const SceneSurface({
    super.key,
    required this.controller,
    this.orbAlignment = Alignment.center,
    this.orbScale = 1.0,
    this.interactive = true,
  });

  final GeodeSceneController controller;
  final Alignment orbAlignment;
  final double orbScale;
  final bool interactive;

  @override
  State<SceneSurface> createState() => _SceneSurfaceState();
}

class _SceneSurfaceState extends State<SceneSurface>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration? _previous;
  ui.FragmentShader? _shader;
  ui.Image? _environment;
  bool _systemReducedMotion = false;
  bool _appActive = true;
  bool _tickerModeEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_tick);
    widget.controller.addListener(_syncTicker);
    _loadRenderer();
  }

  Future<void> _loadRenderer() async {
    ui.Image? image;
    ui.FragmentShader? shader;
    try {
      // Decode once; no image readback or shader creation happens each frame.
      final bytes = await rootBundle.load('assets/images/forest-sanctuary.png');
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        targetWidth: 1920,
      );
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      final program = await ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag');
      shader = program.fragmentShader();
      shader.setImageSampler(0, image);
      if (!mounted) {
        shader.dispose();
        image.dispose();
        return;
      }
      setState(() {
        _shader = shader;
        _environment = image;
      });
      widget.controller.reportRenderer(ready: true);
    } catch (error) {
      shader?.dispose();
      if (!mounted) {
        image?.dispose();
        return;
      }
      // Keep a successfully decoded background if shader loading fails.
      setState(() => _environment = image);
      widget.controller.reportRenderer(ready: false, error: error.toString());
      if (kDebugMode) debugPrint('Geode scene fallback: $error');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _systemReducedMotion = MediaQuery.disableAnimationsOf(context);
    _tickerModeEnabled = TickerMode.of(context);
    // Defer notifications until inherited-widget propagation has completed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.setSystemReducedMotion(_systemReducedMotion);
    });
    _syncTicker();
  }

  @override
  void didUpdateWidget(SceneSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncTicker);
      widget.controller.addListener(_syncTicker);
      _previous = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.controller.setSystemReducedMotion(_systemReducedMotion);
          widget.controller.reportRenderer(ready: _shader != null);
          _syncTicker();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncTicker();
  }

  void _syncTicker() {
    final shouldRun = _appActive && _tickerModeEnabled &&
        !_systemReducedMotion && !widget.controller.motionDisabled;
    if (shouldRun && !_ticker.isActive) {
      _previous = null;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
      _previous = null;
    }
  }

  void _tick(Duration elapsed) {
    final previous = _previous;
    _previous = elapsed;
    if (previous == null) return;
    widget.controller.advance(
      (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      void interact(Offset position) {
        if (size.width <= 0 || size.height <= 0) return;
        widget.controller.interact(Offset(position.dx / size.width, position.dy / size.height));
      }

      final painting = RepaintBoundary(
        child: CustomPaint(
          size: size,
          isComplex: true,
          willChange: !_systemReducedMotion && !widget.controller.motionDisabled,
          painter: _ScenePainter(
            controller: widget.controller,
            shader: _shader,
            environment: _environment,
            orbAlignment: widget.orbAlignment,
            orbScale: widget.orbScale,
            systemReducedMotion: _systemReducedMotion,
          ),
        ),
      );
      if (!widget.interactive) return painting;
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (size.width <= 0 || size.height <= 0) return;
          widget.controller.touch(Offset(
            event.localPosition.dx / size.width,
            event.localPosition.dy / size.height,
          ));
        },
        onPointerMove: (event) => interact(event.localPosition),
        onPointerUp: (_) => widget.controller.release(),
        onPointerCancel: (_) => widget.controller.release(),
        child: painting,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_syncTicker);
    _ticker.dispose();
    _shader?.dispose();
    _environment?.dispose();
    super.dispose();
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.controller,
    required this.shader,
    required this.environment,
    required this.orbAlignment,
    required this.orbScale,
    required this.systemReducedMotion,
  }) : super(repaint: controller);

  final GeodeSceneController controller;
  final ui.FragmentShader? shader;
  final ui.Image? environment;
  final Alignment orbAlignment;
  final double orbScale;
  final bool systemReducedMotion;

  bool get reduced => systemReducedMotion || controller.effectiveReducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final center = Offset((orbAlignment.x + 1) / 2, (orbAlignment.y + 1) / 2);
    final activeShader = shader;
    final image = environment;
    if (activeShader != null && image != null) {
      final values = <double>[
        size.width, size.height,
        controller.time,
        controller.tilt.dx, controller.tilt.dy,
        controller.displayEnergy,
        controller.displayMaterial,
        controller.pulse,
        center.dx, center.dy,
        orbScale,
        image.width.toDouble(), image.height.toDouble(),
        reduced ? 1.0 : 0.0,
        controller.highQuality ? 1.0 : 0.0,
      ];
      final ripples = controller.ripples;
      for (var i = 0; i < 4; i += 1) {
        if (i < ripples.length && !reduced) {
          final ripple = ripples[i];
          values.addAll([
            ripple.position.dx, ripple.position.dy,
            controller.time - ripple.startedAt, ripple.strength,
          ]);
        } else {
          values.addAll([0, 0, 10, 0]);
        }
      }
      values.add(controller.hue); // Float slot 31.
      for (var i = 0; i < values.length; i += 1) {
        activeShader.setFloat(i, values[i]);
      }
      canvas.drawRect(rect, Paint()..shader = activeShader);
    } else {
      _paintFallback(canvas, size, center);
    }
    if (controller.particlesEnabled) _paintParticles(canvas, size);
  }

  void _paintFallback(Canvas canvas, Size size, Offset normalizedCenter) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF183E49));
    final image = environment;
    if (image != null) {
      paintImage(canvas: canvas, rect: rect, image: image, fit: BoxFit.cover,
          colorFilter: const ColorFilter.mode(Color(0x18123D4A), BlendMode.srcATop));
    }
    final center = Offset(normalizedCenter.dx * size.width, normalizedCenter.dy * size.height) +
        controller.tilt * (size.shortestSide * .026) +
        Offset(0, reduced ? 0 : math.sin(controller.time * .75) * size.shortestSide * .0095);
    final radius = size.shortestSide * .285 * orbScale;
    canvas.drawOval(
      Rect.fromCenter(center: center + Offset(0, radius * 1.34),
          width: radius * 1.65, height: radius * .18),
      Paint()..color = const Color(0x44163E42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    if (!reduced) {
      for (final ripple in controller.ripples) {
        final age = controller.time - ripple.startedAt;
        final touchCenter = Offset(ripple.position.dx * size.width, ripple.position.dy * size.height);
        final opacity = (math.exp(-age * 1.35) * ripple.strength * .24).clamp(0.0, 1.0).toDouble();
        for (var ring = 0; ring < 2; ring += 1) {
          final ringAge = age - ring * .15;
          if (ringAge < 0) continue;
          canvas.drawCircle(touchCenter, ringAge * size.shortestSide * .65,
              Paint()..color = const Color(0xFFCEF5ED).withValues(alpha: opacity)
                ..style = PaintingStyle.stroke..strokeWidth = ring == 0 ? 1.2 : .65);
        }
      }
    }
    _paintFallbackLens(canvas, size, center, radius, organic: true);
    final t = reduced ? 0.0 : controller.time;
    _paintFallbackLens(canvas, size,
        center + Offset(-radius * 1.12, -radius * 1.06 + math.sin(t * .9) * 5), radius * .11);
    _paintFallbackLens(canvas, size,
        center + Offset(radius * 1.21, -radius * .47 + math.sin(t * .7 + 1) * 4), radius * .06);
    _paintFallbackLens(canvas, size,
        center + Offset(-radius * 1.24, radius * .44), radius * .039);
  }

  void _paintFallbackLens(Canvas canvas, Size size, Offset center, double radius,
      {bool organic = false}) {
    final orb = Rect.fromCircle(center: center, radius: radius);
    final shape = Path();
    final t = reduced ? 0.0 : controller.time;
    for (var i = 0; i <= 80; i += 1) {
      final angle = i * math.pi * 2 / 80;
      final wave = organic ? math.sin(angle * 3 + t * .6) * .008 +
          math.cos(angle * 5 - t * .8) * (.003 + controller.displayEnergy * .008) : 0.0;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius * (1 + wave);
      if (i == 0) { shape.moveTo(point.dx, point.dy); } else { shape.lineTo(point.dx, point.dy); }
    }
    shape.close();
    canvas.save();
    canvas.clipPath(shape);
    final image = environment;
    if (image != null) {
      // A magnified photographic crop supplies a lightweight refractive fallback.
      canvas.translate(center.dx, center.dy);
      canvas.scale(1.18, 1.1);
      canvas.translate(-center.dx - radius * .10, -center.dy + radius * .055);
      paintImage(canvas: canvas, rect: Offset.zero & size, image: image, fit: BoxFit.cover);
    }
    canvas.restore();
    final water = <Color>[
      const Color(0x77E9FFFF), const Color(0x1042C6D1),
      const Color(0x661C90A8), const Color(0xDAB8F4F3),
    ];
    final opal = <Color>[
      const Color(0xEAF8E9EA), const Color(0xB9B8D6DF),
      const Color(0xC88EABD2), const Color(0xEFF4E8F6),
    ];
    final mercury = <Color>[
      const Color(0xFFF4FFFF), const Color(0xD8456D77),
      const Color(0xF016343E), const Color(0xFFF2FCFD),
    ];
    final material = controller.displayMaterial;
    final colors = List<Color>.generate(4, (i) => Color.lerp(
      Color.lerp(water[i], opal[i], material.clamp(0.0, 1.0).toDouble()),
      mercury[i], (material - 1).clamp(0.0, 1.0).toDouble(),
    )!);
    if ((controller.hue - .5).abs() > .005) {
      final tint = HSVColor.fromAHSV(.18, (controller.hue * 360 + 180) % 360, .55, .95).toColor();
      for (var i = 0; i < colors.length; i++) { colors[i] = Color.alphaBlend(tint, colors[i]); }
    }
    canvas.drawPath(shape, Paint()
      ..shader = RadialGradient(center: const Alignment(-.38, -.5),
          radius: 1.02, colors: colors, stops: const [0, .45, .81, 1]).createShader(orb));
    canvas.drawPath(shape, Paint()
      ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xF1E5FFFC), Color(0x18D5FCFF), Color(0xA28FDBE7), Color(0xEED7FFFF)],
          stops: [0, .35, .72, 1]).createShader(orb)
      ..style = PaintingStyle.stroke..strokeWidth = organic ? 1.35 : .8);
    canvas.save();
    canvas.clipPath(shape);
    canvas.drawOval(Rect.fromCenter(center: center + Offset(-radius * .37, -radius * .60),
        width: radius * .62, height: radius * .16), Paint()
      ..color = const Color(0xBDF5FFFF)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(.5, radius * .045)));
    canvas.drawArc(orb.deflate(radius * .04), math.pi * 1.05, math.pi * .38, false,
        Paint()..color = const Color(0xB8FFFFFF)..style = PaintingStyle.stroke
          ..strokeWidth = math.max(.7, radius * .009)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(.3, radius * .005)));
    canvas.restore();
  }

  void _paintParticles(Canvas canvas, Size size) {
    final t = reduced ? 0.0 : controller.time;
    final paint = Paint();
    // Three depth bands: far mist specks, mid-field dew, near luminous bokeh.
    // Deterministic trajectories keep particles stable across navigation.
    final count = (controller.particleDensity * (controller.highQuality ? 84 : 36)).round();
    for (var i = 0; i < count; i += 1) {
      final seed = i * 2.3999632297;
      final depth = (i % 3 + 1) / 3.0;
      final x = (.5 + math.sin(seed * 2.2) * .48) * size.width;
      final y = ((i * .173 + .13 - t * (.0012 + depth * .002)) % 1.0) * size.height;
      final drift = math.sin(t * (.14 + depth * .1) + seed) * (3 + depth * 11);
      final parallax = controller.tilt * (depth * 9);
      final point = Offset(x + drift, y) + parallax;
      final glint = math.pow(math.max(0.0, math.sin(seed + t * .65)), 12).toDouble();
      final opacity = .035 + depth * .08 + glint * .15;
      final radius = .55 + depth * 1.1;
      if (depth > .9 && controller.highQuality) {
        paint..color = const Color(0xFFAEEEF6).withValues(alpha: opacity * .2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(point, radius * 2.4, paint);
      }
      paint..maskFilter = null
        ..color = const Color(0xFFE0FAFF).withValues(alpha: opacity);
      canvas.drawCircle(point, radius, paint);
      if (glint > .65 && depth > .5) {
        paint..strokeWidth = .5..color = Colors.white.withValues(alpha: glint * .22);
        canvas.drawLine(point - const Offset(3.5, 0), point + const Offset(3.5, 0), paint);
        canvas.drawLine(point - const Offset(0, 3.5), point + const Offset(0, 3.5), paint);
      }
    }
    if (controller.particleDensity == 0) return;
    if (reduced || controller.burstAge > 2.4) return;
    final age = controller.burstAge;
    final center = Offset(controller.burstPosition.dx * size.width, controller.burstPosition.dy * size.height);
    final scale = size.shortestSide * orbScale;
    for (var i = 0; i < (controller.particleDensity * 26).ceil(); i += 1) {
      final angle = i * 2.3999632297;
      final speed = .12 + (i % 5) * .022;
      final x = math.cos(angle) * scale * (.015 + age * speed);
      final y = math.sin(angle) * scale * (.015 + age * speed) + scale * .16 * age * age;
      final opacity = ((1 - age / 2.4) * .52).clamp(0.0, 1.0).toDouble();
      final radius = (1.2 + i % 3) * (1 - age / 3.4);
      paint.color = const Color(0xFFD3F6FF).withValues(alpha: opacity);
      canvas.drawCircle(center + Offset(x, y), radius, paint);
      paint.color = Colors.white.withValues(alpha: opacity * .8);
      canvas.drawCircle(center + Offset(x - radius * .25, y - radius * .3), radius * .27, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.shader != shader ||
      oldDelegate.environment != environment ||
      oldDelegate.orbAlignment != orbAlignment ||
      oldDelegate.orbScale != orbScale ||
      oldDelegate.systemReducedMotion != systemReducedMotion;
}
