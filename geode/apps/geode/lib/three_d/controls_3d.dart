import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'soft_3d.dart';

const _stone = Color(0xFF52624C), _stoneDark = Color(0xFF1A2B22), _jade = Color(0xFF7BE0A8);
const _jadeDeep = Color(0xFF2E7A55), _glass = Color(0xFFCFEBDD), _focus = Color(0xFFD7DEAE);

Duration _motion(BuildContext context, int ms) =>
  MediaQuery.disableAnimationsOf(context) ? Duration.zero : Duration(milliseconds: ms);

/// A switch carved into stone: a pebble rolls along a hollow groove, which glows jade
/// when on. Tap or drag it. Same contract as [Switch]: `onChanged == null` disables it.
class Switch3D extends StatefulWidget {
  const Switch3D({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<Switch3D> createState() => _Switch3DState();
}

class _Switch3DState extends State<Switch3D> with TickerProviderStateMixin {
  late final _position = AnimationController(vsync: this, value: widget.value ? 1 : 0,
    duration: const Duration(milliseconds: 260));
  late final _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 110));
  bool _focused = false;
  static const _travel = 30.0;

  bool get _enabled => widget.onChanged != null;

  @override
  void didUpdateWidget(Switch3D old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _settle();
  }

  void _settle() {
    _position.duration = _motion(context, 260);
    _position.animateTo(widget.value ? 1 : 0, curve: Curves.easeInOutCubic);
  }

  void _toggle() {
    if (_enabled) widget.onChanged!(!widget.value);
  }

  void _dragEnd(DragEndDetails details) {
    _press.reverse();
    if (!_enabled) return;
    final velocity = details.primaryVelocity ?? 0;
    final on = velocity.abs() > 300 ? velocity > 0 : _position.value >= .5;
    if (on != widget.value) {
      widget.onChanged!(on);
    } else {
      _settle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final directional = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    return Semantics(toggled: widget.value, enabled: _enabled, onTap: _enabled ? _toggle : null,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowFocusHighlight: (focused) => setState(() => _focused = focused),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { _toggle(); return null; })},
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => _press.forward() : null,
          onTapCancel: () => _press.reverse(),
          onTapUp: _enabled ? (_) => _press.reverse() : null,
          onTap: _enabled ? _toggle : null,
          onHorizontalDragStart: _enabled ? (_) { _position.stop(); _press.forward(); } : null,
          onHorizontalDragUpdate: _enabled ? (details) => _position.value =
            (_position.value + details.primaryDelta! * directional / _travel).clamp(0.0, 1.0) : null,
          onHorizontalDragEnd: _enabled ? _dragEnd : null,
          child: SizedBox(width: 64, height: 48, child: CustomPaint(painter: _SwitchPainter(
            position: _position, press: _press, enabled: _enabled, focused: _focused,
            mirrored: directional < 0))),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _position.dispose();
    _press.dispose();
    super.dispose();
  }
}

class _SwitchPainter extends CustomPainter {
  _SwitchPainter({required this.position, required this.press, required this.enabled,
    required this.focused, required this.mirrored}) : super(repaint: Listenable.merge([position, press]));

  final Animation<double> position, press;
  final bool enabled, focused, mirrored;

  static const _halfLength = 1.0, _grooveRadius = .7, _pebbleRadius = .6;
  static final _groove = SoftMesh.capsule(halfLength: _halfLength, radius: _grooveRadius,
    depthScale: .55, segments: 24);
  static final _pebble = SoftMesh.ellipsoid(rx: 1, ry: .9, rz: .86, segments: 16, rings: 11);

