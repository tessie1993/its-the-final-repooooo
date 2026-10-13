import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// One localized impulse in the shared gel. Positions are normalized to 0..1.
@immutable
class GelRipple {
  const GelRipple({
    required this.position,
    required this.startedAt,
    this.strength = 1,
  });

  final Offset position;
  final double startedAt;
  final double strength;
}

/// Shared, bounded spring and wave state for the environment and every control.
///
/// SceneSurface owns the ticker. No component creates its own animation loop.
class GeodeSceneController extends ChangeNotifier {
  double _time = 0;
  double _energy = .42;
  double _hue = .5;
  double _luminescence = .65;
  double _particleDensity = .6;
  double _rippleStrength = .65;
  double _displayEnergy = .42;
  double _audioRms = 0;
  double _audioBass = 0;
  double _audioMid = 0;
  double _audioTreble = 0;
  double _lastAudioBeat = -1;
  double _previousOnset = 0;
  int _materialIndex = 0;
  double _displayMaterial = 0;
  bool _reducedMotion = false;
  bool _systemReducedMotion = false;
  bool _paused = false;
  bool _particlesEnabled = true;
  bool _highQuality = true;
  Offset _tilt = Offset.zero;
  Offset _velocity = Offset.zero;
  Offset _target = Offset.zero;
  Offset _touchPosition = const Offset(.5, .45);
  Offset _burstPosition = const Offset(.5, .45);
  double _lastWakeTime = -1;
  Offset _lastWakePosition = Offset.zero;
  double _pulse = 0;
  double _burstAge = 20;
  int _burstCount = 0;
  final List<GelRipple> _ripples = [];
  bool _disposed = false;
  bool _shaderReady = false;
  String? _rendererError;

  double get time => _time;
  double get energy => _energy;
  double get hue => _hue;
  double get luminescence => _luminescence;

  /// Shared light level for 3D organisms, particles and tactile control rims.
  /// Paused and accessibility still modes never flicker in response to audio.
  double get lightEnvelope => _luminescence * (motionDisabled
      ? .32
      : (.32 + _audioRms * .45 + _audioBass * .25 + _pulse * .2)
          .clamp(0.0, 1.0));

  void setLuminescence(double value) {
    if (_disposed || !value.isFinite) return;
    final bounded = value.clamp(0.0, 1.0).toDouble();
    if (bounded == _luminescence) return;
    _luminescence = bounded;
    notifyListeners();
  }
  double get particleDensity => _particleDensity;
  double get rippleStrength => _rippleStrength;
  double get displayEnergy => _displayEnergy;
  double get audioRms => _audioRms;
  double get audioBass => _audioBass;
  double get audioMid => _audioMid;
  double get audioTreble => _audioTreble;
  bool get audioActive => _audioRms > .005;
  int get materialIndex => _materialIndex;
  double get displayMaterial => _displayMaterial;
  bool get reducedMotion => _reducedMotion;
  bool get effectiveReducedMotion => _reducedMotion || _systemReducedMotion;
  bool get motionDisabled => _paused || effectiveReducedMotion;
  bool get paused => _paused;
  bool get particlesEnabled => _particlesEnabled;
  bool get highQuality => _highQuality;
  Offset get tilt => _tilt;
  Offset get touchPosition => _touchPosition;
  Offset get burstPosition => _burstPosition;
  List<GelRipple> get ripples => List.unmodifiable(_ripples);
  double get pulse => _pulse;
  double get burstAge => _burstAge;
  int get burstCount => _burstCount;
  bool get shaderReady => _shaderReady;
  String? get rendererError => _rendererError;

  set reducedMotion(bool value) {
    if (_disposed || value == _reducedMotion) return;
    _reducedMotion = value;
    _applyMotionPreference();
    notifyListeners();
  }

  void setSystemReducedMotion(bool value) {
    if (_disposed || value == _systemReducedMotion) return;
    _systemReducedMotion = value;
    _applyMotionPreference();
    notifyListeners();
  }

