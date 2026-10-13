import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// A rounded stone tablet as a shape: the lip facing the key light (top left) is lit,
/// the far lip falls into shadow, and a side wall shows below the slab. A negative
/// [depth] carves the shape into the surface instead (the lighting swaps and the wall
/// goes away). Depth lerps through zero, so pressed and selected states sink smoothly.
class StoneBevelBorder extends OutlinedBorder {
  const StoneBevelBorder({super.side,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)), this.depth = 3});

  final BorderRadiusGeometry borderRadius;

  /// Logical pixels the slab stands proud of (positive) or sinks into (negative) the
  /// surface.
  final double depth;

  static const _lit = Color(0x47E4F5D2), _litSoft = Color(0x1FE4F5D2);
  static const _shade = Color(0x80030A07), _shadeSoft = Color(0x38030A07);
  static const _wallTop = Color(0xFF2F4434), _wallBottom = Color(0xFF0B1611);

  RRect _rrect(Rect rect, TextDirection? textDirection) => borderRadius.resolve(textDirection).toRRect(rect);

  @override
  EdgeInsetsGeometry get dimensions => switch (side.style) {
    BorderStyle.none => EdgeInsets.zero,
    BorderStyle.solid => EdgeInsets.all(side.strokeInset),
  };

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
    Path()..addRRect(_rrect(rect, textDirection).deflate(side.strokeInset));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
    Path()..addRRect(_rrect(rect, textDirection));

  @override
  bool get preferPaintInterior => true;

  @override
  void paintInterior(Canvas canvas, Rect rect, Paint paint, {TextDirection? textDirection}) =>
    canvas.drawRRect(_rrect(rect, textDirection), paint);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (rect.isEmpty) return;
    final rrect = _rrect(rect, textDirection);
    final d = depth.abs().clamp(0.0, rect.shortestSide / 4);
    if (depth > .5) {
      // The slab's side wall, visible below it and under its rounded corners.
      final wall = RRect.fromLTRBAndCorners(rrect.left, rrect.top, rrect.right, rrect.bottom + d,
        topLeft: rrect.tlRadius, topRight: rrect.trRadius,
        bottomLeft: rrect.blRadius, bottomRight: rrect.brRadius);
      canvas.drawDRRect(wall, rrect.deflate(.5), Paint()..shader = ui.Gradient.linear(
        Offset(0, rrect.bottom - d), Offset(0, rrect.bottom + d), const [_wallTop, _wallBottom]));
    }
    if (d > .25) {
      final raised = depth > 0;
      canvas.save();
      canvas.clipRRect(rrect);
      // A stroke around the shape shifted toward a corner covers only the inner lip
      // on the opposite sides once clipped.
      void lip(Offset toward, Color strong, Color soft) {
        canvas.drawRRect(rrect.shift(toward * d * 1.1), Paint()..style = PaintingStyle.stroke
          ..strokeWidth = d * 2.6..color = soft);
        canvas.drawRRect(rrect.shift(toward * d * .55), Paint()..style = PaintingStyle.stroke
          ..strokeWidth = d * 1.1..color = strong);
      }
      lip(const Offset(1, 1), raised ? _lit : _shade, raised ? _litSoft : _shadeSoft);
      lip(const Offset(-1, -1), raised ? _shade : _lit, raised ? _shadeSoft : _litSoft);
      canvas.restore();
    }
    if (side.style == BorderStyle.solid) {
      if (side.width == 0) {
        canvas.drawRRect(rrect, side.toPaint());
      } else {
        canvas.drawDRRect(rrect.inflate(side.strokeOutset), rrect.deflate(side.strokeInset),
          Paint()..color = side.color);
      }
    }
  }

  @override
  StoneBevelBorder copyWith({BorderSide? side, BorderRadiusGeometry? borderRadius, double? depth}) =>
    StoneBevelBorder(side: side ?? this.side, borderRadius: borderRadius ?? this.borderRadius,
      depth: depth ?? this.depth);

  @override
  ShapeBorder scale(double t) =>
    StoneBevelBorder(side: side.scale(t), borderRadius: borderRadius * t, depth: depth * t);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is StoneBevelBorder) {
      return StoneBevelBorder(side: BorderSide.lerp(a.side, side, t),
        borderRadius: BorderRadiusGeometry.lerp(a.borderRadius, borderRadius, t)!,
        depth: ui.lerpDouble(a.depth, depth, t)!);
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is StoneBevelBorder) {
      return StoneBevelBorder(side: BorderSide.lerp(side, b.side, t),
        borderRadius: BorderRadiusGeometry.lerp(borderRadius, b.borderRadius, t)!,
        depth: ui.lerpDouble(depth, b.depth, t)!);
    }
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) => other is StoneBevelBorder && other.side == side &&
    other.borderRadius == borderRadius && other.depth == depth;

  @override
  int get hashCode => Object.hash(side, borderRadius, depth);

  @override
  String toString() => 'StoneBevelBorder($side, $borderRadius, depth: $depth)';
}

