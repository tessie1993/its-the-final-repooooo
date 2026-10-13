/// Playback through Geode's C++ PCM pipeline on Android.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:geode_native/geode_native.dart';
import 'package:just_audio/just_audio.dart';

export 'package:just_audio/just_audio.dart' show PlayerException, PlayerState, ProcessingState;
export 'package:geode_native/geode_native.dart' show NativeMediaAction;

/// The app keeps its queue and persistence in Dart. Android decoding, output,
/// DSP and the PCM analysis tap all share the native player; other platforms
/// retain just_audio's supported playback implementation.
class GeodePlayer {
  GeodePlayer({bool? useNative, GeodeNative? native})
      : usesNative = useNative ?? Platform.isAndroid,
        _native = native ?? GeodeNative.instance {
    if (usesNative) {
      _subscriptions.add(_native.snapshots.listen(_acceptSnapshot,
          onError: (Object error) => _fail(error.toString())));
    } else {
      _fallback = AudioPlayer();
      _subscriptions.add(_fallback!.playerStateStream.listen(_publishState));
      _subscriptions.add(_fallback!.positionStream.listen((value) {
        _position = value;
        _positions.add(value);
      }));
      _subscriptions.add(_fallback!.durationStream.listen(_durations.add));
      _subscriptions.add(_fallback!.errorStream.listen(_errors.add));
    }
  }

  final bool usesNative;
  final GeodeNative _native;
  AudioPlayer? _fallback;
  final _states = StreamController<PlayerState>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  final _durations = StreamController<Duration?>.broadcast();
  final _errors = StreamController<PlayerException>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  PlayerState _state = PlayerState(false, ProcessingState.idle);
  Duration _position = Duration.zero;
  Duration? _duration;
  int _token = 0;
  bool _disposed = false;
  String? _lastError;
  Future<void>? _initialization;
  Completer<NativePlaybackSnapshot?>? _pendingLoad;

  Stream<PlayerState> get playerStateStream => _states.stream;
  Stream<Duration> get positionStream => _positions.stream;
  Stream<Duration?> get durationStream => _durations.stream;
  Stream<PlayerException> get errorStream => _errors.stream;
  Stream<Float32List> get features => usesNative ? _native.features : const Stream.empty();
  Stream<NativeMediaAction> get mediaActions => usesNative ? _native.mediaActions : const Stream.empty();
  bool get playing => _state.playing;
  ProcessingState get processingState => _state.processingState;
  Duration get position => _position;
  bool get speedAvailable => !usesNative;
  bool get pitchAvailable => false;

  Future<void> initialize() => _initialization ??=
      usesNative ? _native.initialize() : Future<void>.value();

  void _publishState(PlayerState value) {
    if (_disposed) return;
    if (_state.playing == value.playing &&
        _state.processingState == value.processingState) return;
    _state = value;
    _states.add(value);
  }

  void _fail(String message) {
    if (_disposed || message == _lastError) return;
    _lastError = message;
    _errors.add(PlayerException(0, message));
    _publishState(PlayerState(false, ProcessingState.idle));
  }

  void _acceptSnapshot(NativePlaybackSnapshot value) {
    if (_disposed || value.token != _token) return;
    final pending = _pendingLoad;
    if (pending != null && !pending.isCompleted &&
        (value.state == NativePlaybackState.ready ||
         value.state == NativePlaybackState.error ||
         value.state == NativePlaybackState.ended)) {
      pending.complete(value);
    }
    if (value.state == NativePlaybackState.error) {
      _fail(value.error ?? 'The native decoder could not open this track.');
      return;
    }
    _position = value.position;
    _positions.add(value.position);
    if (value.duration != _duration) {
      _duration = value.duration;
      _durations.add(value.duration);
    }
    final state = switch (value.state) {
      NativePlaybackState.idle => ProcessingState.idle,
      NativePlaybackState.buffering => ProcessingState.buffering,
      NativePlaybackState.ready => ProcessingState.ready,
      NativePlaybackState.ended => ProcessingState.completed,
      NativePlaybackState.error => ProcessingState.idle,
    };
    _publishState(PlayerState(value.playing, state));
  }

