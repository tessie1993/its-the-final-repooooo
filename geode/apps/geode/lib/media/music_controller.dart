import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:geode_playback/geode_playback.dart';
import 'package:geode_engine/geode_engine.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_models.dart';
import 'shuffle_order.dart';
export 'music_models.dart';

part 'music_catalogue.dart';
part 'music_effects.dart';
part 'music_import.dart';
part 'music_persistence.dart';
part 'music_transport.dart';

/// One real player, one persisted catalogue, and no synthetic transport clock.
/// The UI listens to [position] separately from lower-frequency app state.
class MusicController extends ChangeNotifier {
  MusicController({this.enableDeviceServices = true});

  final bool enableDeviceServices;

  void _ensurePlayer() {
    if (_playerCreated || _disposed || !enableDeviceServices) return;
    _player = GeodePlayer();
    _playerCreated = true;
    _subscriptions.add(_player.mediaActions.listen(_handleMediaAction,
      onError: (Object _) {}));
    _subscriptions.add(_player.playerStateStream.listen((state) {
      if (_disposed) return;
      playing = state.playing && state.processingState != ProcessingState.completed;
      if (!playing && !_player.usesNative) analysis.value = AudioFeatureFrame.silence;
      if (initialized) {
        loading = _loadingSource || state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
      }
      _notify();
      if (state.processingState == ProcessingState.completed &&
          !_loadingSource && !_completionPending) {
        final completedSource = _sourceGeneration;
        _completionPending = true;
        unawaited(_serial(() async {
          if (_sourceGeneration != completedSource || _loadedTrackId == null) return;
          if (sleepAtTrackEnd) {
            sleepAtTrackEnd = false;
            await _player.pause();
            _changed();
          } else if (repeatMode == 2 || (loopStart != null && loopEnd != null)) {
            await _player.seek(loopStart ?? Duration.zero);
            _startPlayback();
          } else {
            await _advance(1, completed: true);
          }
        }).whenComplete(() => _completionPending = false));
      }
    }));
    _subscriptions.add(_player.features.listen((frame) {
      if (_disposed) return;
      try { analysis.value = AudioFeatureFrame.fromNative(frame); }
      on FormatException { analysis.value = AudioFeatureFrame.silence; }
    }, onError: (Object _) {
      if (!_disposed) analysis.value = AudioFeatureFrame.silence;
    }));
    _subscriptions.add(_player.positionStream.listen((value) {
      if (_disposed || _loadedTrackId == null || _loadingSource) return;
      position.value = value;
      if ((value.inSeconds - _lastSavedPositionSeconds).abs() >= 10) {
        _lastSavedPositionSeconds = value.inSeconds;
        _scheduleSave();
      }
      _publishMediaState();
      final start = loopStart;
      final end = loopEnd;
      if (playing && start != null && end != null && value >= end && !_loopSeeking) {
        final loopSource = _sourceGeneration;
        _loopSeeking = true;
        unawaited(_serial(() async {
          if (loopSource == _sourceGeneration && loopStart == start && loopEnd == end) {
            await _player.seek(start);
          }
        })
            .whenComplete(() => _loopSeeking = false));
      }
    }));
    _subscriptions.add(_player.durationStream.listen((value) {
      if (_disposed || value == null || _loadingSource ||
          _loadedTrackId == null || _loadedTrackId != currentTrack?.id) {
        return;
      }
      _acceptDuration(value);
    }));
    _subscriptions.add(_player.errorStream.listen((failure) {
      if (_disposed) return;
      error = 'Playback failed. Retry this track or import it again. (${failure.code})';
      _loadedTrackId = null;
      loading = false;
      _notify();
    }));
  }

  late final GeodePlayer _player;
  final ValueNotifier<AudioFeatureFrame> analysis = ValueNotifier(AudioFeatureFrame.silence);
  bool get nativeAudioAvailable => enableDeviceServices && Platform.isAndroid;
  bool get speedAvailable => _playerCreated ? _player.speedAvailable : !Platform.isAndroid;
  bool get pitchAvailable => false;
  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final List<MusicTrack> _tracks = [];
  final List<MusicPlaylist> _playlists = [];
  final List<String> _queue = [];
  final Set<String> _favorites = {};
  final List<String> _recentIds = [];
  final ShuffleOrder _shuffleOrder = ShuffleOrder();
  List<MusicTrack> get tracks => List.unmodifiable(_tracks);
  List<MusicPlaylist> get playlists => List.unmodifiable(_playlists);
  List<String> get queue => List.unmodifiable(_queue);
  Set<String> get favorites => Set.unmodifiable(_favorites);
  List<String> get recentIds => List.unmodifiable(_recentIds);
  MusicTrack? get currentTrack => queueIndex >= 0 && queueIndex < _queue.length
      ? _findTrack(_queue[queueIndex]) : null;