  @override
  void paint(Canvas canvas, Size size) {
    final unit = math.min(size.width / 3.6, size.height / 1.9);
    final renderer = SoftRenderer(center: size.center(Offset.zero), unit: unit, distance: 9);
    final t = position.value.clamp(0.0, 1.0);
    final glow = enabled ? t : t * .3;
    final fade = enabled ? 1.0 : .45;
    renderer.drawMesh(canvas, _groove, vm.Matrix4.identity(), SoftMaterial(
      color: Color.lerp(_stoneDark, _jadeDeep, glow)!.withValues(alpha: fade),
      ambient: .38, diffuse: .7, specular: .08, rim: 0, emissive: glow * .55), inside: true);
    final x = (t * 2 - 1) * _halfLength * (mirrored ? -1 : 1);
    final lift = press.value;
    final scale = _pebbleRadius * (1 + lift * .1);
    // Contact shadow on the groove floor.
    final shadowCenter = renderer.project(x + .08, -.12, -.2);
    canvas.drawOval(Rect.fromCenter(center: shadowCenter, width: scale * unit * 2.1,
      height: scale * unit * 1.5), Paint()
      ..color = Color.fromRGBO(0, 6, 4, .45 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    // The pebble rolls: travelling one radius turns it one radian.
    final model = vm.Matrix4.translationValues(x, 0, .1 + lift * .12)
      ..rotateY(x / _pebbleRadius)
      ..scaleByDouble(scale, scale, scale, 1);
    final face = Color.lerp(_stone, _jade, glow)!;
    final vein = Color.lerp(const Color(0xFF7D8A70), const Color(0xFFD9FFE8), glow)!;
    final mesh = _pebble;
    renderer.drawMesh(canvas, mesh, model, SoftMaterial(color: face.withValues(alpha: fade),
      emissive: glow * .2, specular: .4, rim: .22), tint: (i) {
      final k = i * 3;
      final band = math.sin(mesh.positions[k] * 5.2 + mesh.positions[k + 2] * 3.1);
      return (band > .82 ? vein : face).withValues(alpha: fade);
    });
    if (focused) {
      final rect = Rect.fromCenter(center: size.center(Offset.zero),
        width: (_halfLength + _grooveRadius) * 2 * unit + 8, height: _grooveRadius * 2 * unit + 8);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)), Paint()
        ..style = PaintingStyle.stroke..strokeWidth = 2..color = _focus);
    }
  }

  @override
  bool shouldRepaint(_SwitchPainter old) =>
    old.enabled != enabled || old.focused != focused || old.mirrored != mirrored ||
    old.position != position || old.press != press;
}

/// A [ListTile] with a [Switch3D], replacing [SwitchListTile]: the whole row toggles.
class SwitchTile3D extends StatelessWidget {
  const SwitchTile3D({super.key, required this.title, required this.value,
    required this.onChanged, this.subtitle, this.contentPadding});
  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) => MergeSemantics(child: ListTile(
    contentPadding: contentPadding, title: title, subtitle: subtitle,
    enabled: onChanged != null,
    trailing: Switch3D(value: value, onChanged: onChanged),
    onTap: onChanged == null ? null : () => onChanged!(!value)));
}