  void _applyMotionPreference() {
    if (!effectiveReducedMotion) return;
    _target = Offset.zero;
    _velocity = Offset.zero;
    _tilt = Offset.zero;
    _pulse = 0;
    _burstAge = 20;
    _ripples.clear();
    _displayEnergy = _energy;
    _displayMaterial = _materialIndex.toDouble();
  }

  set paused(bool value) {
    if (_disposed || value == _paused) return;
    _paused = value;
    _target = Offset.zero;
    notifyListeners();
  }

  set particlesEnabled(bool value) {
    if (_disposed || value == _particlesEnabled) return;
    _particlesEnabled = value;
    notifyListeners();
  }

  set highQuality(bool value) {
    if (_disposed || value == _highQuality) return;
    _highQuality = value;
    notifyListeners();
  }

  void setHue(double value) {
    if (_disposed || !value.isFinite) return;
    _hue = value.clamp(0.0, 1.0).toDouble();
    notifyListeners();
  }
  void setParticleDensity(double value) {
    if (_disposed || !value.isFinite) return;
    _particleDensity = value.clamp(0.0, 1.0).toDouble();
    notifyListeners();
  }
  void setRippleStrength(double value) {
    if (_disposed || !value.isFinite) return;
    _rippleStrength = value.clamp(0.0, 1.0).toDouble();
    notifyListeners();
  }

  void setEnergy(double value) {
    if (_disposed || !value.isFinite) return;
    _energy = value.clamp(0.0, 1.0).toDouble();
    if (motionDisabled) _displayEnergy = _energy;
    notifyListeners();
  }

  /// Receives actual PCM measurements from the playback engine. User intensity
  /// remains the baseline; audio adds a bounded envelope without moving controls
  /// more than their normal six-pixel range. Silence restores ambient motion.
  void setAudioFeatures({required double rms, required double bass,
    required double mid, required double treble, required double onset}) {
    if (_disposed) return;
    double bounded(double value) => value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0;
    _audioRms = bounded(rms);
    _audioBass = bounded(bass);
    _audioMid = bounded(mid);
    _audioTreble = bounded(treble);
    final beat = bounded(onset);
    if (!motionDisabled && _audioRms > .005 && beat > .3 &&
        _previousOnset <= .3 && _time - _lastAudioBeat > .24) {
      _lastAudioBeat = _time;
      _pulse = math.max(_pulse, beat * .5);
      _addRipple(const Offset(.5, .64), beat * .55);
    }
    _previousOnset = beat;
    // The shared scene ticker handles repainting. No second audio animation
    // loop or widget-tree rebuild is scheduled for each PCM block.
  }

  void setMaterial(int value) {
    if (_disposed) return;
    _materialIndex = value.clamp(0, 2).toInt();
    if (motionDisabled) _displayMaterial = _materialIndex.toDouble();
    notifyListeners();
  }

  Offset? _normalize(Offset position) {
    if (!position.dx.isFinite || !position.dy.isFinite) return null;
    return Offset(
      position.dx.clamp(0.0, 1.0).toDouble(),
      position.dy.clamp(0.0, 1.0).toDouble(),
    );
  }

  /// Starts a ripple exactly where the user touched, including on controls.
  void touch(Offset normalized) {
    if (_disposed || motionDisabled) return;
    final position = _normalize(normalized);
    if (position == null) return;
    _touchPosition = position;
    _target = position * 2 - const Offset(1, 1);
    _addRipple(position, 1);
    _pulse = math.max(_pulse, .45);
    _burstAge = 0;
    _burstPosition = position;
    _velocity += Offset((position.dx - .5) * .18, -.12);
    notifyListeners();
  }

  /// Dragging bends the gel and leaves a short, rate-limited wake.
  void interact(Offset normalized) {
    if (_disposed || motionDisabled) return;
    final position = _normalize(normalized);
    if (position == null) return;
    _touchPosition = position;
    _target = position * 2 - const Offset(1, 1);
    if (_time - _lastWakeTime > .11 &&
        (position - _lastWakePosition).distance > .028) {
      _addRipple(position, .45);
    }
  }