  Future<Duration?> setFilePath(String path, {Duration? initialPosition}) async {
    await initialize();
    if (_disposed) return null;
    if (!usesNative) {
      return _fallback!.setFilePath(path, initialPosition: initialPosition);
    }
    if (_pendingLoad != null && !_pendingLoad!.isCompleted) _pendingLoad!.complete(null);
    final token = ++_token;
    _lastError = null;
    _position = Duration.zero;
    _duration = null;
    final pending = Completer<NativePlaybackSnapshot?>();
    _pendingLoad = pending;
    _publishState(PlayerState(false, ProcessingState.loading));
    try {
      await _native.open(Uri.file(path).toString(), token: token);
      final ready = await pending.future.timeout(const Duration(seconds: 30));
      if (_disposed || token != _token || ready == null) return null;
      if (ready.state == NativePlaybackState.error) {
        throw PlayerException(0, ready.error ?? 'Native decoder failed');
      }
      if (initialPosition != null && initialPosition > Duration.zero) {
        await _native.seek(initialPosition);
        _position = initialPosition;
      }
      return ready.duration;
    } catch (_) {
      if (!_disposed && token == _token) await _native.stop();
      rethrow;
    } finally {
      if (identical(_pendingLoad, pending)) _pendingLoad = null;
    }
  }

  Future<void> play() async {
    await initialize();
    if (_disposed) return;
    if (usesNative) { await _native.play(); }
    else { await _fallback!.play(); }
  }

  Future<void> pause() async {
    await initialize();
    if (_disposed) return;
    if (usesNative) { await _native.pause(); }
    else { await _fallback!.pause(); }
  }

  Future<void> stop() async {
    await initialize();
    if (_disposed) return;
    if (usesNative) {
      ++_token;
      if (_pendingLoad != null && !_pendingLoad!.isCompleted) _pendingLoad!.complete(null);
      _pendingLoad = null;
      await _native.stop();
      _position = Duration.zero;
      _positions.add(_position);
      _publishState(PlayerState(false, ProcessingState.idle));
    } else { await _fallback!.stop(); }
  }

  Future<void> seek(Duration position) async {
    await initialize();
    if (_disposed) return;
    if (usesNative) { await _native.seek(position); }
    else { await _fallback!.seek(position); }
  }

  Future<void> setVolume(double value) async {
    await initialize();
    if (_disposed) return;
    if (usesNative) { await _native.setVolume(value); }
    else { await _fallback!.setVolume(value); }
  }

  Future<void> setSpeed(double value) async {
    if (!speedAvailable || _disposed) return;
    await _fallback!.setSpeed(value);
  }

  Future<void> setEqualizer({required bool enabled, required List<double> bands}) async {
    if (!usesNative || _disposed) return;
    await initialize();
    await _native.setEqualizer(enabled: enabled, bands: bands);
  }

  Future<Map<String, dynamic>> readTags(String path) async {
    if (!usesNative || _disposed) return const {};
    await initialize();
    return _native.readTags(Uri.file(path).toString());
  }

  Future<void> publishPlaybackState(Map<String, Object?> value) async {
    if (!usesNative || _disposed) return;
    await _native.publishPlaybackState(value);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final pending = _pendingLoad;
    if (pending != null && !pending.isCompleted) pending.complete(null);
    _pendingLoad = null;
    for (final subscription in _subscriptions) { await subscription.cancel(); }
    if (usesNative) {
      try { await _native.stop(); } catch (_) { /* Engine may already be detached. */ }
    } else { await _fallback!.dispose(); }
    await Future.wait([_states.close(), _positions.close(), _durations.close(), _errors.close()]);
  }
}
