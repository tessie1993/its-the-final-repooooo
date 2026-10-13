import 'dart:math' as math;

import 'package:ditredi/ditredi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:geode_engine/geode_engine.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'three_d_support.dart';

const _crystalLow = Color(0xFF3E7F67), _crystalHigh = Color(0xFFBDF2D2), _curve = Color(0xFFF3E7A8);

Color _shade(double level) => Color.lerp(_crystalLow, _crystalHigh, level.clamp(0.0, 1.0))!;

/// A lit box (top and four walls) standing on y = 0, for ditredi's face renderer.
List<Face3D> _column(double x, double z, double width, double depth, double height, Color color) {
  final h = math.max(height, .02);
  final x0 = x - width / 2, x1 = x + width / 2, z0 = z - depth / 2, z1 = z + depth / 2;
  final a = vm.Vector3(x0, 0, z0), b = vm.Vector3(x1, 0, z0), c = vm.Vector3(x1, 0, z1), d = vm.Vector3(x0, 0, z1);
  final e = vm.Vector3(x0, h, z0), f = vm.Vector3(x1, h, z0), g = vm.Vector3(x1, h, z1), k = vm.Vector3(x0, h, z1);
  Face3D face(vm.Vector3 p, vm.Vector3 q, vm.Vector3 r) => Face3D.fromVertices(p, q, r, color: color);
  return [
    face(e, f, g), face(e, g, k), // top
    face(a, b, f), face(a, f, e), // front
    face(b, c, g), face(b, g, f), // right
    face(c, d, k), face(c, k, g), // back
    face(d, a, e), face(d, e, k), // left
  ];
}

/// The live spectrum as a 3D terrain: each row is one moment of the 64-band analysis
/// folded to [columns] bands, receding into depth as it ages, with the equalizer
/// curve laid across the front. Throttled to 30 fps and frozen under reduced motion.
class SpectrumTerrain3D extends StatefulWidget {
  const SpectrumTerrain3D({super.key, required this.analysis, required this.fallback,
    this.gains = const [], this.minGain = -15, this.maxGain = 15, this.columns = 16, this.rows = 10});

  final ValueListenable<AudioFeatureFrame> analysis;
  final Widget fallback;

  /// Equalizer band gains in dB, drawn as a curve across the front row.
  final List<double> gains;
  final double minGain, maxGain;
  final int columns, rows;

  @override
  State<SpectrumTerrain3D> createState() => _SpectrumTerrain3DState();
}