  void release() {
    if (_disposed) return;
    _target = Offset.zero;
  }

  void _addRipple(Offset position, double strength) {
    if (_rippleStrength == 0) return;
    _ripples.removeWhere((ripple) => _time - ripple.startedAt > 3.8);
    if (_ripples.length >= 4) _ripples.removeAt(0);
    _ripples.add(GelRipple(
      position: position,
      startedAt: _time,
      strength: strength * _rippleStrength / .65,
    ));
    _lastWakeTime = _time;
    _lastWakePosition = position;
  }

  /// A larger impulse and a small, deterministic spray of refractive droplets.
  void burst() {
    if (_disposed) return;
    _burstCount += 1;
    if (!motionDisabled) {
      _pulse = 1;
      _burstAge = 0;
      _burstPosition = _touchPosition;
      _velocity += const Offset(.38, -.78);
      _addRipple(_touchPosition, 1.35);
    }
    notifyListeners();
  }

  /// Pixel displacement for a floating control. Heavy items respond less.
  ///
  /// Ripples arrive after their travel time. Motion is limited to six logical
  /// pixels per axis, so large impulses cannot dislodge a navigation target.
  Offset offsetFor(Offset normalized, {double weight = 1, double phase = 0}) {
    if (effectiveReducedMotion) return Offset.zero;
    final safeWeight = weight.isFinite ? weight.clamp(.5, 4.0).toDouble() : 1.0;
    final safePhase = phase.isFinite ? phase : 0.0;
    final anchor = _normalize(normalized) ?? const Offset(.5, .5);
    final amplitude = .75 + _displayEnergy * 1.15;
    var displacement = Offset(
      math.sin(_time * .43 + safePhase + anchor.dy * 2) * amplitude * .48,
      math.sin(_time * .61 + safePhase + anchor.dx * 2) * amplitude,
    );
    displacement += _tilt * .7;
    for (final ripple in _ripples) {
      final delta = anchor - ripple.position;
      final distance = delta.distance;
      final arrived = _time - ripple.startedAt - distance / .65;
      if (arrived < 0 || arrived > 2.8) continue;
      final radial = distance < .001 ? const Offset(0, -1) : delta / distance;
      final oscillation = math.sin(arrived * 11) * math.exp(-arrived * 2.1);
      displacement += radial *
          (oscillation * 5.5 * ripple.strength * math.exp(-distance * .75));
    }
    displacement /= safeWeight;
    return Offset(
      displacement.dx.clamp(-6.0, 6.0).toDouble(),
      displacement.dy.clamp(-6.0, 6.0).toDouble(),
    );
  }

  /// Time integration is capped and subdivided to keep resumed apps stable.
  void advance(double seconds, {bool? systemReducedMotion}) {
    if (_disposed || !seconds.isFinite || seconds <= 0) return;
    if (systemReducedMotion != null) setSystemReducedMotion(systemReducedMotion);
    if (motionDisabled) return;
    final dt = seconds.clamp(0.0, .05).toDouble();
    final steps = math.max(1, (dt / (1 / 120)).ceil());
    final step = dt / steps;
    for (var i = 0; i < steps; i += 1) {
      final acceleration = (_target - _tilt) * 38 - _velocity * 10.5;
      _velocity += acceleration * step;
      _tilt += _velocity * step;
    }
    _time += dt;
    _burstAge += dt;
    _pulse *= math.exp(-dt * 2.4);
    _ripples.removeWhere((ripple) => _time - ripple.startedAt > 3.8);
    final blend = 1 - math.exp(-dt * 5);
    final audioEnergy = (_energy + _audioRms * .55 + _audioBass * .2).clamp(0.0, 1.0);
    _displayEnergy += (audioEnergy - _displayEnergy) * blend;
    _displayMaterial += (_materialIndex - _displayMaterial) * blend;
    notifyListeners();
  }

  void reportRenderer({required bool ready, String? error}) {
    if (_disposed) return;
    _shaderReady = ready;
    _rendererError = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
