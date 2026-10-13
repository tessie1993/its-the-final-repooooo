import 'package:flutter_test/flutter_test.dart';
import 'package:geode_engine/geode_engine.dart';

void main() {
  test('decodes the C ABI feature offsets without changing PCM signs', () {
    final values = List<double>.filled(237, 0);
    values[0] = .25;
    values[1] = .8;
    values[6] = .7;
    values[12] = 128;
    values[33] = .5;
    values[96] = .6;
    values[97] = -.9;
    values[224] = .4;
    values[225] = .3;
    values[236] = .2;
    final frame = AudioFeatureFrame.fromNative(values);
    expect(frame.rms, .25);
    expect(frame.bass, .8);
    expect(frame.onset, .7);
    expect(frame.bpm, 128);
    expect(frame.bands, hasLength(64));
    expect(frame.bands.first, .5);
    expect(frame.bands.last, .6);
    expect(frame.waveform, hasLength(128));
    expect(frame.waveform.first, -.9);
    expect(frame.waveform.last, .4);
    expect(frame.peak, .9);
    expect(frame.chroma, hasLength(12));
    expect(frame.chroma.first, .3);
    expect(frame.chroma.last, .2);
    values[0] = 1;
    expect(frame.rms, .25, reason: 'Published snapshots must own their data.');
  });

  test('rejects incompatible frames and sanitizes non-finite analysis', () {
    expect(() => AudioFeatureFrame.fromNative([0]), throwsFormatException);
    final values = List<double>.filled(237, 0);
    values[0] = double.nan;
    values[1] = double.infinity;
    values[2] = -1;
    values[3] = 2;
    final frame = AudioFeatureFrame.fromNative(values);
    expect([frame.rms, frame.bass, frame.mid, frame.treble], [0, 0, 0, 1]);
    expect(() => frame.values[0] = 1, throwsUnsupportedError);
    expect(() => AudioFeatureFrame.silence.values[0] = 1, throwsUnsupportedError);
  });
}