  int queueIndex = -1;
  bool playing = false, busy = false, loading = false, initialized = false;
  String? importStatus;
  double? importProgress;
  HttpClient? _downloadClient;
  bool _cancelImport = false;
  bool shuffle = false;
  int repeatMode = 0;
  bool sleepAtTrackEnd = false;
  bool crossfeed = false, limiter = true;
  double bassBoost = 0, loudnessDb = 0, preampDb = 0;
  String replayGainMode = 'off';
  double volume = 1, speed = 1, pitch = 0;
  String? error;
  Duration duration = Duration.zero;
  DateTime? sleepEndsAt;
  Duration? loopStart, loopEnd;
  bool equalizerAvailable = false, equalizerEnabled = false;
  List<double> eqFrequencies = const [], eqGains = const [];
  double eqMinGain = -12, eqMaxGain = 12;

  bool _savedEqEnabled = false, _eqInitializing = false;
  List<double> _savedEqGains = [];
  bool _disposed = false, _completionPending = false, _loopSeeking = false;
  bool _loadingSource = false, _playerCreated = false;
  int _importCounter = 0, _resumePositionMs = 0, _sourceGeneration = 0;
  int _lastSavedPositionSeconds = 0;
  String? _loadedTrackId;
  String? _lastPublishedMediaState;
  Timer? _saveTimer, _sleepTimer;
  Future<void>? _initialization;
  Future<void> _transportSerial = Future.value();
  Future<void> _saveSerial = Future.value();

