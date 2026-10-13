import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// Gives a control physical depth: it tilts toward the finger in perspective, sinks
/// while pressed, and a specular sheen slides across it like light on wet stone.
/// Pointer handling uses a [Listener], so taps still reach the child unchanged.
class Depth3D extends StatefulWidget {
  const Depth3D({super.key, required this.child, this.enabled = true,
    this.maxTilt = .16, this.sink = .035, this.radius = 28});

  final Widget child;
  final bool enabled;

  /// Largest rotation (radians) toward the touch point.
  final double maxTilt;

  /// Fractional shrink while pressed, read as the control moving away.
  final double sink;
  final double radius;

  @override
  State<Depth3D> createState() => _Depth3DState();
}

class _Depth3DState extends State<Depth3D> with SingleTickerProviderStateMixin {
  late final _press = AnimationController(vsync: this,
    duration: const Duration(milliseconds: 140), reverseDuration: const Duration(milliseconds: 260));
  final _focus = ValueNotifier(Offset.zero);

  void _down(PointerEvent event) {
    if (!widget.enabled) return;
    _aim(event);
    _press.forward();
  }

  void _aim(PointerEvent event) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return;
    final local = event.localPosition;
    _focus.value = Offset((local.dx / box.size.width * 2 - 1).clamp(-1.0, 1.0),
      (local.dy / box.size.height * 2 - 1).clamp(-1.0, 1.0));
  }

  void _up(PointerEvent _) => _press.reverse();

  @override
  void didUpdateWidget(Depth3D old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) _press.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return Listener(
      onPointerDown: _down,
      onPointerMove: (event) { if (_press.value > 0) _aim(event); },
      onPointerUp: _up,
      onPointerCancel: _up,
      child: AnimatedBuilder(
        animation: Listenable.merge([_press, _focus]),
        child: widget.child,
        builder: (context, child) {
          final p = Curves.easeOutCubic.transform(_press.value);
          final focus = _focus.value;
          final scale = 1 - widget.sink * p;
          // Pressing a corner pushes that corner away from the viewer.
          final transform = vm.Matrix4.identity()
            ..setEntry(3, 2, .0011)
            ..rotateX(focus.dy * widget.maxTilt * p)
            ..rotateY(-focus.dx * widget.maxTilt * p)
            ..scaleByDouble(scale, scale, 1, 1);
          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: p == 0 ? child : DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                gradient: RadialGradient(
                  center: Alignment(-focus.dx * .8, -focus.dy * .8),
                  radius: 1.1,
                  colors: [Color.fromRGBO(220, 255, 236, .16 * p), const Color(0x00DCFFEC)],
                ),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    _focus.dispose();
    super.dispose();
  }
}

/// A slider thumb shaped as a lit river pebble with a contact shadow.
class PebbleThumbShape extends SliderComponentShape {
  const PebbleThumbShape({this.radius = 11});
  final double radius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.fromRadius(radius + 2);

  @override
  void paint(PaintingContext context, Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final lift = activationAnimation.value;
    final r = radius * (1 + lift * .12);
    final body = Rect.fromCenter(center: center, width: r * 2.2, height: r * 1.8);
    canvas.drawOval(body.shift(Offset(0, 3 + lift * 3)).inflate(1), Paint()
      ..color = Color.fromRGBO(2, 10, 8, .55 - lift * .15)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + lift * 3));
    final enabled = enableAnimation.value;
    canvas.drawOval(body, Paint()..shader = RadialGradient(
      center: const Alignment(-.4, -.55), radius: 1.05,
      colors: [
        Color.lerp(const Color(0xFF6E7466), const Color(0xFFD6E6B8), enabled)!,
        Color.lerp(const Color(0xFF3D463A), const Color(0xFF6E9761), enabled)!,
        const Color(0xFF1B2C21),
      ],
      stops: const [0, .55, 1],
    ).createShader(body));
    // Specular glint and a soft rim keep the pebble reading as a rounded solid.
    canvas.drawOval(Rect.fromCenter(center: center + Offset(-r * .38, -r * .42),
      width: r * .62, height: r * .34), Paint()..color = Color.fromRGBO(255, 255, 255, .35 * enabled));
    canvas.drawOval(body, Paint()..style = PaintingStyle.stroke..strokeWidth = .8
      ..color = const Color(0x66C9E5B0));
  }
}

/// A slider track carved into stone: an inset groove whose filled part glows.
class GrooveTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const GrooveTrackShape();

  @override
  void paint(PaintingContext context, Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(parentBox: parentBox, offset: offset,
      sliderTheme: sliderTheme, isEnabled: isEnabled, isDiscrete: isDiscrete);
    if (rect.isEmpty) return;
    final canvas = context.canvas;
    final h = math.max(rect.height, 5.0);
    final groove = RRect.fromRectAndRadius(Rect.fromCenter(center: rect.center,
      width: rect.width, height: h), Radius.circular(h / 2));
    canvas.drawRRect(groove, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFF07130F), Color(0xFF203227), Color(0xFF3F5440)],
    ).createShader(groove.outerRect));
    final ltr = textDirection == TextDirection.ltr;
    final filled = Rect.fromLTRB(ltr ? groove.left : thumbCenter.dx, groove.top + 1,
      ltr ? thumbCenter.dx : groove.right, groove.bottom - 1);
    if (filled.width > 0) {
      canvas.drawRRect(RRect.fromRectAndRadius(filled, Radius.circular(h / 2)), Paint()
        ..shader = LinearGradient(colors: [
          (sliderTheme.activeTrackColor ?? const Color(0xFF8AF2B0)).withValues(alpha: .55),
          (sliderTheme.activeTrackColor ?? const Color(0xFF8AF2B0)).withValues(alpha: .95 * enableAnimation.value),
        ]).createShader(filled));
    }
    // A lit lower lip sells the carved depth.
    canvas.drawLine(groove.outerRect.bottomLeft + Offset(h / 2, .5),
      groove.outerRect.bottomRight + Offset(-h / 2, .5),
      Paint()..color = const Color(0x40B8D4A4)..strokeWidth = .8);
  }
}