/// A checkbox as a small stone block: checking it tumbles the block forward to show
/// a glowing jade face with the check mark.
class Check3D extends StatefulWidget {
  const Check3D({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<Check3D> createState() => _Check3DState();
}

class _Check3DState extends State<Check3D> with SingleTickerProviderStateMixin {
  late final _turn = AnimationController(vsync: this, value: widget.value ? 1 : 0,
    duration: const Duration(milliseconds: 340));
  bool _focused = false;

  bool get _enabled => widget.onChanged != null;

  @override
  void didUpdateWidget(Check3D old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _turn.duration = _motion(context, 340);
      _turn.animateTo(widget.value ? 1 : 0, curve: Curves.easeOutBack);
    }
  }

  void _toggle() {
    if (_enabled) widget.onChanged!(!widget.value);
  }

  @override
  Widget build(BuildContext context) => Semantics(checked: widget.value, enabled: _enabled,
    onTap: _enabled ? _toggle : null,
    child: FocusableActionDetector(
      enabled: _enabled,
      mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowFocusHighlight: (focused) => setState(() => _focused = focused),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { _toggle(); return null; })},
      child: GestureDetector(excludeFromSemantics: true, behavior: HitTestBehavior.opaque,
        onTap: _enabled ? _toggle : null,
        child: SizedBox.square(dimension: 48, child: CustomPaint(
          painter: _CheckPainter(turn: _turn, enabled: _enabled, focused: _focused))))),
  );

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.turn, required this.enabled, required this.focused}) : super(repaint: turn);
  final Animation<double> turn;
  final bool enabled, focused;

  static final _cube = SoftMesh.roundedCube(roundness: .3, segments: 24, rings: 14);

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 4.2;
    final renderer = SoftRenderer(center: size.center(Offset.zero), unit: unit,
      distance: 10, pitch: .38, yaw: -.5);
    final t = turn.value;
    final fade = enabled ? 1.0 : .45;
    final hop = math.sin(t.clamp(0.0, 1.0) * math.pi) * .45;
    final model = vm.Matrix4.translationValues(0, hop, 0)..rotateX(-math.pi / 2 * t);
    canvas.drawOval(Rect.fromCenter(center: size.center(Offset(0, unit * 1.25)),
      width: unit * 2.6 * (1 - hop * .3), height: unit * .9), Paint()
      ..color = Color.fromRGBO(0, 6, 4, .4 * fade)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    final mesh = _cube;
    renderer.drawMesh(canvas, mesh, model, SoftMaterial(color: _stone.withValues(alpha: fade),
      specular: .28, rim: .2), tint: (i) {
      // The -y face is jade; the others are stone, a shade lighter on top.
      final ny = mesh.normals[i * 3 + 1];
      if (ny < -.55) return Color.lerp(_jadeDeep, _jade, t.clamp(0.0, 1.0))!.withValues(alpha: fade);
      return (ny > .55 ? const Color(0xFF66765D) : _stone).withValues(alpha: fade);
    });
    // The check mark lies on the jade face (local x across, local z up once turned).
    final facing = renderer.rotateModel(model, 0, -1, 0).z;
    if (facing > .15) {
      final path = Path();
      const points = [(-.5, .02), (-.13, -.36), (.52, .42)];
      for (var i = 0; i < points.length; i++) {
        final p = renderer.projectModel(model, points[i].$1, -1.03, points[i].$2);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      final alpha = ((facing - .15) / .45).clamp(0.0, 1.0) * fade;
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .5
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFE9FFF2).withValues(alpha: .35 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .26
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF0E2A1C).withValues(alpha: alpha));
    }
    if (focused) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: size.center(Offset.zero),
        width: unit * 3.6, height: unit * 3.6), Radius.circular(unit)), Paint()
        ..style = PaintingStyle.stroke..strokeWidth = 2..color = _focus);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.enabled != enabled || old.focused != focused || old.turn != turn;
}

/// Progress as a glass vial filling with glowing liquid. With a null [value] a bead
/// of light shuttles through the vial instead.
class Progress3D extends StatefulWidget {
  const Progress3D({super.key, this.value, this.height = 12, this.color = _jade, this.semanticsLabel});
  final double? value;
  final double height;
  final Color color;
  final String? semanticsLabel;

  @override
  State<Progress3D> createState() => _Progress3DState();
}

class _Progress3DState extends State<Progress3D> with SingleTickerProviderStateMixin {
  late final _shuttle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Progress3D old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final shuttling = widget.value == null && !MediaQuery.disableAnimationsOf(context);
    if (shuttling && !_shuttle.isAnimating) {
      _shuttle.repeat(reverse: true);
    } else if (!shuttling && _shuttle.isAnimating) {
      _shuttle.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final percent = value == null || !value.isFinite ? null : '${(value.clamp(0.0, 1.0) * 100).round()}%';
    return Semantics(label: widget.semanticsLabel ?? 'Progress', value: percent,
      child: SizedBox(height: widget.height, width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value == null || !value.isFinite ? 0 : value.clamp(0.0, 1.0).toDouble()),
          duration: _motion(context, 220), curve: Curves.easeOutCubic,
          builder: (context, fill, _) => CustomPaint(painter: _VialPainter(
            fill: value == null ? null : fill, shuttle: _shuttle, color: widget.color)))));
  }

  @override
  void dispose() {
    _shuttle.dispose();
    super.dispose();
  }
}

class _VialPainter extends CustomPainter {
  _VialPainter({required this.fill, required this.shuttle, required this.color}) : super(repaint: shuttle);
  final double? fill;
  final Animation<double> shuttle;
  final Color color;

  static final _cache = <int, SoftMesh>{};