  Future<void> initialize() {
    if (_disposed || initialized) return Future.value();
    if (!enableDeviceServices) {
      initialized = true;
      _notify();
      return Future.value();
    }
    return _initialization ??= _initialize().whenComplete(() => _initialization = null);
  }
  Future<void> flush() async {
    if (!initialized || _disposed || !enableDeviceServices) return;
    _saveTimer?.cancel();
    _writeSnapshot();
    await _saveSerial;
  }
  Future<void> importAudio() => _importAudio();
  Future<void> importAudioUrl(String url, {String title = ''}) => _importAudioUrl(url, title: title);
  void cancelImport() {
    _cancelImport = true;
    _downloadClient?.close(force: true);
  }
  Future<void> playTrack(MusicTrack track, {List<MusicTrack>? from}) =>
      _playTrack(track, from: from);
  Future<void> togglePlay() => _togglePlay();
  Future<void> playQueueIndex(int index) => _serial(() async {
    if (index < 0 || index >= _queue.length) return;
    queueIndex = index;
    _shuffleOrder.reset(_queue.length, queueIndex);
    _resumePositionMs = 0;
    await _loadCurrent(autoplay: true);
  });
  Future<void> seek(Duration value) => _seek(value);
  Future<void> next() => _serial(() => _advance(1));
  Future<void> previous() => _serial(() async {
    if (position.value > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else {
      await _advance(-1);
    }
  });
  Future<void> setVolume(double value) => _serial(() async {
    final adjusted = value.clamp(0.0, 1.0).toDouble();
    await _player.setVolume(adjusted);
    volume = adjusted;
    _changed();
  });
  Future<void> setSpeed(double value) => _serial(() async {
    if (!speedAvailable) return;
    final adjusted = value.clamp(0.5, 2.0).toDouble();
    await _player.setSpeed(adjusted);
    speed = adjusted;
    _changed();
  });
  // Independent pitch is not implemented by the native PCM engine.
  Future<void> setPitch(double value) => Future<void>.value();
  void setShuffle(bool value) => _change(() {
    shuffle = value;
    _shuffleOrder.reset(_queue.length, queueIndex);
  });
  void setRepeatMode(int value) => _change(() => repeatMode = value.clamp(0, 2).toInt());
  void enqueue(String id) => _enqueue(id);
  void playNext(String id) => _playNext(id);
  Future<void> clearQueue() => _clearQueue();
  Future<void> removeQueue(int index) => _removeQueue(index);
  void moveQueue(int oldIndex, int newIndex) => _moveQueue(oldIndex, newIndex);
  void toggleFavorite(String id) => _toggleFavorite(id);
  String createPlaylist(String name) => _createPlaylist(name);
  void renamePlaylist(String id, String name) => _renamePlaylist(id, name);
  void deletePlaylist(String id) => _change(() => _playlists.removeWhere((p) => p.id == id));
  void addToPlaylist(String playlistId, String trackId) => _editPlaylist(playlistId, trackId, add: true);
  void removeFromPlaylist(String playlistId, String trackId) => _editPlaylist(playlistId, trackId, add: false);
  void movePlaylistTrack(String id, int oldIndex, int newIndex) => _movePlaylistTrack(id, oldIndex, newIndex);
  void updateTrack(MusicTrack track) => _updateTrack(track);
  Future<void> removeTrack(String id) => _removeTrack(id);
  void setSleepTimer(Duration? value) => _setSleepTimer(value);
  void setSleepAtTrackEnd(bool value) => _change(() {
    _sleepTimer?.cancel();
    cancelImport();
    sleepEndsAt = null;
    sleepAtTrackEnd = value;
  });
  void setLoopStart(Duration? value) => _setLoopStart(value);
  void setLoopEnd(Duration? value) => _setLoopEnd(value);
  Future<void> setEqualizerEnabled(bool value) => _setEqualizerEnabled(value);
  Future<void> setEqGain(int band, double value) => _setEqGain(band, value);
  Future<void> setSoundEffects({double? bass, double? loudness, double? preamp,
    bool? headphoneCrossfeed, bool? peakLimiter, String? replayGain}) =>
      _setSoundEffects(bass: bass, loudness: loudness, preamp: preamp,
        headphoneCrossfeed: headphoneCrossfeed, peakLimiter: peakLimiter, replayGain: replayGain);
  bool get hasNext => _queue.isNotEmpty && (repeatMode == 1 ||
      (shuffle ? _shuffleOrder.hasNext : queueIndex + 1 < _queue.length));
  bool get hasPrevious => _queue.isNotEmpty && (position.value > const Duration(seconds: 3) ||
      repeatMode == 1 || (shuffle ? _shuffleOrder.hasPrevious : queueIndex > 0));
  void clearError() { error = null; _notify(); }

  MusicTrack? _findTrack(String id) {
    for (final track in _tracks) { if (track.id == id) return track; }
    return null;
  }
  String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${_importCounter++}';
  void _notify() {
    if (_disposed) return;
    _publishMediaState();
    notifyListeners();
  }
  void _publishMediaState() {
    if (_disposed || !_playerCreated || !initialized || !_player.usesNative) return;
    final track = currentTrack;
    final state = <String, Object?>{
      'title': track?.title ?? 'Geode', 'artist': track?.artist ?? '',
      'album': track?.album ?? '', 'durationMs': duration.inMilliseconds,
      'artUri': track?.artPath.isNotEmpty == true ? Uri.file(track!.artPath).toString() : null,
      'positionMs': position.value.inSeconds * 1000, 'playing': playing,
      'queueIndex': queueIndex, 'queueSize': _queue.length,
      'hasMedia': track != null, 'hasNext': hasNext, 'hasPrevious': hasPrevious,
    };
    final key = jsonEncode(state);
    if (_lastPublishedMediaState == key) return;
    _lastPublishedMediaState = key;
    unawaited(_player.publishPlaybackState(state).catchError((Object _) {
      if (!_disposed) _lastPublishedMediaState = null;
    }));
  }
  void _handleMediaAction(NativeMediaAction action) {
    if (_disposed) return;
    switch (action.action) {
      case 'play': if (!playing) unawaited(togglePlay());
      case 'pause': if (playing) unawaited(togglePlay());
      case 'next': unawaited(next());
      case 'previous': unawaited(previous());
      case 'seek': unawaited(seek(action.position));
      case 'stop': unawaited(_serial(() async {
        await _player.stop();
        _loadedTrackId = null;
        playing = false;
        position.value = Duration.zero;
        analysis.value = AudioFeatureFrame.silence;
        _changed();
      }));
    }
  }
  void _changed() { _notify(); _scheduleSave(); }
  void _change(void Function() action) {
    if (_disposed) return;
    if (!initialized) {
      unawaited(initialize().then((_) { if (initialized && !_disposed) { action(); _changed(); } }));
      return;
    }
    action();
    _changed();
  }
  Future<void> _serial(Future<void> Function() action) {
    final result = _transportSerial.catchError((Object _) {}).then((_) async {
      if (_disposed) return;
      try {
        await initialize();
        if (!initialized || _disposed || !enableDeviceServices) return;
        await action();
      }
      catch (_) {
        if (!_disposed) {
          error = 'Could not complete playback. Check the audio file and retry.';
          loading = false;
          _notify();
        }
      }
    });
    _transportSerial = result;
    return result;
  }
  void _acceptDuration(Duration value) {
    duration = value;
    final track = currentTrack;
    if (track != null && track.durationMs != value.inMilliseconds) {
      final index = _tracks.indexWhere((t) => t.id == track.id);
      if (index >= 0) _tracks[index] = track.copyWith(durationMs: value.inMilliseconds);
      _scheduleSave();
    }
    _notify();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _saveTimer?.cancel();
    _sleepTimer?.cancel();
    if (initialized && enableDeviceServices) _writeSnapshot();
    _disposed = true;
    for (final subscription in _subscriptions) { unawaited(subscription.cancel()); }
    if (_playerCreated) unawaited(_player.dispose().catchError((Object _) {}));
    position.dispose();
    analysis.dispose();
    super.dispose();
  }
}
