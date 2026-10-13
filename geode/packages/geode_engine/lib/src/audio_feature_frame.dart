import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Immutable snapshot of GeodeFeatureFrame in core/api/geode_api.h.
/// Values come from the decoded PCM output, never a synthetic transport clock.
@immutable
class AudioFeatureFrame {
  const AudioFeatureFrame._(this.values);

  static const int floatCount = 237;
  static final silence = AudioFeatureFrame._(List<double>.unmodifiable(List<double>.filled(floatCount, 0)));

  factory AudioFeatureFrame.fromNative(List<double> source) {
    if (source.length != floatCount) {
      throw FormatException('Expected $floatCount audio feature values, got ${source.length}.');
    }
    return AudioFeatureFrame._(List<double>.unmodifiable(
      source.map((value) => value.isFinite ? value : 0.0),
    ));
  }

  final List<double> values;
  double get rms => _level(0);
  double get bass => _level(1);
  double get mid => _level(2);
  double get treble => _level(3);
  double get centroid => _level(4);
  double get flux => _level(5);
  double get onset => _level(6);
  bool get beat => values[7] >= .5;
  double get beatStrength => _level(8);
  double get beatPhase => _level(10);
  double get bpm => math.max(0, values[12]);
  double get macroEnergy => _level(18);
  double get kick => _level(19);
  double get snare => _level(20);
  double get hat => _level(21);
  List<double> get bands => List<double>.unmodifiable(values.getRange(33, 97));
  List<double> get waveform => List<double>.unmodifiable(values.getRange(97, 225));
  List<double> get chroma => List<double>.unmodifiable(values.getRange(225, 237));
  double get peak => values.getRange(97, 225).fold(0.0, (peak, sample) =>
      math.max(peak, sample.abs())).clamp(0.0, 1.0).toDouble();
  double _level(int index) => values[index].clamp(0.0, 1.0).toDouble();
}