class _SpectrumTerrain3DState extends State<SpectrumTerrain3D> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _controller = DiTreDiController(rotationX: -24, rotationY: 28, light: vm.Vector3(-.4, -1, .8),
    lightStrength: .9, ambientLightStrength: .32);
  late List<List<double>> _history = _emptyHistory();
  Duration _lastFrame = Duration.zero, _lastRow = Duration.zero;
  final _figures = ValueNotifier<List<Model3D>>(const []);

  List<List<double>> _emptyHistory() =>
      List.generate(widget.rows, (_) => List<double>.filled(widget.columns, 0));

  @override
  void didUpdateWidget(SpectrumTerrain3D old) {
    super.didUpdateWidget(old);
    if (old.rows != widget.rows || old.columns != widget.columns) _history = _emptyHistory();
    _rebuild();
  }

  void _sample() {
    final bands = widget.analysis.value.bands;
    final row = _history.removeLast();
    final per = bands.length / widget.columns;
    for (var i = 0; i < widget.columns; i++) {
      var peak = 0.0;
      for (var j = (i * per).floor(); j < ((i + 1) * per).floor() && j < bands.length; j++) {
        peak = math.max(peak, bands[j]);
      }
      row[i] = peak.isFinite ? peak.clamp(0.0, 1.0).toDouble() : 0;
    }
    _history.insert(0, row);
  }

  void _tick(Duration elapsed) {
    if (elapsed - _lastFrame < const Duration(milliseconds: 33)) return;
    _lastFrame = elapsed;
    if (elapsed - _lastRow >= const Duration(milliseconds: 90)) {
      _lastRow = elapsed;
      _sample();
    }
    _controller.update(rotationY: 28 + math.sin(elapsed.inMilliseconds / 4200) * 14);
    _rebuild();
  }

  void _rebuild() {
    final columns = widget.columns;
    final faces = <Model3D>[];
    for (var r = _history.length - 1; r >= 0; r--) {
      final fade = 1 - r / _history.length * .65;
      for (var c = 0; c < columns; c++) {
        final level = _history[r][c];
        faces.addAll(_column(c - (columns - 1) / 2, r * 1.1, .78, .8, level * 5,
          _shade(level * fade + .05)));
      }
    }
    final gains = widget.gains;
    if (gains.length > 1 && widget.maxGain > widget.minGain) {
      final points = <vm.Vector3>[
        for (var i = 0; i < gains.length; i++)
          vm.Vector3(i / (gains.length - 1) * (columns - 1) - (columns - 1) / 2,
            ((gains[i] - widget.minGain) / (widget.maxGain - widget.minGain)) * 5, -1),
      ];
      for (var i = 0; i < points.length - 1; i++) {
        faces.add(Line3D(points[i], points[i + 1], width: 3, color: _curve));
      }
    }
    _figures.value = faces;
  }

  @override
  Widget build(BuildContext context) {
    final mode = threeDModeIn(context);
    if (mode == ThreeDMode.flat) {
      _ticker.stop();
      return widget.fallback;
    }
    if (mode == ThreeDMode.live && !_ticker.isActive) {
      _ticker.start();
    } else if (mode == ThreeDMode.still && _ticker.isActive) {
      _ticker.stop();
    }
    if (_figures.value.isEmpty) _rebuild();
    return Semantics(image: true, label: 'Live spectrum and equalizer curve in 3D',
      child: ExcludeSemantics(child: ValueListenableBuilder<List<Model3D>>(valueListenable: _figures,
        builder: (context, figures, _) => DiTreDi(figures: figures, controller: _controller,
          config: const DiTreDiConfig(supportZIndex: true, defaultLineWidth: 2)))));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _figures.dispose();
    super.dispose();
  }
}

/// Bass, mid and treble as three 3D quartz columns that rise with the sound.
class Meters3D extends StatelessWidget {
  const Meters3D({super.key, required this.frame, required this.fallback, this.height = 150});
  final AudioFeatureFrame frame;
  final Widget fallback;
  final double height;

  static final _controller = DiTreDiController(rotationX: -18, rotationY: 32,
    light: vm.Vector3(-.3, -1, .7), lightStrength: .95, ambientLightStrength: .3);

  @override
  Widget build(BuildContext context) {
    if (threeDModeIn(context) == ThreeDMode.flat) return fallback;
    final levels = [frame.bass, frame.mid, frame.treble];
    final figures = <Model3D>[
      for (var i = 0; i < levels.length; i++)
        ..._column((i - 1) * 1.6, 0, 1, 1, (levels[i].isFinite ? levels[i].clamp(0.0, 1.0) : 0) * 4,
          _shade(levels[i].isFinite ? levels[i] : 0)),
      // A low plinth gives the columns a common ground.
      ..._column(0, 0, 4.6, 1.6, .06, const Color(0xFF263A2F)),
    ];
    return Semantics(
      label: 'Bass ${(levels[0] * 100).round()} percent, mid ${(levels[1] * 100).round()} percent, '
        'treble ${(levels[2] * 100).round()} percent',
      child: SizedBox(height: height, child: ExcludeSemantics(child: DiTreDi(figures: figures,
        controller: _controller, bounds: vm.Aabb3.minMax(vm.Vector3(-2.4, 0, -1), vm.Vector3(2.4, 4, 1))))),
    );
  }
}
