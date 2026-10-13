import 'dart:typed_data';

import 'package:flutter/services.dart';

enum NativePlaybackState { idle, buffering, ready, ended, error }

class NativePlaybackSnapshot {
  const NativePlaybackSnapshot({
    this.state = NativePlaybackState.idle,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.token = -1,
    this.sampleRate = 0,
    this.error,
    this.visualizerError,
  });

  factory NativePlaybackSnapshot.fromMap(Map<Object?, Object?> data) {
    final ordinal = (data['state'] as num?)?.toInt() ?? 0;
    return NativePlaybackSnapshot(
      state: NativePlaybackState.values[ordinal.clamp(0, 4)],
      playing: data['playing'] == true,
      position: Duration(milliseconds: (data['positionMs'] as num?)?.toInt() ?? 0),
      duration: Duration(milliseconds: (data['durationMs'] as num?)?.toInt() ?? 0),
      token: (data['token'] as num?)?.toInt() ?? -1,
      sampleRate: (data['sampleRate'] as num?)?.toInt() ?? 0,
      error: data['error'] as String?,
      visualizerError: data['visualizerError'] as String?,
    );
  }

  final NativePlaybackState state;
  final bool playing;
  final Duration position;
  final Duration duration;
  final int token;
  final int sampleRate;
  final String? error;
  final String? visualizerError;
}

class NativeMediaAction {
  const NativeMediaAction(this.action, {this.position = Duration.zero});
  final String action;
  final Duration position;
}

/// Android host for the imported C++ decoder, Oboe output, DSP and GLES engine.
/// PCM never crosses a platform channel: the worker analyzes the post-DSP tap
/// and publishes only the 237-float feature frame to Flutter.
class GeodeNative {
  GeodeNative({
    MethodChannel channel = const MethodChannel('geode_native'),
    EventChannel playbackChannel = const EventChannel('geode_native/playback'),
    EventChannel featureChannel = const EventChannel('geode_native/features'),
    EventChannel mediaChannel = const EventChannel('geode_native/media_actions'),
  }) : _channel = channel,
       _playbackChannel = playbackChannel,
       _featureChannel = featureChannel,
       _mediaChannel = mediaChannel;

  static final GeodeNative instance = GeodeNative();
  static const equalizerFrequencies = <double>[
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
  ];

  final MethodChannel _channel;
  final EventChannel _playbackChannel;
  final EventChannel _featureChannel;
  final EventChannel _mediaChannel;

  late final Stream<NativePlaybackSnapshot> snapshots = _playbackChannel
      .receiveBroadcastStream()
      .map((event) => NativePlaybackSnapshot.fromMap(event as Map<Object?, Object?>));

  /// Struct order is defined in core/api/geode_api.h: 33 scalar fields,
  /// 64 spectrum bands, 128 waveform points, then 12 chroma bins.
  late final Stream<Float32List> features = _featureChannel
      .receiveBroadcastStream()
      .map((event) => event is Float32List
          ? event
          : Float32List.fromList((event as List<Object?>).cast<num>().map((n) => n.toDouble()).toList()));

  late final Stream<NativeMediaAction> mediaActions = _mediaChannel
      .receiveBroadcastStream()
      .map((event) {
        final values = event as Map<Object?, Object?>;
        return NativeMediaAction(
          values['action']! as String,
          position: Duration(milliseconds: (values['positionMs'] as num?)?.toInt() ?? 0),
        );
      });

  Future<void> initialize() => _channel.invokeMethod<void>('initialize');
  Future<void> open(String uri, {required int token}) =>
      _channel.invokeMethod<void>('open', {'uri': uri, 'token': token});
  Future<void> setNext(String? uri, {int token = -1}) =>
      _channel.invokeMethod<void>('setNext', {'uri': uri, 'token': token});
  Future<void> play() => _channel.invokeMethod<void>('play');
  Future<void> pause() => _channel.invokeMethod<void>('pause');
  Future<void> stop() => _channel.invokeMethod<void>('stop');
  Future<void> seek(Duration position) =>
      _channel.invokeMethod<void>('seek', {'positionMs': position.inMilliseconds});
  Future<void> setVolume(double volume) =>
      _channel.invokeMethod<void>('setVolume', {'volume': volume.clamp(0, 1)});
  Future<void> setCrossfade(Duration duration, {int curve = 1}) =>
      _channel.invokeMethod<void>('setCrossfade', {'durationMs': duration.inMilliseconds, 'curve': curve});
  Future<NativePlaybackSnapshot> snapshot() async => NativePlaybackSnapshot.fromMap(
      (await _channel.invokeMapMethod<Object?, Object?>('snapshot'))!);
  Future<int> createTexture({int width = 720, int height = 1280}) async =>
      (await _channel.invokeMethod<int>('createTexture', {'width': width, 'height': height}))!;
  Future<void> disposeTexture() => _channel.invokeMethod<void>('disposeTexture');
  Future<void> setScene(String id) => _channel.invokeMethod<void>('setScene', {'id': id});
  Future<void> setParam(String name, double value) =>
      _channel.invokeMethod<void>('setParam', {'name': name, 'value': value});
  Future<void> setReducedMotion(bool enabled) =>
      _channel.invokeMethod<void>('setReducedMotion', {'enabled': enabled});
  Future<void> setPaused(bool paused) =>
      _channel.invokeMethod<void>('setPaused', {'paused': paused});
  Future<void> setVisualizerPaused(bool paused) => setPaused(paused);
  Future<List<String>> listScenes() async =>
      (await _channel.invokeListMethod<String>('listScenes')) ?? const [];
  Future<List<String>> listMilkPresets() async =>
      (await _channel.invokeListMethod<String>('listMilkPresets')) ?? const [];
  Future<void> loadMilkPreset(String name) =>
      _channel.invokeMethod<void>('loadMilkPreset', {'name': name});
  Future<void> touch({required double x, required double y, double dx = 0, double dy = 0,
    double dt = 0.016, double strength = 1}) => _channel.invokeMethod<void>('touch', {
      'x': x.clamp(0, 1), 'y': y.clamp(0, 1), 'dx': dx, 'dy': dy,
      'dt': dt.clamp(0.001, 1), 'strength': strength.clamp(0, 2),
    });
  Future<void> setEqualizer({required bool enabled, required List<double> bands,
    double bassBoost = 0, double loudnessDb = 0, double gainDb = 0,
    bool crossfeed = false, bool limiter = true}) {
    if (bands.length != 10) throw ArgumentError.value(bands.length, 'bands', 'Expected ten EQ bands');
    return _channel.invokeMethod<void>('setEqualizer', {
      'enabled': enabled, 'bands': bands, 'bassBoost': bassBoost.clamp(0, 1),
      'loudnessDb': loudnessDb.clamp(0, 10), 'gainDb': gainDb.clamp(-30, 15),
      'crossfeed': crossfeed, 'limiter': limiter,
    });
  }
  Future<Map<String, Object?>> readTags(String uri) async =>
      (await _channel.invokeMapMethod<String, Object?>('readTags', {'uri': uri})) ?? const {};
  Future<void> publishPlaybackState(Map<String, Object?> state) =>
      _channel.invokeMethod<void>('publishPlaybackState', state);
}