/// An outlined text field carved into stone: its upper lip is in shadow and the lower
/// lip catches the light, so the field reads as a hollow.
class CarvedInputBorder extends OutlineInputBorder {
  const CarvedInputBorder({super.borderSide, super.borderRadius, super.gapPadding});

  @override
  CarvedInputBorder copyWith({BorderSide? borderSide, BorderRadius? borderRadius, double? gapPadding}) =>
    CarvedInputBorder(borderSide: borderSide ?? this.borderSide,
      borderRadius: borderRadius ?? this.borderRadius, gapPadding: gapPadding ?? this.gapPadding);

  @override
  CarvedInputBorder scale(double t) => CarvedInputBorder(borderSide: borderSide.scale(t),
    borderRadius: borderRadius * t, gapPadding: gapPadding * t);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is OutlineInputBorder) {
      return CarvedInputBorder(borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
        gapPadding: ui.lerpDouble(a.gapPadding, gapPadding, t)!);
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is OutlineInputBorder) {
      return CarvedInputBorder(borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        borderRadius: BorderRadius.lerp(borderRadius, b.borderRadius, t)!,
        gapPadding: ui.lerpDouble(gapPadding, b.gapPadding, t)!);
    }
    return super.lerpTo(b, t);
  }

  @override
  void paint(Canvas canvas, Rect rect, {double? gapStart, double gapExtent = 0.0,
      double gapPercentage = 0.0, TextDirection? textDirection}) {
    final rrect = borderRadius.resolve(textDirection).toRRect(rect);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(rrect.shift(const Offset(2.2, 2.6)), Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 5..color = const Color(0x5C020806));
    canvas.drawRRect(rrect.shift(const Offset(-1.4, -1.6)), Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 3..color = const Color(0x1FCFE8C0));
    canvas.restore();
    super.paint(canvas, rect, gapStart: gapStart, gapExtent: gapExtent,
      gapPercentage: gapPercentage, textDirection: textDirection);
  }

  @override
  bool operator ==(Object other) => other is CarvedInputBorder && super == other;

  @override
  int get hashCode => Object.hash(CarvedInputBorder, super.hashCode);
}

/// Swings content in and out like a page of a stone book: perspective, a turn about
/// the leading edge, and a fade. [secondary] pushes the covered page back.
class Swing3DTransition extends StatelessWidget {
  const Swing3DTransition({super.key, required this.animation, required this.child,
    this.secondary});
  final Animation<double> animation;
  final Animation<double>? secondary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final listenable = secondary == null ? animation : Listenable.merge([animation, secondary]);
    return AnimatedBuilder(animation: listenable, child: child, builder: (context, child) {
      final t = Curves.easeOutCubic.transform(animation.value.clamp(0.0, 1.0));
      final back = Curves.easeInOutCubic.transform((secondary?.value ?? 0).clamp(0.0, 1.0));
      final rtl = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
      final scale = 1 - back * .06;
      final transform = vm.Matrix4.identity()
        ..setEntry(3, 2, .0012)
        ..rotateY(rtl * ((1 - t) * -.42 + back * .1))
        ..rotateX((1 - t) * .06)
        ..scaleByDouble(scale, scale, 1, 1);
      final opacity = (t * (1 - back * .35)).clamp(0.0, 1.0);
      // Always the same wrappers, so the page's state survives the transition's end.
      return Opacity(opacity: opacity, child: Transform(
        alignment: rtl > 0 ? Alignment.centerLeft : Alignment.centerRight,
        transform: transform, child: child));
    });
  }
}

/// [Swing3DTransition] for [MaterialPageRoute]s, via the theme.
class Swing3DPageTransitionsBuilder extends PageTransitionsBuilder {
  const Swing3DPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) =>
    Swing3DTransition(animation: animation, secondary: secondaryAnimation, child: child);
}