  /// Vial meshes depend on the aspect ratio; a handful of sizes cover the app.
  static SoftMesh _mesh(double halfLength, double radius) {
    final steps = (halfLength * 4).round();
    if (_cache.length > 96) _cache.clear();
    return _cache.putIfAbsent(Object.hash(steps, (radius * 100).round()),
      () => SoftMesh.capsule(halfLength: steps / 4, radius: radius, segments: 14, capRings: 4));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= size.height || size.height <= 0) return;
    final unit = size.height / 2.3;
    final halfLength = size.width / unit / 2 - 1.1;
    if (halfLength <= 0) return;
    final renderer = SoftRenderer(center: size.center(Offset.zero), unit: unit,
      distance: double.infinity, pitch: .5);
    final glass = _mesh(halfLength, 1);
    renderer.drawMesh(canvas, glass, vm.Matrix4.identity(), const SoftMaterial(color: Color(0xFF0B1913),
      opacity: .7, ambient: .5, diffuse: .3, specular: .05, rim: 0), inside: true);
    final liquidRadius = .7;
    final level = fill;
    if (level == null) {
      final x = (Curves.easeInOutSine.transform(shuttle.value) * 2 - 1) * (halfLength - .2);
      final bead = _mesh(.6, liquidRadius);
      renderer.drawMesh(canvas, bead, vm.Matrix4.translationValues(x, 0, 0),
        SoftMaterial(color: color, emissive: .45, specular: .5, rim: .2));
    } else if (level > .005) {
      // The liquid's tips run from the vial's left end to the fill level.
      final left = -halfLength - .45;
      final right = left + liquidRadius * 2 + (halfLength * 2 + .9 - liquidRadius * 2) * level;
      final liquid = _mesh(math.max(0.0, (right - left) / 2 - liquidRadius), liquidRadius);
      renderer.drawMesh(canvas, liquid, vm.Matrix4.translationValues((left + right) / 2, 0, 0),
        SoftMaterial(color: color, emissive: .35, specular: .45, rim: .2));
    }
    renderer.drawMesh(canvas, glass, vm.Matrix4.identity(), const SoftMaterial(color: _glass,
      opacity: .08, ambient: .2, diffuse: .2, specular: .7, shininess: 40, rim: .35));
  }

  @override
  bool shouldRepaint(_VialPainter old) => old.fill != fill || old.color != color || old.shuttle != shuttle;
}

/// An indeterminate loading indicator: a tilted ring of pebble beads with a bright
/// comet of light running around it.
class Spinner3D extends StatefulWidget {
  const Spinner3D({super.key, this.size = 36, this.semanticsLabel = 'Loading'});
  final double size;
  final String semanticsLabel;

  @override
  State<Spinner3D> createState() => _Spinner3DState();
}

class _Spinner3DState extends State<Spinner3D> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  Widget build(BuildContext context) => Semantics(label: widget.semanticsLabel,
    child: SizedBox.square(dimension: widget.size,
      child: CustomPaint(painter: _SpinnerPainter(_spin))));

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.spin) : super(repaint: spin);
  final Animation<double> spin;

  static const _beads = 10;
  static final _bead = SoftMesh.ellipsoid(segments: 10, rings: 7);

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 2.9;
    final renderer = SoftRenderer(center: size.center(Offset.zero), unit: unit, distance: 8, pitch: .95);
    final phase = spin.value;
    final beads = <(double, vm.Matrix4, double)>[];
    for (var i = 0; i < _beads; i++) {
      // The ring turns slowly while the comet of light laps it.
      final angle = 2 * math.pi * (i / _beads + phase / 4);
      final x = math.cos(angle), z = math.sin(angle);
      // Brightness falls off behind the comet's head.
      final behind = (phase - i / _beads) % 1;
      final heat = math.pow(1 - behind, 3).toDouble();
      final radius = .17 + heat * .1;
      final model = vm.Matrix4.translationValues(x, 0, z)..scaleByDouble(radius, radius, radius, 1);
      final depth = <double>[0];
      renderer.projectModel(model, 0, 0, 0, depth: depth);
      beads.add((depth[0], model, heat));
    }
    beads.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, model, heat) in beads) {
      renderer.drawMesh(canvas, _bead, model, SoftMaterial(
        color: Color.lerp(_stone, _jade, heat)!, emissive: heat * .5, specular: .45, rim: .2));
    }
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) => old.spin != spin;
}
