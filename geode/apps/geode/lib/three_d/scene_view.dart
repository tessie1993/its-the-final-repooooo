import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart' as fs;

import 'three_d_support.dart';

/// A flutter_scene scene that a [ThreeDView] can host.
abstract class ThreeDScene {
  fs.Scene get scene;
  fs.Camera get camera;

  /// Advances animation by [dt] seconds. [live] is false under reduced motion,
  /// where a scene settles into its resting pose. Returns whether it still needs
  /// frames; once false the view stops ticking until it is woken again.
  bool advance(double dt, {required bool live});

  void dispose() => scene.dispose();
}

/// Hosts a [ThreeDScene] in a CustomPaint. It creates the scene lazily, ticks only
/// while the scene asks for frames (or [listenable] changes), pauses with
/// TickerMode, and shows [fallback] in flat mode or whenever Flutter GPU fails.
class ThreeDView<T extends ThreeDScene> extends StatefulWidget {
  const ThreeDView({
    super.key,
    required this.mode,
    required this.create,
    required this.fallback,
    this.onScene,
    this.listenable,
    this.semanticsLabel,
    this.pixelRatio,
  });

  final ThreeDMode mode;
  final Future<T> Function() create;
  final Widget fallback;

  /// Called on every build once the scene exists, so callers can push state
  /// (track, progress, selection) into it before the next frame.
  final void Function(T scene)? onScene;

  /// Wakes the scene for at least one frame whenever it notifies.
  final Listenable? listenable;
  final String? semanticsLabel;
  final double? pixelRatio;

  @override
  State<ThreeDView<T>> createState() => ThreeDViewState<T>();
}

class ThreeDViewState<T extends ThreeDScene> extends State<ThreeDView<T>>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _frame = ValueNotifier<int>(0);
  T? _scene;
  bool _failed = false;
  int _generation = 0;
  Duration? _last;

  T? get scene => _scene;

  @override
  void initState() {
    super.initState();
    widget.listenable?.addListener(wake);
    if (widget.mode != ThreeDMode.flat) _create();
  }

  Future<void> _create() async {
    final generation = ++_generation;
    T? created;
    try {
      created = await widget.create();
      if (!mounted || generation != _generation || widget.mode == ThreeDMode.flat) {
        created.dispose();
        return;
      }
      setState(() => _scene = created);
      wake();
    } catch (error) {
      created?.dispose();
      if (kDebugMode) debugPrint('3D view uses its flat fallback: $error');
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  /// Requests frames until the scene reports that it is at rest.
  void wake() {
    if (_scene == null || _failed || _ticker.isActive) return;
    _last = null;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final scene = _scene;
    if (scene == null) {
      _ticker.stop();
      return;
    }
    final last = _last;
    _last = elapsed;
    final dt = last == null ? 0.0 : ((elapsed - last).inMicroseconds / 1e6).clamp(0.0, .1).toDouble();
    final more = scene.advance(dt, live: widget.mode == ThreeDMode.live);
    _frame.value++;
    if (!more) _ticker.stop();
  }

  void _renderFailed(Object error) {
    if (kDebugMode) debugPrint('3D rendering stopped, using flat fallback: $error');
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_failed) setState(() => _failed = true);
    });
  }

  @override
  void didUpdateWidget(ThreeDView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable?.removeListener(wake);
      widget.listenable?.addListener(wake);
    }
    if (oldWidget.mode != widget.mode) {
      if (widget.mode == ThreeDMode.flat) {
        _generation++;
        _ticker.stop();
        _scene?.dispose();
        _scene = null;
      } else if (_scene == null && !_failed) {
        _create();
      }
    }
    wake();
  }

  @override
  Widget build(BuildContext context) {
    final scene = _scene;
    if (widget.mode == ThreeDMode.flat || _failed || scene == null) return widget.fallback;
    if (widget.onScene != null) {
      widget.onScene!(scene);
      // New state from the caller needs at least one frame to show.
      wake();
    }
    final ratio = widget.pixelRatio ?? MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0).toDouble();
    final view = RepaintBoundary(child: CustomPaint(
      isComplex: true,
      willChange: _ticker.isActive,
      painter: _ScenePainter(scene, _frame, ratio, _renderFailed),
      child: const SizedBox.expand(),
    ));
    final label = widget.semanticsLabel;
    return label == null ? ExcludeSemantics(child: view) : Semantics(image: true, label: label, child: view);
  }

  @override
  void dispose() {
    _generation++;
    widget.listenable?.removeListener(wake);
    _ticker.dispose();
    _frame.dispose();
    _scene?.dispose();
    super.dispose();
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.host, this.frame, this.pixelRatio, this.onError)
    : super(repaint: Listenable.merge([frame, host.scene.repaintRequested]));

  final ThreeDScene host;
  final ValueNotifier<int> frame;
  final double pixelRatio;
  final void Function(Object error) onError;
  bool _failed = false;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || _failed) return;
    canvas.save();
    try {
      host.scene.render(host.camera, canvas, viewport: Offset.zero & size, pixelRatio: pixelRatio);
    } catch (error) {
      _failed = true;
      onError(error);
    } finally {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.host != host || old.pixelRatio != pixelRatio;
}
