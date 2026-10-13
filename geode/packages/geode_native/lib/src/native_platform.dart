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
    this.channel = const MethodChannel('geode_native'),
    this.playbackChannel = const EventChannel('geode_native/playback'),
    this.featureChannel = const EventChannel('geode_native/features'),
    this.mediaChannel = const EventChannel('geode_native/media_actions'),
  });

  static final GeodeNative instance = GeodeNative();
  static const equalizerFrequencies = <double>[
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
  ];

  final MethodChannel channel;
  final EventChannel playbackChannel;
  final EventChannel featureChannel;
  final EventChannel mediaChannel;

  late final Stream<NativePlaybackSnapshot> snapshots = playbackChannel
      .receiveBroadcastStream()
      .map((event) => NativePlaybackSnapshot.fromMap(event as Map<Object?, Object?>));

  /// Struct order is defined in core/api/geode_api.h: 33 scalar fields,
  /// 64 spectrum bands, 128 waveform points, then 12 chroma bins.
  late final Stream<Float32List> features = featureChannel
      .receiveBroadcastStream()
      .map((event) => event is Float32List
          ? event
          : Float32List.fromList((event as List<Object?>).cast<num>().map((n) => n.toDouble()).toList()));

  late final Stream<NativeMediaAction> mediaActions = mediaChannel
      .receiveBroadcastStream()
      .map((event) {
        final values = event as Map<Object?, Object?>;
        return NativeMediaAction(
          values['action']! as String,
          position: Duration(milliseconds: (values['positionMs'] as num?)?.toInt() ?? 0),
        );
      });

  Future<void> initialize() => channel.invokeMethod<void>('initialize');
  Future<void> open(String uri, {required int token}) =>
      channel.invokeMethod<void>('open', {'uri': uri, 'token': token});
  Future<void> setNext(String? uri, {int token = -1}) =>
      channel.invokeMethod<void>('setNext', {'uri': uri, 'token': token});
  Future<void> play() => channel.invokeMethod<void>('play');
  Future<void> pause() => channel.invokeMethod<void>('pause');
  Future<void> stop() => channel.invokeMethod<void>('stop');
  Future<void> seek(Duration position) =>
      channel.invokeMethod<void>('seek', {'positionMs': position.inMilliseconds});
  Future<void> setVolume(double volume) =>
      channel.invokeMethod<void>('setVolume', {'volume': volume.clamp(0, 1)});
  Future<void> setCrossfade(Duration duration, {int curve = 1}) =>
      channel.invokeMethod<void>('setCrossfade', {'durationMs': duration.inMilliseconds, 'curve': curve});
  Future<NativePlaybackSnapshot> snapshot() async => NativePlaybackSnapshot.fromMap(
      (await channel.invokeMapMethod<Object?, Object?>('snapshot'))!);
  Future<int> createTexture({int width = 720, int height = 1280}) async =>
      (await channel.invokeMethod<int>('createTexture', {'width': width, 'height': height}))!;
  Future<void> disposeTexture() => channel.invokeMethod<void>('disposeTexture');
  Future<void> setAudioSource(String source) =>
      channel.invokeMethod<void>('setAudioSource', {'source': source});
  Future<void> setScene(String id) => channel.invokeMethod<void>('setScene', {'id': id});
  Future<void> setParam(String name, double value) =>
      channel.invokeMethod<void>('setParam', {'name': name, 'value': value});
  Future<void> setReducedMotion(bool enabled) =>
      channel.invokeMethod<void>('setReducedMotion', {'enabled': enabled});
  Future<void> setPaused(bool paused) =>
      channel.invokeMethod<void>('setPaused', {'paused': paused});
  Future<void> setVisualizerPaused(bool paused) => setPaused(paused);
  Future<List<String>> listScenes() async =>
      (await channel.invokeListMethod<String>('listScenes')) ?? const [];
  Future<List<String>> listMilkPresets() async =>
      (await channel.invokeListMethod<String>('listMilkPresets')) ?? const [];
  Future<void> loadMilkPreset(String name) =>
      channel.invokeMethod<void>('loadMilkPreset', {'name': name});
  Future<void> touch({required double x, required double y, double dx = 0, double dy = 0,
    double dt = 0.016, double strength = 1}) => channel.invokeMethod<void>('touch', {
      'x': x.clamp(0, 1), 'y': y.clamp(0, 1), 'dx': dx, 'dy': dy,
      'dt': dt.clamp(0.001, 1), 'strength': strength.clamp(0, 2),
    });
  Future<void> setEqualizer({required bool enabled, required List<double> bands,
    double bassBoost = 0, double loudnessDb = 0, double gainDb = 0,
    bool crossfeed = false, bool limiter = true}) {
    if (bands.length != 10) throw ArgumentError.value(bands.length, 'bands', 'Expected ten EQ bands');
    return channel.invokeMethod<void>('setEqualizer', {
      'enabled': enabled, 'bands': bands, 'bassBoost': bassBoost.clamp(0, 1),
      'loudnessDb': loudnessDb.clamp(0, 10), 'gainDb': gainDb.clamp(-30, 15),
      'crossfeed': crossfeed, 'limiter': limiter,
    });
  }
  Future<Map<String, Object?>> readTags(String uri) async =>
      (await channel.invokeMapMethod<String, Object?>('readTags', {'uri': uri})) ?? const {};
  Future<void> publishPlaybackState(Map<String, Object?> state) =>
      channel.invokeMethod<void>('publishPlaybackState', state);

  /// Opens Android's live wallpaper preview for the currently selected scene.
  Future<void> setWallpaper() => channel.invokeMethod<void>('setWallpaper');

  /// Opens Android's screensaver picker; the user selects Geode there.
  Future<void> openScreensaverSettings() =>
      channel.invokeMethod<void>('openScreensaverSettings');

  /// Asks the launcher to add Geode's transport widget when supported.
  Future<bool> requestPinWidget() async =>
      (await channel.invokeMethod<bool>('requestPinWidget')) ?? false;

}
